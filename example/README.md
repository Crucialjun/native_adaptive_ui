# native_adaptive_ui example

A gallery app that exercises every widget in `native_adaptive_ui`, and doubles
as the package's own design-review tool.

- **Controls** — buttons, a segmented control, switch, slider, text fields, an
  alert and an action sheet / popover.
- **Lists** — an inset-grouped list section with a pushed detail screen.
- **More** — search, a popover, a split view, and the Material 3 Expressive
  slider sizes.
- **Design** — shows the detected platform, form factor and `DesignEra`, and
  lets you preview *any* era on the machine you're running on. That is how
  the screenshots in the root [README](../README.md) were produced.

## Run it

```sh
cd example
flutter run
```

Pick any destination in the **Design** tab's "Preview as" list to re-render
the whole app as iOS 26, iOS 18, iPadOS, Android 16, or macOS Tahoe — without
needing a device for each.
