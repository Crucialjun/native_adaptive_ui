# native_adaptive_ui — handoff

Paste this whole file into a fresh chat to pick the project up cold. It is
written for an assistant that has never seen the repo.

---

## What this is

A Flutter **plugin** (not a plain package — it has Swift and Kotlin code) that
renders widgets according to the host platform's *current* design language,
resolved from three inputs rather than one:

**platform × OS version × form factor → `DesignEra`**

Ten eras: `iosLiquidGlass`, `iosClassic`, `ipadLiquidGlass`, `ipadClassic`,
`materialExpressive`, `material3`, `material3Legacy`, `macosTahoe`,
`macosClassic`, `fallback`.

The pitch: every other adaptive package asks "iOS or Android?", which stopped
being enough when iOS 26 and iOS 18 diverged, and Android 16 and Android 12 did
too. Version thresholds live in exactly one file
(`lib/src/core/platform_info.dart`, the `era` getter).

**Why now.** `flutter_platform_widgets` — the category leader, 1.3k likes — was
discontinued when Flutter froze Material and Cupertino in the SDK (April 2026)
and shipped them as standalone `material_ui` / `cupertino_ui` packages. The SDK
copies deprecate in November 2026. That left a gap, and it is the reason every
Material/Cupertino import in this package routes through one file
(`lib/src/design_systems/design_imports.dart`) so the migration is a two-line
change.

**Target platforms:** iOS, iPadOS, Android, macOS. Web/Windows/Linux resolve to
`DesignEra.fallback` and render Material 3.

---

## Where things are

| | |
|---|---|
| Repo (local) | `/Users/gauravraj/personalProjects/native_adaptive_ui` |
| GitHub | `https://github.com/gauravrajkagwaniya/native_adaptive_ui` — created, public, **nothing pushed yet** |
| pub.dev | **not published.** Name `native_adaptive_ui` was available as of 21 Aug 2026 |
| Version | 0.1.0 |
| Flutter | 3.47.1 via FVM (`.fvmrc`) — always `fvm flutter`, never bare `flutter` |
| Design research | `doc/design-specs.md` — read this before changing any visual decision |

---

## How to work on it

Everything runs on the developer's Mac. There is one command:

```sh
cd /Users/gauravraj/personalProjects/native_adaptive_ui
bash tool/verify.sh > verify.log 2>&1; echo "exit=$?"
```

`tool/verify.sh` checks the example's platform folders exist, checks the SPM and
privacy manifests, runs `dart fix --apply` and `dart format` (so lint noise
self-heals), then `flutter analyze --fatal-infos`, the tests, and
`dart pub publish --dry-run`.

To run the app:

```sh
cd example && fvm flutter run
```

**The single most valuable habit on this project: take a screenshot.**

```sh
xcrun simctl io booted screenshot ~/personalProjects/native_adaptive_ui/shot.png
```

Three rounds of visual bugs were "fixed" by reasoning about the code and stayed
broken. One screenshot found four real ones in a minute, including the worst bug
in the project's history (see below). If something "looks wrong", look at it.

---

## Current state

**Passing as of the last full run:** analyze clean, 34 tests green,
`pub publish --dry-run` 0 warnings, iOS simulator builds via Swift Package
Manager with no CocoaPods involved.

**Just added and NOT yet verified** — this is where to start:

The real native Liquid Glass implementation. Swift factories were written
against the documented UIKit API but have never been compiled:

- `GlassSurfaceFactory` → `UIVisualEffectView(effect: UIGlassEffect(style:))`,
  used as a backdrop with Flutter content stacked on top
- `NativeSwitchFactory` → real `UISwitch`
- `NativeSliderFactory` → real `UISlider`
- `GlassButtonFactory` → `UIButton.Configuration.glass()` / `.prominentGlass()`

APIs verified against Apple's documentation pages, not from memory:
`UIGlassEffect` is iOS 26+, has `init(style:)` with `Style.regular` / `.clear`,
plus `isInteractive` and `tintColor`. `UIVisualEffectView` docs warn: "avoid
alpha values that are less than 1". `UIButton.Configuration.glass()`,
`.prominentGlass()`, `.clearGlass()`, `.prominentClearGlass()` all exist.

**Run verify + the app, then screenshot.** If Swift fails to compile, the error
is almost certainly a signature detail, not a missing API.

---

## Architecture

```
PlatformInfo   →  DesignEra  →  AdaptiveTokens  →  RenderStrategy
(OS, version,     (10 eras,     (radius, density,   (native if the device
 idiom, sim)       one file)     motion, glass)      advertises it, else Dart)
```

- `NativeAdaptiveUi.ensureInitialized()` must be awaited in `main()`. It queries
  the plugin channel once; everything afterwards is synchronous.
- **Capability probing, not version inference.** The host advertises a component
  id only when its factory is actually registered. `availableComponents()` in
  the Swift plugin must stay in step with the factories registered above it —
  advertising an id without a factory produces a blank rectangle on a user's
  screen.
- `NativePolicy.auto` / `dartOnly` — settable app-wide, per subtree
  (`AdaptiveScope`), or per widget (`preferNative:`). `dartOnly` is required for
  widget tests: platform views do not render in the test harness.
- `PlatformInfo.fake(era:)` and `NativeAdaptiveUi.debugSetPlatform()` render any
  era on any machine. The example app has a live era picker built on this.

### Files that matter most

| File | Why |
|---|---|
| `lib/src/core/platform_info.dart` | every version threshold |
| `lib/src/core/design_era.dart` | era traits (`hasLiquidGlass`, `prefersSidebarNavigation`, …) |
| `lib/src/tokens/adaptive_tokens.dart` | all per-era geometry and motion |
| `lib/src/design_systems/design_imports.dart` | the single Material/Cupertino choke point |
| `lib/src/core/native_bridge.dart` | component ids — the Dart↔Swift contract |
| `ios/native_adaptive_ui/Sources/native_adaptive_ui/` | the Swift side (SPM layout) |

---

## Decisions worth not re-litigating

**Liquid Glass belongs to the functional layer only.** Apple's Materials page:
"Don't use Liquid Glass in the content layer." Bars, sidebars, alerts, popovers
get it; buttons, list rows, cards do not. `AdaptiveButton` is a plain Cupertino
button on iOS 26 — the era changes its *geometry*, not its material. An earlier
version glassed every button and that was the main reason the UI looked wrong.

**Sliders and toggles are the documented exception** — they take glass "when a
person activates it", transiently. That is why they are embedded as real
`UISwitch` / `UISlider` rather than faked: the system does it, we cannot.

**Simulators take the same path as hardware.** An earlier rule forced simulators
to Dart; the practical effect was that the native path never ran during
development. Liquid Glass renders correctly in the iOS 26 simulator.

**iPad defaults to a sidebar, not a tab bar.** Apple's HIG says "Prefer a tab bar
for navigation" on iPad, and `AdaptiveNavigationStyle.tabBar` gives exactly that
(placed at the *top*, which is where iPadOS puts it). The default is `sidebar`
anyway, because the sidebar layout is what gives the detail pane its own
`Navigator` — pane-only navigation is the behaviour that actually distinguishes
an iPad app from a phone app on a tablet, and it is what the project owner
asked for. Both are valid Apple patterns.

**Most Apple HIG pages are stale.** Ten of the fourteen component pages have not
been revised for iOS 26. For those, the Materials page is the only binding glass
rule. `doc/design-specs.md` marks every page ✅ or ⚠️.

**Apple publishes almost no numbers.** 44×44pt is the only universal one. Do not
invent point values to match Material's precision — `doc/design-specs.md` lists
every published figure and explicitly names what is unpublished.

---

## Bugs already found and fixed — do not reintroduce

Ordered by how much damage each did.

1. **The whole app rendered in Roboto, not San Francisco.** `AdaptiveApp` inserts
   a transparent `Material` so Material widgets work inside `CupertinoApp` (which
   provides no `Material` ancestor). But `Material` wraps its child in
   `AnimatedDefaultTextStyle(style: widget.textStyle ?? Theme.of(context)
   .textTheme.bodyMedium!)` — leaving `textStyle` null hands the entire app
   Material's typography. It now passes `CupertinoTheme.of(context).textTheme
   .textStyle` explicitly. **Nothing else has to be wrong for this alone to make
   an iOS build look like an Android one.**
2. **Glass tinted with black in light mode**, turning every glass surface into a
   grey slab. Apple's material is a *light* one. The tint is now white-based in
   both themes.
3. **`showMenu` inside `CupertinoApp` crashed** — it asserts
   `debugCheckHasMaterialLocalizations`, which `CupertinoApp` does not install.
   `AdaptiveApp` now appends `DefaultMaterialLocalizations.delegate`.
4. **`CupertinoActivityIndicator(progress:)` does not exist.** The determinate
   form is `CupertinoActivityIndicator.partiallyRevealed(progress:)`.
5. **`CupertinoListSection.insetGrouped` has no `margin` parameter** — only the
   base constructor does.
6. **Cupertino glyphs rendered as `?` boxes** — the package draws from the
   CupertinoIcons font but did not depend on `cupertino_icons`.
7. **Content scrolled behind the navigation bar.** An earlier version forced the
   Cupertino bar transparent, which removed its blur *and* stopped
   `CupertinoPageScaffold` reporting the bar height through `MediaQuery`. Use
   `context.adaptiveScrollPadding()` from a context *inside* the scaffold
   (a `Builder`) whenever a scrollable needs custom padding — an explicit
   `padding` on a `ListView` silently discards the automatic inset.
8. **The floating tab bar reused `CupertinoTabBar`**, which is built to be pinned
   full-width to the bottom edge, adds the safe area to its own height and draws
   a top border. Glass eras now use a purpose-built floating capsule.
9. **Inset-grouped list headers were 20pt bold and footers 17pt black** —
   Flutter's defaults. iOS renders both as 13pt secondary label.
10. **Grouped screens sat on white**, so the cards had nothing to float on.
    `AdaptiveScaffold(grouped: true)` sets the platform's grouped background.
11. **Material glyphs in the iOS tab bar.** `AdaptiveDestination` now takes
    `appleIcon` / `appleSelectedIcon`.
12. **`verify.log` shipped inside the published archive** — `pub publish`
    includes everything git does not ignore.

Also verified from the Flutter 3.47.1 source, and easy to get wrong again:
`RefreshCallback` is declared in *both* material and cupertino (the design-imports
file hides one); `Switch.activeColor` is deprecated in favour of
`activeThumbColor`; macOS platform views use `AppKitView`, not `UiKitView`.

---

## What's next

From `doc/design-specs.md`, roughly by value:

1. Verify the native Swift compiles and the glass actually appears.
2. **Scroll edge effect** (`ScrollEdgeEffectStyle`) — Apple's stated alternative
   to painting a toolbar background.
3. **`sidebarAdaptable`** — the button that converts an iPad tab bar to a sidebar.
4. **Concentric corner radii** for bar-embedded components. Apple publishes no
   value, so it has to be derived from the bar's own radius.
5. **Search placements** — three on iOS, a different set on iPadOS/macOS, plus
   the iPad virtual-keyboard auto-focus exception.
6. **Toolbar item regions** — leading/center/trailing with system overflow and
   one `.prominent` trailing action. `AdaptiveScaffold` still models iOS 18.
7. `UIGlassContainerEffect` for the tab bar, so the selected pill merges with the
   bar the way the system does it.
8. M3E flexible navigation bar with horizontal items in medium windows.
9. Android has **no** platform views by design — Material 3 Expressive is a
   specification, not embeddable widgets, and embedding Compose would drag a
   Compose runtime into every consumer's APK. Revisit only if that changes.
10. iOS 27 era — Apple's design resources already ship an iOS 27 UI Kit. The
    `>= 26` rule covers it today; split it when 27 actually diverges.

---

## Before publishing

- `git init` / commit / push — nothing is on GitHub yet.
- Add repo topics: `flutter`, `dart`, `flutter-plugin`, `adaptive-ui`,
  `cupertino`, `material-design`, `ios26`, `liquid-glass`.
- Device matrix that a simulator cannot cover: a real iOS 26 device, a real iOS
  18 device, an iPad dragged into Slide Over, Android 16 and Android 12, macOS.
- `pod lib lint ios/native_adaptive_ui.podspec` for the CocoaPods fallback.
- `dart pub publish` needs a pub.dev (Google) login. The work so far was done on
  an office laptop where the owner's personal accounts are not signed in, so
  both the git push and the publish are still outstanding.
- Publish as **0.1.0**, not 1.0 — it sets honest expectations and leaves room to
  break API in 0.2.

A launch and marketing plan (positioning, pub.dev scoring, a LinkedIn post
series) lives at
https://claude.ai/code/artifact/8db2fa18-5edf-45a9-b5ad-359f5a9b23fa
