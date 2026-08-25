import '../core/design_era.dart';
import '../core/native_bridge.dart';
import '../core/native_component_view.dart';
import '../design_systems/design_imports.dart';
import '../effects/liquid_glass.dart';
import '../tokens/adaptive_tokens.dart';
import 'adaptive_base.dart';

/// Visual weight of an [AdaptiveButton], expressed in intent rather than in any
/// one design system's vocabulary.
///
/// Each era maps these onto its own idiom: [AdaptiveButtonStyle.prominent] is a
/// filled Material button on Android and a filled Cupertino button on Apple
/// platforms — the same intent, each platform's own answer.
enum AdaptiveButtonStyle {
  /// The primary action on a screen. One per screen, ideally.
  prominent,

  /// A secondary action with a visible container.
  tonal,

  /// A low-emphasis action with no container.
  plain,

  /// A destructive action. Red on every era, but the *shape* still adapts.
  destructive,

  /// A glass button for the functional layer — bars, toolbars, floating bars.
  ///
  /// Unlike the other styles this one *is* made of Liquid Glass on iOS 26,
  /// with the interactive material that animates on touch. Use it for chrome,
  /// not content: Apple's guidance reserves glass for the functional layer.
  glass,
}

/// A button that renders in the host platform's current design language.
///
/// ```dart
/// AdaptiveButton(
///   onPressed: _save,
///   style: AdaptiveButtonStyle.prominent,
///   child: const Text('Save'),
/// )
/// ```
///
/// Buttons live in the content layer, so they are deliberately **not** made of
/// Liquid Glass on iOS 26 — Apple's guidance reserves that material for bars,
/// sidebars, alerts and popovers. What the era changes here is geometry: iOS 26
/// gets a taller control with a wider, continuous corner radius and a press
/// that shrinks; iOS 18 keeps the tighter classic shape; Android 16 adds
/// Material 3 Expressive's spring press feedback over Material 3's ripple.
///
/// Every Apple era enforces a 44x44pt minimum hit region, the one hard number
/// Apple's guidance states for touch targets.
class AdaptiveButton extends StatelessWidget with AdaptiveRenderMixin {
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style = AdaptiveButtonStyle.prominent,
    this.icon,
    this.expand = false,
    this.preferNative,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AdaptiveButtonStyle style;

  /// Optional leading icon, drawn at the era's own icon size and gap.
  final Widget? icon;

  /// Stretches the button to the width of its parent.
  final bool expand;

  @override
  final bool? preferNative;

  @override
  String? get nativeComponent => NativeComponents.glassButton;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    // A native control takes a plain string title, so a rich [child] cannot
    // cross the channel. Rather than flattening it and losing a badge or an
    // inline icon, such a button quietly stays in Dart.
    final title = _plainLabel(child);
    final isGlassStyle = style == AdaptiveButtonStyle.glass;

    // The native glass button takes a plain string title, so a rich [child]
    // cannot cross the channel. The glass style goes native whenever the
    // strategy allows it (the native UIButton.Configuration.glass() handles
    // its own title display); other styles only go native for plain Text.
    if (strategyFor(context).isNative &&
        tokens.hasGlass &&
        (isGlassStyle || title != null)) {
      return _buildNative(tokens, title ?? '');
    }

    // The glass style wraps a Cupertino button in an interactive GlassSurface
    // so the Dart fallback still reads as glass on touch.
    if (isGlassStyle && era.isApple && tokens.hasGlass) {
      final cupertino = _buildCupertino(context, tokens);
      return GlassSurface(
        tokens: tokens,
        interactive: true,
        borderRadius: tokens.radius(),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.horizontalPadding,
          vertical: tokens.verticalPadding,
        ),
        child: cupertino,
      );
    }

    // Apple eras all render a Cupertino button, glass or not.
    //
    // An earlier version gave every button a Liquid Glass background on iOS 26,
    // which reads well in a screenshot and is wrong. Apple's Materials guidance
    // is explicit: "Don't use Liquid Glass in the content layer… Limit these
    // effects to the most important functional elements in your app." Glass
    // belongs to bars, sidebars, alerts and popovers — the functional layer —
    // and an ordinary button sitting in a form or a list is content.
    //
    // What *does* change between iOS 18 and iOS 26 here is geometry, and that
    // comes from the era's tokens: a taller control, a wider corner radius, and
    // a press that shrinks rather than only dimming.
    final Widget button = switch (era) {
      DesignEra.iosLiquidGlass ||
      DesignEra.ipadLiquidGlass ||
      DesignEra.macosTahoe ||
      DesignEra.iosClassic ||
      DesignEra.ipadClassic ||
      DesignEra.macosClassic =>
        _buildCupertino(context, tokens),
      _ => _buildMaterial(context, tokens),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildNative(AdaptiveTokens tokens, String title) {
    return NativeComponentView(
      viewType: 'dev.gauravraj/${NativeComponents.glassButton}',
      creationParams: <String, Object?>{
        'style': style.name,
        'title': title,
        'enabled': _enabled,
      },
      fallbackSize: Size(expand ? double.infinity : 140, tokens.controlHeight),
      onEvent: (event, _) {
        if (event == 'pressed') onPressed?.call();
      },
    );
  }

  Widget _buildCupertino(BuildContext context, AdaptiveTokens tokens) {
    final accent = _accentColor(context);
    final isFilled = style == AdaptiveButtonStyle.prominent ||
        style == AdaptiveButtonStyle.destructive;
    final content = _label(
      context,
      color: isFilled ? CupertinoColors.white : accent,
      tokens: tokens,
    );

    // 44x44pt is the one hard number Apple's guidance gives for hit regions,
    // and it is the floor on every Apple era.
    final minSize = tokens.minTapTarget;

    if (style == AdaptiveButtonStyle.prominent) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        borderRadius: tokens.radius(),
        minimumSize: Size(minSize, minSize),
        child: content,
      );
    }
    return CupertinoButton(
      onPressed: onPressed,
      borderRadius: tokens.radius(),
      minimumSize: Size(minSize, minSize),
      color: switch (style) {
        AdaptiveButtonStyle.tonal => accent.withValues(alpha: 0.12),
        AdaptiveButtonStyle.destructive =>
          CupertinoColors.destructiveRed.resolveFrom(context),
        AdaptiveButtonStyle.glass => null,
        _ => null,
      },
      child: content,
    );
  }

  Widget _buildMaterial(BuildContext context, AdaptiveTokens tokens) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: tokens.radius());
    final padding = EdgeInsets.symmetric(
      horizontal: tokens.horizontalPadding,
      vertical: tokens.verticalPadding,
    );
    final content = _materialContent(tokens);

    final Widget button = switch (style) {
      AdaptiveButtonStyle.glass => FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(shape: shape, padding: padding),
          child: content,
        ),
      AdaptiveButtonStyle.prominent => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(shape: shape, padding: padding),
          child: content,
        ),
      AdaptiveButtonStyle.tonal => FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(shape: shape, padding: padding),
          child: content,
        ),
      AdaptiveButtonStyle.plain => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(shape: shape, padding: padding),
          child: content,
        ),
      AdaptiveButtonStyle.destructive => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            shape: shape,
            padding: padding,
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: content,
        ),
    };

    // Material 3 Expressive's press feedback is a spring squash the standard
    // button does not provide, so on that era the button is wrapped rather
    // than restyled.
    if (!tokens.era.isExpressive) return button;
    return AdaptivePressable(
      onPressed: onPressed,
      enabled: _enabled,
      child: IgnorePointer(child: button),
    );
  }

  Widget _materialContent(AdaptiveTokens tokens) {
    final iconWidget = icon;
    if (iconWidget == null) return child;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [iconWidget, SizedBox(width: tokens.spacing), child],
    );
  }

  Widget _label(
    BuildContext context, {
    required Color color,
    required AdaptiveTokens tokens,
  }) {
    final text = DefaultTextStyle.merge(
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: tokens.era.isPointerFirst ? 13 : 17,
      ),
      child: child,
    );
    final iconWidget = icon;
    if (iconWidget == null) {
      return Center(widthFactor: 1, heightFactor: 1, child: text);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme.merge(data: IconThemeData(color: color), child: iconWidget),
        SizedBox(width: tokens.spacing),
        text,
      ],
    );
  }

  Color _accentColor(BuildContext context) {
    if (style == AdaptiveButtonStyle.destructive) {
      return CupertinoColors.destructiveRed.resolveFrom(context);
    }
    return CupertinoTheme.of(context).primaryColor;
  }

  static String? _plainLabel(Widget child) => child is Text ? child.data : null;
}
