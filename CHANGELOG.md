# Changelog

## 0.1.2

- Shortened `pubspec.yaml`'s `description` to pub.dev's 60-180 character
  limit (was 196 characters, costing 10 pub points under "Follow Dart file
  conventions"). No code changes.

## 0.1.1

- Fixed the README's screenshot gallery not rendering on pub.dev. It used raw
  HTML `<img>` tags inside a `<table>`, which render fine on GitHub but get
  stripped by pub.dev's README sanitizer — only plain Markdown image syntax
  (`![alt](path)`) gets resolved against the repository. No code changes.

## 0.1.0

First release.

Fixed before release, from device testing on iOS 26 and iPad:

- The sidebar layout's detail pane could go stale after its first build.
  `AdaptiveNavigationScaffold`'s per-tab `Navigator` captured `body` in a
  closure at first push; `onGenerateRoute` only reruns for newly pushed
  routes, so a later rebuild — the Design tab's era picker, for one — never
  reached the mounted root route, and state built from a constructor field
  (like the "Preview as" checkmark) froze while the surrounding chrome kept
  re-theming correctly. The current `body` now reaches the root route through
  an `InheritedWidget` instead.
- The anchored popover sat 6pt off its anchor with no shadow, reading as a
  flat card pasted on the page rather than a card floating above it; it now
  keeps a visible gap, a shadow, and an arrow colour matched to the glass
  card's own tint. Popover content is also wrapped in a transparent
  `Material`, so content with no Material ancestor of its own (a plain
  `Text`, dropped into the popover from an Android build) no longer falls
  back to Flutter's debug text style.
- Cupertino glyphs rendered as "?" boxes. The package draws from the
  CupertinoIcons font (`CupertinoListTileChevron` and friends) but did not
  depend on `cupertino_icons`, so the font never reached consuming apps.
- Scrolling content sat behind the navigation bar. `AdaptiveScaffold` forced the
  Cupertino bar transparent, which removed its blur *and* stopped
  `CupertinoPageScaffold` from reporting the bar's height through `MediaQuery`.
  The bar now keeps its own translucency, and
  `AdaptiveContext.adaptiveScrollPadding` gives bodies with custom padding the
  right inset.
- The floating iOS 26 tab bar was wrong in shape as well as position. It reused
  `CupertinoTabBar`, which is built to be pinned full-width to the bottom edge,
  adds the bottom safe area to its own height and draws a top border — so it
  came out as a stretched rounded strip rather than a capsule. Glass eras now
  use a purpose-built floating bar, and the body is told about its height
  through `MediaQuery` so lists no longer end underneath it.
- `adaptiveTabBarKey` and `adaptiveSidebarKey` are exported so tests can tell
  the two layouts apart without knowing which era produced them.

Found by looking at an actual iOS 26 simulator build rather than reasoning about
it — each of these is invisible in code review and obvious in a screenshot:

- **Every string in an iOS build was rendered in Roboto, not San Francisco.**
  `Material` wraps its child in `AnimatedDefaultTextStyle(style: widget.textStyle
  ?? Theme.of(context).textTheme.bodyMedium!)`, so the transparent `Material`
  that `AdaptiveApp` inserts to keep Material widgets usable inside a
  `CupertinoApp` was also handing the whole app Material's typography. It now
  passes the Cupertino text style explicitly. Nothing else has to be wrong for
  this alone to make an iOS build look like an Android one.
- Glass surfaces tinted with black in light mode, turning the tab bar into a
  muddy grey slab. Apple's material is a light one — it adjusts luminosity
  rather than darkening — so the tint is now white-based in both themes.
- Inset-grouped list headers rendered at Flutter's 20pt bold and footers at the
  full 17pt body style. iOS renders both as 13pt secondary label.
- Grouped list screens sat on a white background, so the cards had nothing to
  float on and the grouping stopped reading. `AdaptiveScaffold.grouped` sets the
  platform's grouped background.
- `AdaptiveDestination` gained `appleIcon` / `appleSelectedIcon`. Material glyphs
  in an iOS tab bar are the fastest way to give a build away, and Apple's
  guidance asks for SF Symbols.

Corrected against Apple's Human Interface Guidelines and Material 3 specs:

- Liquid Glass was being applied to ordinary buttons. Apple's Materials guidance
  says "Don't use Liquid Glass in the content layer"; the material belongs to
  bars, sidebars, alerts and popovers. `AdaptiveButton` now renders a Cupertino
  button on every Apple era and expresses the era through geometry instead.
- Apple's 44x44pt minimum hit region is now enforced on Apple-era buttons.
- Tab-bar minimising is off by default. Apple frames it as behaviour for bars
  with an attached accessory, and restores the bar on a tab tap or a scroll back
  to the top rather than on any upward scroll.
- iPadOS places the tab bar near the top of the screen, not the bottom;
  `AdaptiveNavigationStyle.tabBar` now does that. `AdaptiveNavigationStyle`
  replaces the previous `forceTabBar` flag.
- Popovers are chosen by window size class rather than device, matching "Avoid
  displaying popovers in compact views".
- Action sheets order destructive choices first and Cancel last, and alerts
  assert Apple's three-button limit.
- Segmented controls assert Apple's five-segment limit in compact windows.
- Material 3 Expressive components now actually differ from Material 3: the
  slider gets the 2024 drawing (4dp bar handle, track gap, stop indicator), the
  switch carries a check icon on the selected thumb, progress indicators get the
  wavy track, and the navigation bar is shorter with a stadium indicator,
  approximating M3 Expressive's "flexible" bar.
- A keyboard now hides the floating bar instead of leaving it stranded above the
  keyboard, and `adaptiveScrollPadding` accounts for `viewInsets`.
- Pushing a route on iPad replaced the whole window instead of the detail pane.
  The sidebar layout now hosts its own `Navigator`; see
  `AdaptiveNavigationScaffold.detailNavigator`.
- `GlassSurface.tintOpacity` was added so bar and sidebar surfaces can be tinted
  independently of the era's default chrome opacity.

- Swift Package Manager support on iOS and macOS, with the CocoaPods podspecs
  kept as a fallback and pointed at the same sources.
- `PrivacyInfo.xcprivacy` for both Apple platforms.
- Android compiles against API 36 (Android 16) with Kotlin 2.1, AGP 8.7, JVM 17.

- `DesignEra` resolution from platform, OS version and form factor: iOS 26 /
  iPadOS 26 / macOS Tahoe Liquid Glass, classic Cupertino, Material 3
  Expressive (Android 16+), Material 3, and Material 3 without dynamic colour.
- Native-first rendering with a Dart fallback for every widget, controlled by
  `NativePolicy` and a per-device capability probe.
- Widgets: `AdaptiveApp`, `AdaptiveScaffold`, `AdaptiveNavigationScaffold`,
  `AdaptiveButton`, `AdaptiveSwitch`, `AdaptiveSlider`, `AdaptiveTextField`,
  `AdaptiveSegmentedControl`, `AdaptiveListSection`, `AdaptiveListTile`,
  `AdaptiveProgressIndicator`, `AdaptivePressable`, `GlassSurface`,
  `ConditionalGlass`.
- Functions: `showAdaptiveAlert`, `showAdaptiveActionSheet`,
  `adaptivePageRoute`, `pushAdaptive`.
- iPad and macOS layout idioms: sidebar navigation on expanded windows,
  popovers instead of bottom sheets, pointer-first densities.
- Design tokens per era, with continuous-corner and concentric-radius helpers.
- `PlatformInfo.fake` and `NativeAdaptiveUi.debugSetPlatform` for rendering any
  era on any machine in tests and design review.
