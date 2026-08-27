# Contributing to native_adaptive_ui

Issues and PRs are welcome, particularly device reports from OS versions the
maintainer does not have hardware for (see the README's Status section).

## Setup

```sh
flutter pub get
cd example && flutter pub get && cd ..
```

The repo pins a Flutter version via `.fvmrc`. If you use [FVM](https://fvm.app),
`fvm flutter` picks it up automatically; otherwise make sure your `flutter`
on `PATH` satisfies the `environment.flutter` constraint in `pubspec.yaml`.

## Before opening a PR

```sh
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed .
```

For changes that touch the native iOS/macOS/Android sides, `tool/verify.sh`
runs a broader pre-publish check (Swift Package Manager manifests, privacy
manifests, example app platform folders). Run it from the package root.

If you're changing a widget's rendering, add or update a test in
`test/adaptive_widgets_test.dart` using `pumpEra` — it renders any
`DesignEra` on the machine you're on via `NativeAdaptiveUi.debugSetPlatform`,
so a device isn't required to cover most cases.

## Reporting a device-specific bug

The most useful bug reports include:

- The exact OS version and device (or simulator) you saw it on
- Whether `NativePolicy.dartOnly` changes the behavior — that narrows it to
  either the native embedding or the Dart fallback
- A screenshot, if it's visual — most of the bugs fixed before 0.1.0 were
  invisible in code review and obvious in a screenshot (see CHANGELOG.md)

## Design decisions

The rules this package renders against — Apple's HIG, Material 3 token
tables, and the Flutter API facts behind them — are written down in
[`doc/design-specs.md`](doc/design-specs.md), with revision dates and
sources. If a PR changes rendering behavior, it should cite the rule it's
following or correcting.

## Code style

Follow the existing `analysis_options.yaml` lints. Comments should explain
*why*, not *what* — see the existing source for the tone the codebase uses.
Avoid adding abstractions, config flags, or fallback paths for cases the
package doesn't need to handle.
