#!/usr/bin/env bash
# Pre-publish verification. Run from the package root.
#
# Uses `fvm flutter` when a .fvmrc is present so the pinned SDK is used rather
# than whatever happens to be on PATH.
set -euo pipefail

if [ -f .fvmrc ] && command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"
  DART="fvm dart"
else
  FLUTTER="flutter"
  DART="dart"
fi

echo "==> Flutter version"
$FLUTTER --version

echo "==> Example app platform folders"
if [ ! -d example/ios ]; then
  echo "    MISSING. The example has no runner projects, so it cannot be built"
  echo "    on a device and Swift Package Manager cannot be exercised. Run:"
  echo "      cd example && $FLUTTER create --platforms=ios,android,macos --org com.example ."
  echo "    then re-run this script."
  exit 1
fi
echo "    present"

echo "==> Swift Package Manager manifests"
for manifest in ios/native_adaptive_ui/Package.swift macos/native_adaptive_ui/Package.swift; do
  [ -f "$manifest" ] || { echo "    MISSING $manifest"; exit 1; }
  echo "    $manifest"
done

echo "==> Privacy manifests (App Store requires one per distributed SDK)"
for privacy in \
  ios/native_adaptive_ui/Sources/native_adaptive_ui/Resources/PrivacyInfo.xcprivacy \
  macos/native_adaptive_ui/Sources/native_adaptive_ui/Resources/PrivacyInfo.xcprivacy; do
  [ -f "$privacy" ] || { echo "    MISSING $privacy"; exit 1; }
  echo "    $privacy"
done

echo "==> Resolving dependencies"
$FLUTTER pub get
(cd example && $FLUTTER pub get)

echo "==> Auto-fixing what the analyzer can fix itself"
# pub.dev scores lints, and most of what it would dock here (missing `const`,
# import ordering) the analyzer can repair mechanically. Running this before the
# check means the manual pass only ever deals with real problems.
$DART fix --apply

echo "==> Formatting"
$DART format .

echo "==> Static analysis (must be clean: pub.dev scores it)"
$FLUTTER analyze --fatal-infos --fatal-warnings

echo "==> Format check"
$DART format --output=none --set-exit-if-changed .

echo "==> Tests"
$FLUTTER test

echo "==> Dry-run publish"
$DART pub publish --dry-run

echo
echo "==> Enable Swift Package Manager, then build the example:"
echo "      $FLUTTER config --enable-swift-package-manager"
echo "      cd example && $FLUTTER build ios --no-codesign"
echo "    A successful build with SPM enabled and no Podfile is the real proof."
echo
echo "==> Remaining manual checks:"
echo "  1. iOS 26 device   — glass chrome + native button"
echo "  2. iOS 18 device   — classic Cupertino"
echo "  3. iPad, then dragged into Slide Over (sidebar must become a tab bar)"
echo "  4. Android 16 and Android 12"
echo "  5. macOS"
echo "  6. Hot reload on a screen containing a native slider"
echo "  7. pod lib lint ios/native_adaptive_ui.podspec  (CocoaPods fallback)"
