import 'package:flutter/foundation.dart';

import 'design_era.dart';
import 'native_bridge.dart';

/// An immutable description of the device the app is running on, resolved once
/// at startup and then read synchronously during builds.
@immutable
class PlatformInfo {
  const PlatformInfo({
    required this.osName,
    required this.majorVersion,
    required this.minorVersion,
    required this.androidSdkInt,
    required this.deviceFormFactor,
    required this.nativeComponents,
    required this.isSimulator,
  });

  /// `ios`, `android`, `macos`, or `unknown`.
  final String osName;

  /// Marketing major version: 26 for iOS 26, 16 for Android 16, 26 for macOS Tahoe.
  final int majorVersion;

  /// Marketing minor version, or 0 when the host does not report one.
  final int minorVersion;

  /// Android API level, or `null` off Android. Android's API level and its
  /// marketing version drift apart often enough that both are kept.
  final int? androidSdkInt;

  /// Form factor as reported by the OS (UI idiom on Apple, smallest-width
  /// bucket on Android). This is the *device*; the usable window may be
  /// smaller, which is why layout code should prefer
  /// `AdaptiveScope.of(context).formFactor`.
  final FormFactor deviceFormFactor;

  /// Native components verified as embeddable on this device.
  final Set<String> nativeComponents;

  /// True on simulators and emulators, where some native materials render
  /// differently from hardware and are worth degrading deliberately.
  final bool isSimulator;

  /// The conservative description used before [resolve] completes, when the
  /// plugin is not registered, and in unit tests.
  factory PlatformInfo.fallback() {
    final platform = defaultTargetPlatform;
    final (name, major) = switch (platform) {
      TargetPlatform.iOS => ('ios', 18),
      TargetPlatform.android => ('android', 15),
      TargetPlatform.macOS => ('macos', 15),
      _ => ('unknown', 0),
    };
    return PlatformInfo(
      osName: name,
      majorVersion: major,
      minorVersion: 0,
      androidSdkInt: platform == TargetPlatform.android ? 35 : null,
      deviceFormFactor: platform == TargetPlatform.macOS
          ? FormFactor.desktop
          : FormFactor.phone,
      nativeComponents: const <String>{},
      isSimulator: false,
    );
  }

  /// Builds a description that resolves to [era], for tests and design-review
  /// builds. Pass [nativeComponents] to exercise native-rendering paths.
  factory PlatformInfo.fake({
    required DesignEra era,
    Set<String> nativeComponents = const <String>{},
    bool isSimulator = false,
  }) {
    final (osName, major, api, formFactor) = switch (era) {
      DesignEra.iosLiquidGlass => ('ios', 26, null, FormFactor.phone),
      DesignEra.iosClassic => ('ios', 18, null, FormFactor.phone),
      DesignEra.ipadLiquidGlass => ('ios', 26, null, FormFactor.tablet),
      DesignEra.ipadClassic => ('ios', 18, null, FormFactor.tablet),
      DesignEra.materialExpressive => ('android', 16, 36, FormFactor.phone),
      DesignEra.material3 => ('android', 14, 34, FormFactor.phone),
      DesignEra.material3Legacy => ('android', 11, 30, FormFactor.phone),
      DesignEra.macosTahoe => ('macos', 26, null, FormFactor.desktop),
      DesignEra.macosClassic => ('macos', 15, null, FormFactor.desktop),
      DesignEra.fallback => ('unknown', 0, null, FormFactor.phone),
    };
    return PlatformInfo(
      osName: osName,
      majorVersion: major,
      minorVersion: 0,
      androidSdkInt: api,
      deviceFormFactor: formFactor,
      nativeComponents: nativeComponents,
      isSimulator: isSimulator,
    );
  }

  /// Queries the host OS. Never throws — an unreachable channel yields
  /// [PlatformInfo.fallback].
  static Future<PlatformInfo> resolve() async {
    final description = await NativeBridge.describePlatform();
    if (description == null) return PlatformInfo.fallback();

    final components = await NativeBridge.availableComponents();
    return PlatformInfo(
      osName: (description['osName'] as String?) ?? 'unknown',
      majorVersion: (description['majorVersion'] as num?)?.toInt() ?? 0,
      minorVersion: (description['minorVersion'] as num?)?.toInt() ?? 0,
      androidSdkInt: (description['androidSdkInt'] as num?)?.toInt(),
      deviceFormFactor: _parseFormFactor(description['formFactor'] as String?),
      nativeComponents: components,
      isSimulator: (description['isSimulator'] as bool?) ?? false,
    );
  }

  static FormFactor _parseFormFactor(String? raw) => switch (raw) {
        'tablet' => FormFactor.tablet,
        'desktop' => FormFactor.desktop,
        _ => FormFactor.phone,
      };

  /// The design era implied by this device, before any developer override.
  ///
  /// Version thresholds live here and nowhere else, so supporting a future OS
  /// is a one-line change rather than a hunt through widget files.
  DesignEra get era {
    switch (osName) {
      case 'ios':
        final isPad = deviceFormFactor == FormFactor.tablet;
        if (majorVersion >= 26) {
          return isPad ? DesignEra.ipadLiquidGlass : DesignEra.iosLiquidGlass;
        }
        return isPad ? DesignEra.ipadClassic : DesignEra.iosClassic;
      case 'macos':
        return majorVersion >= 26
            ? DesignEra.macosTahoe
            : DesignEra.macosClassic;
      case 'android':
        final api = androidSdkInt ?? 0;
        if (api >= 36) return DesignEra.materialExpressive;
        if (api >= 31) return DesignEra.material3;
        return DesignEra.material3Legacy;
      default:
        return DesignEra.fallback;
    }
  }

  /// Whether [component] can be rendered natively on this device.
  bool supportsNative(String component) => nativeComponents.contains(component);

  /// Convenience predicate for feature gating in app code.
  ///
  /// ```dart
  /// if (NativeAdaptiveUi.platform.isAtLeast(ios: 26)) { ... }
  /// ```
  bool isAtLeast({int? ios, int? android, int? macos, int? androidApi}) {
    return switch (osName) {
      'ios' => ios != null && majorVersion >= ios,
      'macos' => macos != null && majorVersion >= macos,
      'android' => (android != null && majorVersion >= android) ||
          (androidApi != null && (androidSdkInt ?? 0) >= androidApi),
      _ => false,
    };
  }

  @override
  String toString() => 'PlatformInfo($osName $majorVersion.$minorVersion, '
      'api=$androidSdkInt, $deviceFormFactor, era=$era, '
      'native=${nativeComponents.length})';
}
