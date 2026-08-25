import 'dart:async' show Completer;
import 'dart:math' as math show min;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart'
    show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_svg/flutter_svg.dart';

import '../core/adaptive_config.dart';
import '../core/design_era.dart';
import '../core/native_bridge.dart';
import '../core/native_component_view.dart';
import '../design_systems/design_imports.dart';
import '../effects/liquid_glass.dart';
import '../tokens/adaptive_tokens.dart';
import 'adaptive_base.dart';
import 'adaptive_route.dart';

/// Height of the floating glass capsule on iOS 26 / iPadOS 26.
const double _kGlassPillHeight = 60;

/// Height the capsule shrinks to while the user scrolls down, matching iOS 26's
/// `tabBarMinimizeBehavior`.
const double _kGlassPillMinimizedHeight = 44;

/// Height reserved for [AdaptiveNavigationScaffold.accessory] — a MiniPlayer
/// in Music sits roughly this tall alongside the tab bar.
const double _kAccessoryHeight = 56;

/// Target size for a decoded [AdaptiveDestination.iconImage], in device
/// pixels — 25pt at 3x, in line with a typical tab bar glyph. Any source
/// asset is resized down (or up) to this regardless of its own dimensions,
/// so a designer's 512x512 export does not end up filling the whole bar.
const int _kNativeIconPixelSize = 75;

/// [_kNativeIconPixelSize] expressed as a scale factor, so the native side
/// can recover the intended point size from the pixel data — `UIImage(data:
/// scale:)` needs one explicitly, since raw PNG bytes carry no scale of
/// their own the way an `@3x` asset catalogue entry would.
const double _kNativeIconScale = 3;

/// Key on whichever bottom bar the tab layout produced — a `CupertinoTabBar`,
/// the floating glass capsule, or a Material `NavigationBar`.
///
/// Exposed so tests and integration checks can tell the tab layout from the
/// sidebar layout without knowing which era they are running in.
const Key adaptiveTabBarKey = Key('native_adaptive_ui.tabBar');

/// Key on the sidebar produced by the expanded layout. See [adaptiveTabBarKey].
const Key adaptiveSidebarKey = Key('native_adaptive_ui.sidebar');

/// How top-level navigation is presented.
enum AdaptiveNavigationStyle {
  /// Follow the platform: a bottom bar on phones, a sidebar on iPad and macOS.
  ///
  /// Apple's guidance says to "Consider using a tab bar first" on iPad and to
  /// offer conversion to a sidebar for complex apps. This package defaults the
  /// other way round because a sidebar is what gives the detail pane its own
  /// navigation stack, which is the behaviour that actually distinguishes an
  /// iPad app from a phone app on a tablet. Pass [tabBar] for Apple's default.
  automatic,

  /// Always a tab bar — at the bottom on phones, across the top on iPad, which
  /// is where iPadOS puts it.
  tabBar,

  /// Always a sidebar, with the detail pane navigating independently.
  sidebar,

  /// A sidebar on iPad/macOS that can be collapsed back to a tab bar and
  /// restored, via the caller-owned [AdaptiveNavigationScaffold.sidebarCollapsed]
  /// flag — HIG's `sidebarAdaptable`, where the sidebar and the tab bar are
  /// "the same control." Pair with [AdaptiveSidebarToggleButton] for the
  /// conversion affordance.
  sidebarAdaptable,
}

/// A top-level destination in [AdaptiveNavigationScaffold].
@immutable
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.appleIcon,
    this.appleSelectedIcon,
    this.sfSymbol,
    this.selectedSfSymbol,
    this.badge,
    this.iconImage,
    this.selectedIconImage,
    this.iconSvgAsset,
    this.selectedIconSvgAsset,
    this.tintNativeIcon,
  });

  final String label;

  /// Icon used on Material eras, and on Apple eras when [appleIcon] is absent.
  final Widget icon;

  /// Filled variant shown while selected. Both design systems expect one;
  /// omitting it falls back to [icon].
  final Widget? selectedIcon;

  /// Icon used on Apple eras.
  ///
  /// Material and SF Symbols are not interchangeable, and nothing gives an iOS
  /// build away faster than Material glyphs in its tab bar. Apple's guidance is
  /// to "Consider using SF Symbols to provide familiar, scalable tab bar icons"
  /// and to "Prefer filled symbols or icons for consistency with the platform".
  /// Pass a `CupertinoIcons` glyph — or any SF Symbol you ship — here.
  final Widget? appleIcon;

  /// Selected variant of [appleIcon].
  final Widget? appleSelectedIcon;

  /// SF Symbol name — `'house'`, `'magnifyingglass'`, `'gearshape'`.
  ///
  /// This is what unlocks the **real** `UITabBar` on iOS 26, where the system
  /// draws the Liquid Glass material, the selection morph and the interactive
  /// response to touch and hold. A `UITabBarItem` needs a `UIImage`, and a
  /// Flutter widget cannot cross that boundary — so the native bar is used only
  /// when *every* destination supplies a symbol, and the Dart capsule renders
  /// otherwise.
  ///
  /// Supply the outline variant here and the filled one in [selectedSfSymbol];
  /// Apple's guidance is to "Prefer filled symbols or icons" for the selected
  /// tab. Names must exist in the SF Symbols catalogue for the running OS, or
  /// the item draws without an icon.
  final String? sfSymbol;

  /// Filled variant of [sfSymbol] shown while selected, e.g. `'house.fill'`.
  final String? selectedSfSymbol;

  /// A short badge value drawn over the icon — `'3'`, `'•'`. Threaded to the
  /// real `UITabBarItem.badgeValue` on the native bar, and drawn in Dart on
  /// every other path.
  final String? badge;

  /// A brand mark or custom glyph for the native `UITabBar`, when the icon
  /// has no SF Symbol equivalent.
  ///
  /// [sfSymbol] still unlocks the native bar on its own; this is the
  /// alternative for destinations whose icon is a logo rather than a system
  /// glyph — mixing symbol destinations and custom-icon destinations in the
  /// same bar is fine, so long as every destination has one or the other
  /// (see [hasNativeIcon]).
  ///
  /// Any [ImageProvider] works — `AssetImage`, `MemoryImage`, `NetworkImage`
  /// — because it is resolved to a decoded frame and re-encoded to PNG bytes
  /// to cross the platform channel, the same image pipeline `Image(image:)`
  /// already uses.
  ///
  /// Renders with the icon's own baked-in colours by default, like a photo
  /// or a full-colour logo. Set [tintNativeIcon] when the source is a
  /// single-colour mark that should follow [selectedColor]/[unselectedColor]
  /// instead — the common case for [iconSvgAsset].
  final ImageProvider? iconImage;

  /// Filled/selected variant of [iconImage]. Falls back to [iconImage] while
  /// selected when absent.
  final ImageProvider? selectedIconImage;

  /// An SVG asset for the native `UITabBar` — the vector counterpart to
  /// [iconImage]. Rasterized once, at mount, to the same fixed pixel size as
  /// [iconImage]; Flutter's own image pipeline has no SVG decoder, so this
  /// goes through `flutter_svg` instead of [ImageProvider.resolve].
  ///
  /// Takes precedence over [iconImage] when both are set. Defaults to
  /// [tintNativeIcon] true — unlike a raster logo, an SVG glyph is almost
  /// always drawn as a single shape meant to be recoloured, the same idiom
  /// an SF Symbol already follows.
  final String? iconSvgAsset;

  /// Filled/selected variant of [iconSvgAsset]. Falls back to
  /// [iconSvgAsset] while selected when absent.
  final String? selectedIconSvgAsset;

  /// Recolors [iconImage]/[iconSvgAsset] to [selectedColor]/[unselectedColor]
  /// on the native bar, the way an SF Symbol already is, instead of keeping
  /// the source's own baked-in colours. Ignored when neither is set.
  ///
  /// Defaults to true when [iconSvgAsset] is set and false otherwise, since a
  /// vector glyph is typically single-colour by design and a raster image
  /// typically is not — set this explicitly to override either default.
  final bool? tintNativeIcon;

  /// Whether this destination can appear in the native `UITabBar` — an SF
  /// Symbol name or a custom icon, in either the outline/unselected or the
  /// selected slot.
  bool get hasNativeIcon =>
      sfSymbol != null ||
      selectedSfSymbol != null ||
      iconImage != null ||
      selectedIconImage != null ||
      iconSvgAsset != null ||
      selectedIconSvgAsset != null;

  /// Resolved [tintNativeIcon], honouring the SVG-vs-raster default.
  bool get _resolvedTintNativeIcon =>
      tintNativeIcon ?? (iconSvgAsset != null || selectedIconSvgAsset != null);

  /// The icon to draw for [era], honouring the Apple overrides and
  /// overlaying [badge] — for every Dart-rendered bar. The native tab bar
  /// gets its badge through `UITabBarItem.badgeValue` instead, and Material's
  /// baseline/flexible bars use Flutter's own `Badge` widget, so neither
  /// calls this.
  Widget resolveIcon(DesignEra era, {required bool selected}) {
    final resolved = era.isApple
        ? (selected
            ? appleSelectedIcon ?? appleIcon ?? selectedIcon ?? icon
            : appleIcon ?? icon)
        : (selected ? (selectedIcon ?? icon) : icon);
    return _withDartBadge(resolved);
  }

  /// A small red pill over [child], for bars with no system badge idiom of
  /// their own to delegate to.
  Widget _withDartBadge(Widget child) {
    final value = badge;
    if (value == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Center(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Top-level navigation that changes *shape* with the window, not just style.
///
/// This is the piece most adaptive packages skip. Flutter's default treatment
/// makes an iPad a large iPhone: a bottom tab bar stretched across 1024 points,
/// which no native iPad app has used in years. Here the same destinations
/// render as:
///
/// * a bottom tab bar on phones — a floating glass pill on iOS 26,
/// * a sidebar on iPad and macOS, which is what iPadOS 26 and Tahoe expect,
/// * and back to a tab bar when an iPad app is dragged into Slide Over, because
///   the decision follows the usable window rather than the device.
///
/// In the sidebar layout the detail pane gets its own [Navigator], so pushing a
/// route replaces only that pane and the sidebar stays put — the behaviour that
/// separates an iPad app from a phone app running on a tablet. See
/// [detailNavigator].
///
/// [selectedIndex] is owned by the caller so the widget stays compatible with
/// any routing package rather than fighting it for ownership of navigation
/// state.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.title,
    this.sidebarWidth = 260,
    this.style = AdaptiveNavigationStyle.automatic,
    this.detailNavigator = true,
    this.minimizeOnScroll = false,
    this.sidebarCollapsed = false,
    this.extendContentBehindSidebar = false,
    this.accessory,
    this.selectedColor,
    this.unselectedColor,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Content for the currently selected destination.
  final Widget body;

  /// Shown above the sidebar on expanded layouts.
  final String? title;

  final double sidebarWidth;

  /// How navigation is presented. See [AdaptiveNavigationStyle].
  final AdaptiveNavigationStyle style;

  /// Gives the detail pane its own [Navigator] in the sidebar layout, so
  /// `pushAdaptive` and `Navigator.of(context)` push *within the pane* instead
  /// of covering the whole window.
  ///
  /// Switching destinations resets that pane's stack, which is what iPadOS
  /// does. Turn this off when an outer router already owns navigation and you
  /// want pushes to reach it.
  final bool detailNavigator;

  /// Shrinks the floating capsule while the user scrolls down — iOS 26's
  /// `tabBarMinimizeBehavior(.onScrollDown)`.
  ///
  /// Off by default, and deliberately so: Apple frames minimising as a
  /// behaviour for "tab bars with an attached accessory, like the MiniPlayer in
  /// Music". Without an accessory there is nothing to move inline with the bar,
  /// so minimising just makes navigation harder to hit. Per the same guidance,
  /// the bar is restored by tapping a tab or scrolling back to the top — not by
  /// scrolling up a little.
  final bool minimizeOnScroll;

  /// Caller-owned: forces the tab-bar layout even when
  /// [AdaptiveNavigationStyle.sidebarAdaptable] and the era/form-factor would
  /// otherwise prefer a sidebar. Ignored by every other [style]. Toggle it
  /// with [AdaptiveSidebarToggleButton].
  final bool sidebarCollapsed;

  /// HIG's sidebars page: content can extend beneath the sidebar via
  /// `backgroundExtensionEffect()`. Flutter chrome cannot call that API, so
  /// this reproduces the *look* — the sidebar floats as a glass overlay over
  /// full-width content instead of sharing a row with it — the same
  /// "look, not the material" caveat [GlassSurface] already documents.
  /// Has no effect on eras without glass.
  final bool extendContentBehindSidebar;

  /// A MiniPlayer-style view shown alongside the floating tab bar, and
  /// collapsed together with it when [minimizeOnScroll] triggers. This is
  /// what gives `minimizeOnScroll` something to move inline with the bar —
  /// see its own doc comment.
  final Widget? accessory;

  /// Overrides the selected tab's colour — the label and, for an SF-Symbol
  /// tab, the glyph. Defaults to the ambient theme's accent colour when null
  /// (`CupertinoTheme`'s primary colour on the Dart capsule; the app's own
  /// tint on the native `UITabBar`, which otherwise takes no colour
  /// instruction from Dart at all).
  ///
  /// A destination's [AdaptiveDestination.iconImage] ignores this — a custom
  /// brand mark keeps its own colours on every path, the same reason it
  /// renders `.alwaysOriginal` rather than tinted on the native bar.
  final Color? selectedColor;

  /// Overrides the unselected tabs' colour. Defaults to the ambient theme's
  /// secondary label colour when null, matching [selectedColor].
  final Color? unselectedColor;

  bool _useSidebar(BuildContext context) {
    final config = context.adaptive;
    final prefersSidebar =
        config.era.prefersSidebarNavigation && config.formFactor.isExpanded;
    return switch (style) {
      AdaptiveNavigationStyle.sidebar => true,
      AdaptiveNavigationStyle.tabBar => false,
      AdaptiveNavigationStyle.automatic => prefersSidebar,
      AdaptiveNavigationStyle.sidebarAdaptable =>
        !sidebarCollapsed && prefersSidebar,
    };
  }

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.length >= 2,
      'AdaptiveNavigationScaffold needs at least two destinations.',
    );
    assert(
      selectedIndex >= 0 && selectedIndex < destinations.length,
      'selectedIndex $selectedIndex is out of range.',
    );

    return _useSidebar(context)
        ? _buildSidebarLayout(context)
        : _buildTabLayout(context);
  }

  Widget _buildSidebarLayout(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    final sidebar = SizedBox(
      key: adaptiveSidebarKey,
      width: sidebarWidth,
      child: ConditionalGlass(
        tokens: tokens,
        borderRadius: BorderRadius.zero,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing * 2),
            children: [
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.horizontalPadding,
                    tokens.spacing,
                    tokens.horizontalPadding,
                    tokens.spacing * 2,
                  ),
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: era.isPointerFirst ? 15 : 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final (index, destination) in destinations.indexed)
                _SidebarRow(
                  destination: destination,
                  selected: index == selectedIndex,
                  onTap: () => onDestinationSelected(index),
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                ),
            ],
          ),
        ),
      ),
    );

    final divider = Container(
      width: tokens.separatorThickness,
      color: _separatorColor(context),
    );

    // The key resets the pane's stack when the destination changes, so
    // switching sections does not leave you three levels deep in the previous
    // one — the same thing iPadOS does.
    //
    // The root route's builder cannot just close over `body` — `onGenerateRoute`
    // only runs again for routes pushed *after* this build, so the very first
    // (root) route would freeze on whatever `body` looked like the moment the
    // destination was first shown, and every later rebuild of this scaffold
    // (an era override changing, a value the page reads from its constructor
    // rather than an `InheritedWidget` changing) would silently stop reaching
    // it. Routing the current `body` through `_DetailBodyHost` and reading it
    // from `context` inside the builder keeps the root route live instead.
    final Widget detail = detailNavigator
        ? _DetailBodyHost(
            body: body,
            child: Navigator(
              key: ValueKey<int>(selectedIndex),
              onGenerateRoute: (settings) => adaptivePageRoute<void>(
                context: context,
                builder: (context) => _DetailBodyHost.of(context),
                settings: settings,
              ),
            ),
          )
        : body;

    if (extendContentBehindSidebar && tokens.hasGlass) {
      // detail fills the full width and the glass sidebar floats over it, so
      // content is visible/blurred through the sidebar rather than stopping
      // where the sidebar begins.
      return _hostSurface(
        context,
        Stack(
          children: [
            Positioned.fill(child: detail),
            Positioned(top: 0, bottom: 0, left: 0, child: sidebar),
          ],
        ),
      );
    }

    return _hostSurface(
      context,
      Row(children: [sidebar, divider, Expanded(child: detail)]),
    );
  }

  Widget _buildTabLayout(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    if (era.isApple) {
      if (!tokens.hasGlass) {
        // Classic Cupertino: an opaque bar pinned to the bottom edge, which is
        // exactly what CupertinoTabBar is built for.
        return _hostSurface(
          context,
          Column(
            children: [
              Expanded(child: body),
              CupertinoTabBar(
                key: adaptiveTabBarKey,
                currentIndex: selectedIndex,
                onTap: onDestinationSelected,
                activeColor: selectedColor,
                inactiveColor: unselectedColor ?? CupertinoColors.inactiveGray,
                items: [
                  for (final destination in destinations)
                    BottomNavigationBarItem(
                      icon: destination.resolveIcon(era, selected: false),
                      activeIcon: destination.resolveIcon(era, selected: true),
                      label: destination.label,
                    ),
                ],
              ),
            ],
          ),
        );
      }

      // iOS 26 floats the tab bar as a capsule that hugs its own content and
      // sits above the home indicator, with the page passing underneath.
      //
      // CupertinoTabBar is deliberately not reused here: it is designed to be
      // pinned full-width to the bottom edge, it adds the bottom safe area to
      // its own height, and it draws a top border — all three fight a floating
      // capsule, which is why an earlier version came out as a stretched
      // rounded strip rather than a pill.
      return _hostSurface(
        context,
        _GlassTabScaffold(
          body: body,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          tokens: tokens,
          minimizeOnScroll: minimizeOnScroll,
          // iPadOS puts the tab bar near the top of the screen; only iPhone
          // floats it at the bottom.
          atTop: context.adaptive.formFactor.isExpanded,
          accessory: accessory,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
        ),
      );
    }

    // M3E's flexible nav bar lays items out horizontally with a fixed width
    // in medium (expanded) windows, instead of the baseline bar's vertical,
    // equal-fit items. Flutter's own NavigationBar has no such mode, so this
    // is a purpose-built variant used only for that one condition — the
    // baseline bar below is untouched for every other case.
    if (era.isExpressive && context.adaptive.formFactor.isExpanded) {
      return Scaffold(
        body: body,
        bottomNavigationBar: _FlexibleNavigationBar(
          key: adaptiveTabBarKey,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: _themedNavigationBar(
        NavigationBar(
          key: adaptiveTabBarKey,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          // Material 3 Expressive retires the baseline navigation bar in
          // favour of a "flexible" one that is shorter and keeps labels
          // visible. Flutter ships the baseline widget, so the difference is
          // expressed through its own knobs rather than by pretending the
          // flexible variant exists.
          height: era.isExpressive ? 64 : null,
          labelBehavior: era.isExpressive
              ? NavigationDestinationLabelBehavior.alwaysShow
              : null,
          indicatorShape: era.isExpressive ? const StadiumBorder() : null,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: _badged(destination.icon, destination.badge),
                selectedIcon: destination.selectedIcon == null
                    ? null
                    : _badged(destination.selectedIcon!, destination.badge),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }

  /// Applies [selectedColor]/[unselectedColor] to a Material `NavigationBar`
  /// via its theme, since the widget itself takes no colour parameters
  /// directly. Returns [bar] unchanged when neither override is set, so the
  /// ambient `Theme`'s own colours still apply exactly as before.
  Widget _themedNavigationBar(Widget bar) {
    if (selectedColor == null && unselectedColor == null) return bar;
    Color? colorFor(Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? selectedColor : unselectedColor;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: colorFor(states)),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(color: colorFor(states)),
        ),
      ),
      child: bar,
    );
  }

  /// Wraps Apple layouts in the scaffold that provides background colour and
  /// safe-area metrics, so callers never need a `CupertinoPageScaffold` of
  /// their own.
  Widget _hostSurface(BuildContext context, Widget child) {
    return context.era.isApple
        ? CupertinoPageScaffold(child: child)
        : Scaffold(body: child);
  }

  Color _separatorColor(BuildContext context) {
    return context.era.isApple
        ? CupertinoColors.separator.resolveFrom(context)
        : Theme.of(context).dividerColor;
  }
}

/// Carries the sidebar detail pane's current [body] past the per-tab
/// [Navigator] that wraps it, so the root route can read the live widget from
/// `context` on every rebuild instead of the one captured when the route was
/// first pushed. See the comment above this widget's use in
/// [AdaptiveNavigationScaffold._buildSidebarLayout].
class _DetailBodyHost extends InheritedWidget {
  const _DetailBodyHost({required this.body, required super.child});

  final Widget body;

  static Widget of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<_DetailBodyHost>();
    assert(host != null, '_DetailBodyHost.of() called outside its host.');
    return host!.body;
  }

  @override
  bool updateShouldNotify(_DetailBodyHost oldWidget) => body != oldWidget.body;
}

/// Lays the page out under a floating glass bar and keeps the two in step.
///
/// Three things have to stay coordinated and are easy to get wrong separately:
/// the bar's position (bottom on iPhone, top on iPad), the inset the page needs
/// so its content is not permanently hidden behind the bar, and what happens
/// when the keyboard appears.
class _GlassTabScaffold extends StatefulWidget {
  const _GlassTabScaffold({
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.tokens,
    required this.minimizeOnScroll,
    required this.atTop,
    this.accessory,
    this.selectedColor,
    this.unselectedColor,
  });

  final Widget body;
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AdaptiveTokens tokens;
  final bool minimizeOnScroll;
  final bool atTop;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Widget? accessory;

  @override
  State<_GlassTabScaffold> createState() => _GlassTabScaffoldState();
}

class _GlassTabScaffoldState extends State<_GlassTabScaffold> {
  bool _minimized = false;

  bool _onScroll(UserScrollNotification notification) {
    if (!widget.minimizeOnScroll) return false;

    // Apple's rule: minimise on scroll down, and restore when a tab is tapped
    // or the view is scrolled back to the top. Restoring on any upward scroll
    // would make the bar flicker in and out during ordinary reading.
    final metrics = notification.metrics;
    final atTopOfList = metrics.pixels <= metrics.minScrollExtent + 1;
    final next = atTopOfList
        ? false
        : switch (notification.direction) {
            ScrollDirection.reverse => true,
            _ => _minimized,
          };

    if (next != _minimized) setState(() => _minimized = next);
    return false;
  }

  void _select(int index) {
    if (_minimized) setState(() => _minimized = false);
    widget.onDestinationSelected(index);
  }

  /// Takes [bar] out of composition while a pushed route covers it.
  ///
  /// Only needed for the native bar, and it is not cosmetic. A platform view is a
  /// real `UIView` in the UIKit hierarchy, and `Navigator` keeps this route alive
  /// underneath the pushed one — so the `UITabBar` stays mounted and Flutter has
  /// to draw the covering page in an *overlay* above it. That overlay is where the
  /// bar bleeds through onto the pushed page. It also keeps claiming touches in
  /// its own frame, because [_NativeTabBar] hands it an eager recogniser. The Dart
  /// capsule has neither problem: it is Flutter paint, so an opaque route simply
  /// covers it.
  ///
  /// Hidden for the whole push, not just once it finishes: an earlier version
  /// waited for the *secondary* animation to reach `completed` — "the route
  /// above me has finished arriving" — but a platform view keeps compositing
  /// on top of the Flutter-drawn transition for that entire animation, so the
  /// bar visibly bled through the incoming page for the whole push instead of
  /// disappearing with it. Hiding as soon as `secondary` leaves `dismissed`
  /// tracks the same animation frame the slide transition itself starts on,
  /// so it reads as "gone with the page," not merely "before" or "after" it —
  /// the concern that ruled out `ModalRoute.isCurrent`, which flips the
  /// instant `Navigator.push` is called, before the first transition frame.
  ///
  /// `maintainState` keeps the element mounted, so the `UITabBar` is hidden rather
  /// than destroyed and recreated on every push and pop.
  Widget _hideWhenCovered(BuildContext context, Widget bar) {
    final secondary = ModalRoute.of(context)?.secondaryAnimation;
    if (secondary == null) return bar;

    return AnimatedBuilder(
      animation: secondary,
      child: bar,
      builder: (context, child) => Visibility(
        visible: secondary.status == AnimationStatus.dismissed ||
            secondary.status == AnimationStatus.reverse,
        maintainState: true,
        child: child!,
      ),
    );
  }

  /// Whether the host can give us a real `UITabBar` for these destinations.
  ///
  /// Two conditions, both necessary. The host must advertise the component —
  /// which it only does on iOS 26 with the factory actually registered — and
  /// every destination must carry an icon the native side can turn into a
  /// `UIImage` — an SF Symbol or a custom asset/bytes (see
  /// [AdaptiveDestination.hasNativeIcon]) — because a Flutter widget cannot
  /// become one. Failing either, the Dart capsule renders instead, which is
  /// the whole point of probing rather than inferring.
  bool _useNativeBar(BuildContext context) {
    if (!AdaptiveScope.of(context)
        .strategyFor(NativeComponents.tabBar)
        .isNative) {
      return false;
    }
    return widget.destinations.every((d) => d.hasNativeIcon);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final media = MediaQuery.of(context);
    final native = _useNativeBar(context);

    // A keyboard takes the bar's place at the bottom of the screen. Leaving it
    // floating above the keyboard is both wrong and in the way.
    final hidden = !widget.atTop && media.viewInsets.bottom > 0;
    // Minimising is a Dart-path affordance. The native bar manages its own
    // layout, and Apple frames minimising as behaviour "for tab bars with an
    // attached accessory" anyway — not something to impose on the system bar.
    final barHeight =
        _minimized && !native ? _kGlassPillMinimizedHeight : _kGlassPillHeight;
    // The accessory collapses together with the bar when minimising — the
    // whole reason minimizeOnScroll exists is to make room by moving this
    // group out of the way as a unit.
    final showAccessory = widget.accessory != null && !_minimized;
    final accessorySpace =
        showAccessory ? _kAccessoryHeight + tokens.spacing : 0.0;
    final inset =
        hidden ? 0.0 : barHeight + accessorySpace + tokens.spacing * 2;

    final padded = MediaQuery(
      data: media.copyWith(
        padding: widget.atTop
            ? media.padding.copyWith(top: media.padding.top + inset)
            : media.padding.copyWith(bottom: media.padding.bottom + inset),
      ),
      child: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: widget.body,
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: padded),
        if (!hidden)
          Positioned(
            left: 0,
            right: 0,
            top: widget.atTop ? 0 : null,
            bottom: widget.atTop ? null : 0,
            child: SafeArea(
              top: widget.atTop,
              bottom: !widget.atTop,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing * 2,
                  vertical: tokens.spacing,
                ),
                child: _buildBarGroup(context, tokens, native, showAccessory),
              ),
            ),
          ),
      ],
    );
  }

  /// The bar, plus [widget.accessory] when present — accessory above the bar
  /// on iPhone (where the bar is pinned to the bottom edge, MiniPlayer-style),
  /// below it on iPad (where the bar sits at the top instead).
  Widget _buildBarGroup(
    BuildContext context,
    AdaptiveTokens tokens,
    bool native,
    bool showAccessory,
  ) {
    final bar = native
        ? _hideWhenCovered(
            context,
            SizedBox(
              height: _kGlassPillHeight,
              child: _NativeTabBar(
                key: adaptiveTabBarKey,
                destinations: widget.destinations,
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: _select,
                selectedColor: widget.selectedColor,
                unselectedColor: widget.unselectedColor,
              ),
            ),
          )
        : _GlassTabBar(
            key: adaptiveTabBarKey,
            destinations: widget.destinations,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: _select,
            tokens: tokens,
            minimized: _minimized,
            selectedColor: widget.selectedColor,
            unselectedColor: widget.unselectedColor,
          );

    final accessoryWidget = widget.accessory;
    if (accessoryWidget == null) return bar;

    final accessoryChild = AnimatedOpacity(
      opacity: showAccessory ? 1 : 0,
      duration: tokens.motionDuration,
      curve: tokens.motionCurve,
      child: showAccessory
          ? Padding(
              padding: EdgeInsets.only(
                bottom: widget.atTop ? 0 : tokens.spacing,
                top: widget.atTop ? tokens.spacing : 0,
              ),
              child: SizedBox(
                height: _kAccessoryHeight,
                child: accessoryWidget,
              ),
            )
          : const SizedBox.shrink(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.atTop ? [bar, accessoryChild] : [accessoryChild, bar],
    );
  }
}

/// A real `UITabBar`, embedded as a platform view.
///
/// Everything that makes an iOS 26 tab bar feel like one is the system's work
/// here: the Liquid Glass material, the selection morph, and the interactive
/// liquid response when a tab is touched and held. None of it is reproducible
/// over Flutter content — `UIVisualEffectView` samples its backdrop from the
/// UIKit hierarchy and Flutter draws into a `CAMetalLayer` it cannot read — so
/// the control itself has to be real, exactly as with [AdaptiveSwitch] and
/// [AdaptiveSlider].
///
/// Selection flows both ways. Taps arrive as a `selected` event; a
/// [selectedIndex] that changes for any other reason — a deep link, a
/// programmatic jump — is pushed down over the same channel so the native bar
/// never disagrees with Dart about which tab is current.
class _NativeTabBar extends StatefulWidget {
  const _NativeTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.selectedColor,
    this.unselectedColor,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  State<_NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<_NativeTabBar> {
  MethodChannel? _channel;

  /// Null while a custom icon asset is still loading. `sfSymbol`-only bars
  /// — the common case — skip the async detour entirely and never see null.
  List<Uint8List?>? _iconBytes;
  List<Uint8List?>? _selectedIconBytes;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(_NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _channel?.invokeMethod<void>('setSelectedIndex', widget.selectedIndex);
    }
    if (!identical(widget.destinations, oldWidget.destinations)) {
      _loadIcons();
    }
  }

  /// Resolves [AdaptiveDestination.iconImage]/[AdaptiveDestination.iconSvgAsset]
  /// to PNG bytes. Skipped synchronously — no dropped frame, no `setState` —
  /// when every destination relies on [AdaptiveDestination.sfSymbol] alone,
  /// which is still the common case.
  void _loadIcons() {
    final destinations = widget.destinations;
    final needsImageLoad = destinations.any(
      (d) =>
          d.iconImage != null ||
          d.selectedIconImage != null ||
          d.iconSvgAsset != null ||
          d.selectedIconSvgAsset != null,
    );

    if (!needsImageLoad) {
      _iconBytes = List<Uint8List?>.filled(destinations.length, null);
      _selectedIconBytes = List<Uint8List?>.filled(destinations.length, null);
      return;
    }

    _iconBytes = null;
    _selectedIconBytes = null;
    Future.wait([
      Future.wait([
        for (final d in destinations)
          _resolveIcon(svgAsset: d.iconSvgAsset, provider: d.iconImage),
      ]),
      Future.wait([
        for (final d in destinations)
          _resolveIcon(
            svgAsset: d.selectedIconSvgAsset ?? d.iconSvgAsset,
            provider: d.selectedIconImage ?? d.iconImage,
          ),
      ]),
    ]).then((resolved) {
      if (!mounted) return;
      setState(() {
        _iconBytes = resolved[0];
        _selectedIconBytes = resolved[1];
      });
    });
  }

  /// [svgAsset] takes precedence over [provider], matching
  /// [AdaptiveDestination.iconSvgAsset]'s own doc comment.
  static Future<Uint8List?> _resolveIcon({
    String? svgAsset,
    ImageProvider? provider,
  }) async {
    if (svgAsset != null) {
      final rasterized = await _rasterizeSvg(svgAsset);
      if (rasterized != null) return rasterized;
    }
    return _resolveIconBytes(provider);
  }

  /// Rasterizes an SVG asset to PNG bytes at [_kNativeIconPixelSize],
  /// letterboxed to preserve its own aspect ratio — `flutter_svg` decodes the
  /// vector data, but a native `UIImage` needs raster pixels regardless.
  static Future<Uint8List?> _rasterizeSvg(String assetPath) async {
    try {
      final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetPath), null);
      try {
        const target = _kNativeIconPixelSize;
        final svgSize = pictureInfo.size;
        final scale = math.min(
          target / svgSize.width,
          target / svgSize.height,
        );
        final offset = Offset(
          (target - svgSize.width * scale) / 2,
          (target - svgSize.height * scale) / 2,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.translate(offset.dx, offset.dy);
        canvas.scale(scale);
        canvas.drawPicture(pictureInfo.picture);
        final scaledPicture = recorder.endRecording();

        final image = await scaledPicture.toImage(target, target);
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        scaledPicture.dispose();
        image.dispose();
        return byteData?.buffer.asUint8List();
      } finally {
        pictureInfo.picture.dispose();
      }
    } on Object {
      // Missing/unparsable SVG: falls through to iconImage, if any, exactly
      // as if iconSvgAsset had never been set.
      return null;
    }
  }

  /// Decodes [provider] through Flutter's own image pipeline — the same
  /// resolve/listen cycle `Image(image: provider)` uses — resized to
  /// [_kNativeIconPixelSize] so an arbitrarily large source asset still comes
  /// out at the tab bar's own icon size, and re-encodes the frame to PNG so
  /// it can cross the platform channel as bytes. [_kNativeIconScale] is sent
  /// alongside so the native side can recover the point size from the pixel
  /// size — see [_creationParams].
  static Future<Uint8List?> _resolveIconBytes(ImageProvider? provider) async {
    if (provider == null) return null;
    try {
      final resized = ResizeImage(
        provider,
        width: _kNativeIconPixelSize,
        height: _kNativeIconPixelSize,
      );
      final completer = Completer<ImageInfo>();
      final stream = resized.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, synchronousCall) {
          completer.complete(info);
          stream.removeListener(listener);
        },
        onError: (error, stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);

      final info = await completer.future;
      final byteData = await info.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } on Object {
      // Unresolvable image (bad asset key, failed network fetch): the native
      // side falls back to the SF Symbol, if any, exactly as if the caller
      // had never set this.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = widget.destinations;
    final iconBytes = _iconBytes;
    final selectedIconBytes = _selectedIconBytes;

    // Blank for the one frame a custom icon asset takes to load, rather than
    // creating the platform view with a hole where its image should be.
    if (iconBytes == null || selectedIconBytes == null) {
      return const SizedBox.shrink();
    }

    return NativeComponentView(
      viewType: 'dev.gauravraj/${NativeComponents.tabBar}',
      creationParams: <String, Object?>{
        'labels': <String>[for (final d in destinations) d.label],
        'symbols': <String>[for (final d in destinations) d.sfSymbol ?? ''],
        'selectedSymbols': <String>[
          for (final d in destinations) d.selectedSfSymbol ?? d.sfSymbol ?? '',
        ],
        'iconBytes': iconBytes,
        'selectedIconBytes': selectedIconBytes,
        'iconScale': _kNativeIconScale,
        'tintIcons': <bool>[
          for (final d in destinations) d._resolvedTintNativeIcon,
        ],
        'badges': <String?>[for (final d in destinations) d.badge],
        'selectedIndex': widget.selectedIndex,
        if (widget.selectedColor != null) 'tint': _argb(widget.selectedColor!),
        if (widget.unselectedColor != null)
          'unselectedTint': _argb(widget.unselectedColor!),
      },
      onChannelReady: (channel) => _channel = channel,
      onEvent: (event, payload) {
        if (event == 'selected' && payload is int) {
          widget.onDestinationSelected(payload);
        }
      },
      // A tab bar must win every touch outright. Without this the surrounding
      // Flutter gesture arena can claim the tap and the bar never responds —
      // and the liquid press animation never plays, because UIKit never sees
      // the touch begin.
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}

/// The floating capsule that replaces the pinned tab bar on glass eras.
///
/// It spans the width left over after the side margins rather than hugging its
/// content: that is what iOS 26 does, and it also means the bar can never
/// overflow no matter how many destinations an app declares. What makes it read
/// as floating is the margin, the fully-rounded radius, the shadow, and the
/// content visible through the glass behind it — not a narrower width.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.tokens,
    required this.minimized,
    this.selectedColor,
    this.unselectedColor,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AdaptiveTokens tokens;
  final bool minimized;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    // The radius stays at the full-height value even while minimised: a radius
    // larger than half the height is clamped to a capsule anyway, so the shape
    // reads correctly at both sizes without animating the corner.
    final radius = BorderRadius.circular(_kGlassPillHeight / 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.24),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: GlassSurface(
        tokens: tokens,
        borderRadius: radius,
        interactive: true,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing * 0.75),
        child: AnimatedContainer(
          duration: tokens.motionDuration,
          curve: tokens.motionCurve,
          height: minimized ? _kGlassPillMinimizedHeight : _kGlassPillHeight,
          child: Row(
            children: [
              for (final (index, destination) in destinations.indexed)
                Expanded(
                  child: _GlassTab(
                    destination: destination,
                    selected: index == selectedIndex,
                    onTap: () => onDestinationSelected(index),
                    tokens: tokens,
                    minimized: minimized,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.tokens,
    required this.minimized,
    this.selectedColor,
    this.unselectedColor,
  });

  final AdaptiveDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final AdaptiveTokens tokens;
  final bool minimized;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? CupertinoTheme.of(context).primaryColor;
    final color = selected
        ? accent
        : unselectedColor ??
            CupertinoColors.secondaryLabel.resolveFrom(context);
    final inset = tokens.spacing * 0.75;
    final pill = minimized ? _kGlassPillMinimizedHeight : _kGlassPillHeight;
    final height = pill - inset * 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: tokens.motionDuration,
        curve: tokens.motionCurve,
        height: height,
        margin: EdgeInsets.symmetric(
          vertical: inset,
          horizontal: tokens.spacing * 0.25,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: selected ? accent.withValues(alpha: 0.16) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(
              data: IconThemeData(color: color, size: 24),
              child: destination.resolveIcon(
                context.era,
                selected: selected,
              ),
            ),
            if (!minimized) const SizedBox(height: 2),
            if (!minimized)
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  });

  final AdaptiveDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;
    final accent = selectedColor ??
        (era.isApple
            ? CupertinoTheme.of(context).primaryColor
            : Theme.of(context).colorScheme.primary);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing,
        vertical: tokens.spacing * 0.25,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: tokens.motionDuration,
          curve: tokens.motionCurve,
          height: era.isPointerFirst ? 28 : 44,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing * 1.5),
          decoration: BoxDecoration(
            borderRadius: tokens.radius(tokens.cornerRadius * 0.5),
            color: selected ? accent.withValues(alpha: 0.16) : null,
          ),
          child: Row(
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  color: selected ? accent : unselectedColor,
                  size: era.isPointerFirst ? 16 : 22,
                ),
                child: destination.resolveIcon(era, selected: selected),
              ),
              SizedBox(width: tokens.spacing * 1.5),
              Expanded(
                child: Text(
                  destination.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: era.isPointerFirst ? 13 : 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? accent : unselectedColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [icon] in Flutter's own `Badge` widget when [value] is present —
/// the Material idiom for a badge, used by the baseline and flexible nav
/// bars instead of [AdaptiveDestination]'s Dart-drawn pill.
Widget _badged(Widget icon, String? value) {
  if (value == null) return icon;
  return Badge(label: Text(value), child: icon);
}

/// Packs [color] into Flutter's 32-bit ARGB integer, the form
/// `UIColor(argb:)` on the native side already expects. `Color`'s own
/// channels are 0.0-1.0 doubles rather than 0-255 ints since Flutter's wide
/// gamut change, so this rounds rather than truncating.
int _argb(Color color) =>
    ((color.a * 255.0).round() & 0xff) << 24 |
    ((color.r * 255.0).round() & 0xff) << 16 |
    ((color.g * 255.0).round() & 0xff) << 8 |
    ((color.b * 255.0).round() & 0xff);

/// M3E's flexible navigation bar in a medium (expanded) window: fixed-width
/// items laid out horizontally with extra space at the ends, instead of the
/// baseline bar's vertical items that stretch to equally fill the container.
/// Flutter's `NavigationBar` has no such mode, so this is a purpose-built
/// variant — used only when [DesignEra.isExpressive] and the window is
/// expanded; every other case still gets the baseline `NavigationBar`.
class _FlexibleNavigationBar extends StatelessWidget {
  const _FlexibleNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.selectedColor,
    this.unselectedColor,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, destination) in destinations.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 80,
                      child: _FlexibleNavigationItem(
                        destination: destination,
                        selected: index == selectedIndex,
                        onTap: () => onDestinationSelected(index),
                        selectedColor: selectedColor,
                        unselectedColor: unselectedColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlexibleNavigationItem extends StatelessWidget {
  const _FlexibleNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  });

  final AdaptiveDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = selected
        ? selectedColor ?? scheme.onSecondaryContainer
        : unselectedColor ?? scheme.onSurfaceVariant;
    final textColor = selected
        ? selectedColor ?? scheme.onSurface
        : unselectedColor ?? scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? scheme.secondaryContainer : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: IconTheme.merge(
                  data: IconThemeData(color: iconColor),
                  child: _badged(destination.icon, destination.badge),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                destination.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `sidebarAdaptable` conversion affordance: toggles
/// [AdaptiveNavigationScaffold.sidebarCollapsed]. Drop this in
/// `AdaptiveScaffold.leading` on a sidebar-adaptable screen.
class AdaptiveSidebarToggleButton extends StatelessWidget {
  const AdaptiveSidebarToggleButton({
    super.key,
    required this.collapsed,
    required this.onChanged,
  });

  final bool collapsed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    return era.isApple
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size(tokens.minTapTarget, tokens.minTapTarget),
            onPressed: () => onChanged(!collapsed),
            child: const Icon(CupertinoIcons.sidebar_left),
          )
        : IconButton(
            onPressed: () => onChanged(!collapsed),
            icon: const Icon(Icons.menu),
          );
  }
}
