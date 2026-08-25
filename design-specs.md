# Design specs reference

Everything this package's rendering decisions are grounded in, gathered from
primary sources on **22 August 2026**. Kept in the repo so the research does not
have to be repeated, and so a future change can be checked against the rule it
would break.

Two things make this document worth re-reading rather than trusting from memory:

1. **Most Apple HIG pages have not been revised for iOS 26.** Ten of the fourteen
   component pages still carry change logs from 2023–2024. For those, the only
   binding Liquid Glass rule is the one on the Materials page. Anything beyond
   that is speculation, and this document marks it as such.
2. **Apple publishes almost no point values.** The complete set of numbers found
   across all fourteen pages is listed in [Numbers Apple actually
   publishes](#numbers-apple-actually-publishes). Material, by contrast,
   publishes full token tables. Do not invent Apple numbers to match Material's
   precision.

---

## 1. The governing rules

From [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
(revised 9 September 2025 — current for iOS 26). These are load-bearing for the
whole package:

> "Liquid Glass forms a distinct functional layer for controls and navigation
> elements — like tab bars and sidebars — that floats above the content layer."

> **"Don't use Liquid Glass in the content layer."** … "An exception to this is
> for controls in the content layer with a transient interactive element like
> sliders and toggles; in these cases, the element takes on a Liquid Glass
> appearance to emphasize its interactivity when a person activates it."

> "Use Liquid Glass effects sparingly… Limit these effects to the most important
> functional elements in your app."

**Functional layer** (glass at rest): toolbars / navigation bars, tab bars,
sidebars, alerts, popovers, sheets.
**Content layer** (never glass at rest): buttons, list rows, cards, text fields,
segmented controls, progress indicators, app backgrounds.
**Transient only**: sliders, toggles — glass appears while the control is being
manipulated and goes away again.

### Variants

| Variant | Behaviour | Use for |
|---|---|---|
| regular | Blurs and adjusts luminosity of what is behind it. "Most system components use this variant." | Anything where legibility is at risk, or with a lot of text — alerts, sidebars, popovers |
| clear | Highly translucent, keeps rich backgrounds prominent | Components floating over photos and video |

Clear over bright content needs "a dark dimming layer of **35% opacity**". Not
needed over dark content, or with AVKit's own controls.

### Colour on glass

From [Color](https://developer.apple.com/design/human-interface-guidelines/color)
(revised 16 December 2025):

- "By default, Liquid Glass has no inherent color, and instead takes on colors
  from the content directly behind it."
- Small elements (toolbars, tab bars) default to monochromatic symbols and text.
- "Liquid Glass appears more opaque in larger elements like sidebars."
- "To emphasize primary actions, apply color to the background rather than to
  symbols or text."
- "Refrain from adding color to the background of multiple controls."

### Standard (non-glass) materials

iOS and iPadOS still ship four for the content layer: `ultraThin`, `thin`,
`regular` (default), `thick`. Vibrancy levels for labels: label (default),
secondaryLabel, tertiaryLabel, quaternaryLabel — "avoid using quaternary on top
of the thin and ultraThin materials, because the contrast is too low."

---

## 2. Apple components

Each entry notes whether the page has been revised for iOS 26. Where it has not,
treat the Materials rule above as the only glass guidance.

### Tab bars — revised 8 June 2026 ✅

- **iOS**: "A tab bar floats above content at the bottom of the screen. Its
  items rest on a Liquid Glass background that allows content beneath to peek
  through."
- **iPadOS**: "The system displays a tab bar near the **top** of the screen." It
  can be fixed (`tabBarOnly`) or carry a button that converts it to a sidebar
  (`sidebarAdaptable`). A toolbar and a tab bar "can coexist in the same
  horizontal space at the top of the view."
- **Minimising**: only framed as behaviour "for tab bars with an attached
  accessory, like the MiniPlayer in Music". The bar is restored by **tapping a
  tab or scrolling to the top of the view** — not by scrolling up a little.
- Labels appear **beneath** icons in compact views, **beside** them in regular.
- "Prefer filled symbols or icons for consistency with the platform."
- A dedicated search tab goes at the **trailing** end.
- Don't: disable or hide tab bar buttons; hide the bar on navigation (modals
  excepted); allow overflow into a More tab if avoidable. Aim for **five or
  fewer** default tabs so customisation stays continuous across size classes.

### Toolbars / navigation bars — revised 16 December 2025 ✅

The standalone navigation-bars page **no longer exists**; `/navigation-bars`
redirects to `/toolbars`, which absorbed its guidance in June 2025. "In iOS, a
navigation-specific toolbar is sometimes called a navigation bar."

- Glass at rest.
- > "Reduce the use of toolbar backgrounds and tinted controls. Any custom
  > backgrounds and appearances you use might overlay or interfere with
  > background effects that the system provides."
  Use the content layer's colour and a `ScrollEdgeEffectStyle` instead.
- "prefer using the default monochromatic appearance of toolbars."
- Corner radii of bar-embedded components are **concentric with the bar's
  corners** — a computed relationship. No value is published.
- Three item regions: **leading** (not customisable), **center** (customisable
  on macOS/iPadOS, collapses into a system overflow menu), **trailing** ("remain
  visible at all window sizes").
- One primary action only, `.prominent` style, on the **trailing** side.
- Titles under **15 characters**; aim for a maximum of **three** groups.
- Don't: add an overflow menu manually — "The system automatically adds an
  overflow menu in macOS or iPadOS when items no longer fit."

### Sidebars — revised 8 June 2026 ✅

- Glass at rest, regular variant, "more opaque… to preserve legibility".
- "In general, show no more than **two levels** of hierarchy in a sidebar."
  Deeper hierarchies want a split view with a content list in between.
- The sidebar and the tab bar are the same control on iOS/iPadOS via
  `sidebarAdaptable`; "Consider using a tab bar first."
- Content can extend beneath it via `backgroundExtensionEffect()`.
- iPadOS reveals it with an edge swipe. macOS has small/medium/large sizes the
  user can override.
- Don't: hide the sidebar by default; put critical actions at its bottom (macOS).

### Split views — revised 9 June 2025, silent on Liquid Glass ⚠️

- "Prefer using a split view in a **regular** — not a compact — environment",
  naming iPhone portrait as the bad case.
- iPad windows are fluidly resizable: design for **narrow, compact and
  intermediate** widths, not one breakpoint.
- macOS: "Prefer the thin divider style. The thin divider measures **one point**
  in width."
- tvOS default is one-third / two-thirds. watchOS shows one pane full-screen.

### Buttons — revised 16 December 2025 ✅

- **"a button needs a hit region of at least 44x44 pt"** (60×60 in visionOS).
  This is the single most important published number in the whole set.
- Roles: normal, primary, cancel, destructive. Primary uses the accent colour and
  responds to Return; destructive uses system red.
- "Keep the number of prominent buttons to **one or two per view**."
- "Use style — not size — to visually distinguish the preferred choice."
- Don't: assign the primary role to a destructive action; omit a press state.
- Content-layer buttons are **not** described as glass anywhere on this page.

### Toggles — revised 29 March 2024, silent on Liquid Glass ⚠️

- "Use the switch toggle style **only in a list row**." Outside a list, "use a
  button that behaves like a toggle, not a switch."
- Don't change the default green unless necessary; don't rely on colour alone.
- macOS adds checkboxes and radio buttons; radio groups are "typically two to
  five", and past "about five options" use a pop-up button.
- No sizes published.

### Sliders — revised 21 June 2023, silent on Liquid Glass ⚠️

- Track fills from minimum to the thumb.
- **"Don't use a slider to adjust audio volume"** on iOS/iPadOS — use a volume
  view.
- macOS adds tick marks and a circular style; the linear thumb is "a narrow
  lozenge".
- No track height, thumb size or tap target published.

### Lists and tables — revised 21 June 2023, silent on Liquid Glass ⚠️

Content layer, so not glass.

- iOS/iPadOS styles: grouped (headers, footers, spacing between groups).
- An **info button** shows detail and does not navigate; a **disclosure
  indicator** navigates and shows no detail. Don't conflate them.
- "Avoid adding an index to a table that displays controls — like disclosure
  indicators — in the trailing ends of its rows."
- No row heights published.

### Alerts — revised 2 February 2024 ⚠️ (but named in Materials as regular glass)

- **"alerts display a title, optional informative text, and up to three
  buttons."** A limit, not a suggestion.
- Most-likely button trailing (or top when stacked); Cancel leading (or bottom);
  the default button is never Cancel.
- Text field allowed on iOS, iPadOS, macOS, visionOS. Icon and accessory view are
  macOS/visionOS only. Suppression checkbox and Help button are macOS only.
- Don't: use an alert merely to inform; show one at launch; use "OK" as the
  default title unless purely informational; let an alert scroll; wrap the title
  past two lines.

### Action sheets — no change log ⚠️ (named in Materials as regular glass)

- The modern API name is **confirmation dialog**. UIKit path is
  `UIAlertController.Style.actionSheet`. **Not supported in visionOS.**
- Destructive choices go at the **top**; Cancel at the **bottom**.
- "Avoid letting an action sheet scroll."
- "Use an action sheet — not a menu — to provide choices related to an action."
- watchOS caps at four buttons including Cancel; no iOS count is published.

### Popovers — no change log ⚠️ (named in Materials as regular glass)

- > "Avoid displaying popovers in compact views… for compact views, use all
  > available screen space by presenting information in a full-screen modal view
  > like a sheet instead."
  This is a **size-class** rule, not a device rule.
- One at a time — "Never show a cascade or hierarchy of popovers."
- The arrow points as directly as possible at the element that revealed it.
- macOS popovers can be detachable. Don't use a popover for a warning — use an
  alert.
- No maximum size published.

### Segmented controls — revised 21 June 2023, silent on Liquid Glass ⚠️

- **"no more than about five to seven segments in a wide interface and no more
  than about five segments on iPhone."**
- Segments are usually equal in width.
- "Prefer using either text or images — not a mix of both."
- iOS/iPadOS are single-select. Multi-select and momentary modes are macOS only.
- "For switching between completely separate sections of an app, use a tab bar."

### Text fields — revised 5 June 2023, silent on Liquid Glass ⚠️

- Clear button at the trailing end; leading end indicates purpose.
- Always use a secure field for sensitive entry.
- Don't rely on the placeholder alone — it disappears; add a label.
- Note the conflict: a text field **in a toolbar** is functional layer and gets
  bar-concentric corner radii.

### Progress indicators — revised 12 September 2023, silent on Liquid Glass ⚠️

- Circular indicators fill **clockwise**; bars fill leading to trailing.
- macOS supports an indeterminate **bar**; iOS does not.
- **"Don't switch from the circular style to the bar style."** Switching
  indeterminate → determinate is fine once the duration is known.
- The refresh control is iOS/iPadOS only.
- No sizes published.

### Search — revised 8 June 2026 ✅

- **iOS has exactly three placements**: as a tab in the tab bar, in a toolbar at
  the bottom or top, or inline with content.
- "Place search at the bottom if there's room." Top-toolbar search is always a
  button that animates into a field above the keyboard.
- **iPadOS and macOS share one rule set**: trailing side of the toolbar, top of
  the sidebar for filtering, or a dedicated item for discovery.
- iPad-specific behaviour with a real consequence: do **not** auto-focus a
  dedicated search field "on iPad when only a virtual keyboard is available, in
  which case it's better to leave the field unfocused to prevent the keyboard
  from unexpectedly covering the view."

---

## 3. Material 3 and Material 3 Expressive

Material publishes full token tables; these are exact.

### Slider — [specs](https://m3.material.io/components/sliders/specs)

The Expressive handle is a **bar, not a circle** — this is the most visible
difference from Material 3.

| Attribute | XS (default) | S | M | L | XL |
|---|---|---|---|---|---|
| Track height | 16dp | 24dp | 40dp | 56dp | 96dp |
| Handle height | 44dp | 44dp | 52dp | 68dp | 108dp |
| Handle width | 4dp | 4dp | 4dp | 4dp | 4dp |
| Track shape | 8dp | 8dp | 12dp | 16dp | 28dp |
| Inset icon size | — | — | 24dp | 24dp | 32dp |

Label container: 44dp height, 48dp width.

| Configuration | M3 | M3 Expressive |
|---|---|---|
| Centered variant | web only | available |
| Vertical orientation | — | available |
| Sizes S–XL | — | available |
| Inset icon | — | available |
| Stop indicators | as "discrete" | available |

### Switch — [specs](https://m3.material.io/components/switch/specs)

| Element | Attribute | Value |
|---|---|---|
| Track | Height / Width | 32dp / 52dp |
| Track | Outline width | 2dp |
| Handle | Unselected | 16dp |
| Handle | Selected, or with icon | 24dp |
| Handle | Pressed | 28dp |
| State layer | Size | 40dp |
| Target | Size | 48dp |
| Icon | Size | 16dp |

"Icon on selected switch" is a listed configuration; Expressive is where it
becomes the expected look.

### Navigation bar — [specs](https://m3.material.io/components/navigation-bar/specs)

- Material 3 Expressive introduces the **flexible navigation bar**, which is
  **shorter** than the baseline bar and supports **horizontal** navigation items
  in medium windows.
- "The baseline nav bar is no longer recommended, and should be replaced by the
  flexible nav bar."
- Vertical items in compact windows; horizontal items in medium windows.
- Vertical items "dynamically change width to equally fit the container";
  horizontal items have a fixed width with extra space at the ends.
- Flutter's `NavigationBar` is the **baseline** widget. Its indicator defaults to
  64×32dp.

---

## 4. Flutter facts worth remembering

Verified against the Flutter 3.47.1 source, not from memory.

- `RefreshCallback` is declared in **both** `material/refresh_indicator.dart` and
  `cupertino/refresh.dart`. Re-exporting both libraries from one file requires
  hiding one.
- `CupertinoActivityIndicator` has **no** `progress` parameter. Determinate use
  goes through `CupertinoActivityIndicator.partiallyRevealed(progress:)`.
- `CupertinoListSection.insetGrouped` has **no** `margin` parameter; only the
  base constructor does. The inset is fixed to Apple's metrics on purpose.
- `showMenu` asserts `debugCheckHasMaterialLocalizations`, which `CupertinoApp`
  does not install. Any Material fallback inside a Cupertino app needs
  `DefaultMaterialLocalizations.delegate` added explicitly.
- Material widgets need a `Material` ancestor; `CupertinoApp` provides none.
- The 2024 drawings for `Slider` and the progress indicators are behind
  `year2023: false`, also available as `SliderThemeData.year2023` and
  `ProgressIndicatorThemeData.year2023`. The flag is deprecated because it is a
  transition switch, and it is currently the only route to the Expressive
  appearance.
- `Switch.activeColor` is deprecated in favour of `activeThumbColor` /
  `activeTrackColor`.
- macOS platform views use `AppKitView`, not `UiKitView`.
- A `ScrollView` with `padding: null` picks up `MediaQuery.padding`
  automatically; supplying any explicit padding silently discards that inset.
- When a keyboard opens, `padding.bottom` collapses to zero and the height moves
  to `viewInsets.bottom`.

---

## 5. Numbers Apple actually publishes

The complete set across all fourteen pages. Everything else is unpublished — do
not invent values to fill the gaps.

| Value | Applies to |
|---|---|
| 44×44 pt | Minimum hit region (60×60 pt in visionOS) |
| 35% | Dimming layer behind clear glass over bright content |
| 15 characters | Toolbar title guidance |
| 3 | Maximum alert buttons |
| ~5 / 5–7 | Segments on iPhone / in a wide interface |
| ~5 | Default tabs before customisation continuity suffers |
| 2 | Maximum levels of hierarchy in a sidebar |
| 1 pt | macOS thin split-view divider |
| 28 / 32 / 44 / 52 / 64 pt | visionOS button size ladder |
| 60 pt, 4 pt | visionOS button spacing, padding above 60 pt |
| 154 pt, 16 pt | visionOS alert accessory max height, corner radius |
| 68 pt, 46 pt | tvOS tab bar height, offset from top |
| ~10 px | macOS image-button padding |

**No published values** for: iOS toolbar height, tab bar height, list row
height, text field height, slider track or thumb, segmented control height,
progress indicator size, popover maximum size, or any corner radius.

---

## 6. Page revision status

Check this before trusting a page for iOS 26 behaviour.

**Current for the new design system:** materials (9 Sep 2025), color
(16 Dec 2025), buttons (16 Dec 2025), toolbars (16 Dec 2025), tab bars
(8 Jun 2026), sidebars (8 Jun 2026), search fields and searching (8 Jun 2026).

**Not revised since 2023–2025, therefore silent on Liquid Glass:** toggles
(29 Mar 2024), sliders (21 Jun 2023), lists and tables (21 Jun 2023), alerts
(2 Feb 2024), action sheets (no change log), popovers (no change log), segmented
controls (21 Jun 2023), text fields (5 Jun 2023), progress indicators
(12 Sep 2023), split views (9 Jun 2025).

---

## 7. What this package implements, and what it does not

### Implemented

| Rule | Where |
|---|---|
| Glass confined to the functional layer | `AdaptiveButton` is a plain Cupertino button on every Apple era; `GlassSurface` is used only by bars and sidebars |
| 44×44 pt minimum hit region | `AdaptiveButton`, Apple eras |
| iPad tab bar at the top | `AdaptiveNavigationStyle.tabBar` |
| Minimise restores on tab tap or scroll-to-top, and is off by default | `AdaptiveNavigationScaffold.minimizeOnScroll` |
| Popover in regular windows, sheet in compact | `showAdaptiveActionSheet` |
| Destructive first, Cancel last | `showAdaptiveActionSheet` |
| Three-button alert limit | `showAdaptiveAlert` assertion |
| Five-segment limit in compact windows | `AdaptiveSegmentedControl` assertion |
| No opaque bar backgrounds | `AdaptiveScaffold` leaves `CupertinoNavigationBar` translucency alone |
| Keyboard insets in scrollables | `AdaptiveContext.adaptiveScrollPadding` |
| M3E slider, switch icon, wavy progress, shorter nav bar | the respective widgets, gated on `DesignEra.isExpressive` |

### Not implemented — the enhancement backlog

Ordered roughly by value.

1. **Scroll edge effect** (`ScrollEdgeEffectStyle`) — Apple's stated alternative
   to painting a toolbar background. Currently nothing distinguishes the bar
   region from content on scroll.
2. **Transient glass on sliders and toggles** during interaction. The documented
   exception to the content-layer rule, currently not reproduced.
3. **`sidebarAdaptable` toggle** — the button that converts an iPad tab bar into
   a sidebar and back. Today the choice is fixed at build time by
   `AdaptiveNavigationStyle`.
4. **Concentric corner radii** for components embedded in bars. Apple publishes
   no value, so this has to be derived from the bar's own radius.
5. **Search placements** — three on iOS, a different set on iPadOS/macOS, plus
   the iPad virtual-keyboard auto-focus exception. No adaptive search widget
   exists yet.
6. **Toolbar item regions** — leading / center / trailing with a system-managed
   overflow and one `.prominent` trailing action. `AdaptiveScaffold` still models
   the iOS 18 leading/middle/trailing shape.
7. **Tab bar accessory** — the MiniPlayer-style view that makes minimising
   meaningful.
8. **M3E flexible navigation bar** with horizontal items in medium windows.
   Currently approximated by shortening the baseline bar.
9. **M3E slider sizes S–XL**, centered and vertical variants, inset icons.
10. **`backgroundExtensionEffect()`** for content extending beneath a sidebar.
11. **Badges** on tab items.
12. **iOS 27 era.** Apple's design resources already ship an iOS 27 / iPadOS 27
    UI Kit. `DesignEra` resolves `>= 26` to the Liquid Glass eras, so iOS 27 is
    covered today; a separate era is needed the moment 27 diverges.

---

## Sources

Apple Human Interface Guidelines: [materials](https://developer.apple.com/design/human-interface-guidelines/materials),
[color](https://developer.apple.com/design/human-interface-guidelines/color),
[tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars),
[toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars),
[sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars),
[split views](https://developer.apple.com/design/human-interface-guidelines/split-views),
[buttons](https://developer.apple.com/design/human-interface-guidelines/buttons),
[toggles](https://developer.apple.com/design/human-interface-guidelines/toggles),
[sliders](https://developer.apple.com/design/human-interface-guidelines/sliders),
[lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables),
[alerts](https://developer.apple.com/design/human-interface-guidelines/alerts),
[action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets),
[popovers](https://developer.apple.com/design/human-interface-guidelines/popovers),
[segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls),
[text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields),
[progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators),
[search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields).

[Apple Design Resources](https://developer.apple.com/design/resources/) — iOS 27
and iPadOS 27 UI Kits, SF Symbols 8 beta, Icon Composer.

Material Design 3: [sliders](https://m3.material.io/components/sliders/specs),
[switch](https://m3.material.io/components/switch/specs),
[navigation bar](https://m3.material.io/components/navigation-bar/specs).

Flutter: [updated Material 3 Slider](https://docs.flutter.dev/release/breaking-changes/updated-material-3-slider),
and the Flutter 3.47.1 framework source.
