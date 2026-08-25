import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'design_era.dart';
import 'platform_info.dart';
import 'render_strategy.dart';

/// Entry point for the package.
///
/// Call [ensureInitialized] before `runApp` so that era resolution is available
/// synchronously during the first frame:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await NativeAdaptiveUi.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
///
/// Skipping the call is not fatal — widgets fall back to
/// [PlatformInfo.fallback], which renders iOS 18 / Android 15 styling — but a
/// debug-mode warning is emitted once, because silently shipping the wrong era
/// is worse than a noisy log.
abstract final class NativeAdaptiveUi {
  static PlatformInfo? _platform;
  static bool _warned = false;

  /// Global policy. Change before `runApp`, or per-subtree via
  /// `AdaptiveScope(policy: ...)`.
  static NativePolicy policy = NativePolicy.auto;

  /// Forces a specific era regardless of the host OS. Intended for design
  /// review, screenshot generation, and demo builds — not production.
  static DesignEra? eraOverride;

  /// Resolved device description. Safe to read at any time.
  static PlatformInfo get platform {
    final resolved = _platform;
    if (resolved == null) {
      _warnUninitialized();
      return PlatformInfo.fallback();
    }
    return resolved;
  }

  /// True once [ensureInitialized] has completed.
  static bool get isInitialized => _platform != null;

  /// The era in effect, honouring [eraOverride].
  static DesignEra get era => eraOverride ?? platform.era;

  /// Queries the host OS and caches the result. Idempotent.
  static Future<PlatformInfo> ensureInitialized() async {
    final cached = _platform;
    if (cached != null) return cached;
    final resolved = await PlatformInfo.resolve();
    _platform = resolved;
    return resolved;
  }

  /// Injects a description without touching the platform channel.
  ///
  /// Tests and design-review builds use this to render any era on any machine:
  ///
  /// ```dart
  /// NativeAdaptiveUi.debugSetPlatform(
  ///   PlatformInfo.fake(era: DesignEra.ipadLiquidGlass),
  /// );
  /// ```
  @visibleForTesting
  static void debugSetPlatform(PlatformInfo? info) {
    _platform = info;
    _warned = false;
  }

  static void _warnUninitialized() {
    if (_warned || !kDebugMode) return;
    _warned = true;
    debugPrint(
      '[native_adaptive_ui] NativeAdaptiveUi.ensureInitialized() was not '
      'awaited before runApp(). Falling back to iOS 18 / Android 15 styling, '
      'so Liquid Glass and Material 3 Expressive will not appear. Add:\n'
      '  WidgetsFlutterBinding.ensureInitialized();\n'
      '  await NativeAdaptiveUi.ensureInitialized();\n'
      'to main().',
    );
  }
}

/// Per-subtree configuration, read by every adaptive widget.
///
/// An [AdaptiveScope] is installed automatically by `AdaptiveApp`. Nest another
/// one to change policy or era for part of the tree — a settings screen pinned
/// to Dart rendering, for example.
class AdaptiveScope extends StatelessWidget {
  const AdaptiveScope({
    super.key,
    this.era,
    this.policy,
    this.platform,
    required this.child,
  });

  /// Overrides the resolved era for this subtree.
  final DesignEra? era;

  /// Overrides the native-rendering policy for this subtree.
  final NativePolicy? policy;

  /// Overrides the device description for this subtree. Mostly useful in tests.
  final PlatformInfo? platform;

  final Widget child;

  /// Reads the nearest configuration. Falls back to global state when no
  /// [AdaptiveScope] is present, so widgets work standalone.
  static AdaptiveConfig of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_AdaptiveScopeMarker>();
    final info = inherited?.platform ?? NativeAdaptiveUi.platform;
    final baseEra = inherited?.era ?? NativeAdaptiveUi.eraOverride ?? info.era;
    final width = MediaQuery.maybeSizeOf(context)?.width;

    return AdaptiveConfig(
      platform: info,
      era: baseEra,
      policy: inherited?.policy ?? NativeAdaptiveUi.policy,
      formFactor: _effectiveFormFactor(info, baseEra, width),
    );
  }

  /// Blends the device idiom with the *usable* window width.
  ///
  /// An iPad in Slide Over is a tablet running phone-width chrome; treating it
  /// as a tablet produces a sidebar crammed into 320 logical pixels. Layout
  /// therefore follows the window, while the design era keeps following the OS.
  static FormFactor _effectiveFormFactor(
    PlatformInfo info,
    DesignEra era,
    double? width,
  ) {
    if (width == null) return info.deviceFormFactor;
    if (era.isPointerFirst) {
      return width < 600 ? FormFactor.phone : FormFactor.desktop;
    }
    if (width >= 600) return FormFactor.tablet;
    return FormFactor.phone;
  }

  @override
  Widget build(BuildContext context) {
    return _AdaptiveScopeMarker(
      era: era,
      policy: policy,
      platform: platform,
      child: child,
    );
  }
}

class _AdaptiveScopeMarker extends InheritedWidget {
  const _AdaptiveScopeMarker({
    required this.era,
    required this.policy,
    required this.platform,
    required super.child,
  });

  final DesignEra? era;
  final NativePolicy? policy;
  final PlatformInfo? platform;

  @override
  bool updateShouldNotify(_AdaptiveScopeMarker oldWidget) =>
      era != oldWidget.era ||
      policy != oldWidget.policy ||
      platform != oldWidget.platform;
}

/// The resolved configuration a widget builds against.
@immutable
class AdaptiveConfig {
  const AdaptiveConfig({
    required this.platform,
    required this.era,
    required this.policy,
    required this.formFactor,
  });

  final PlatformInfo platform;
  final DesignEra era;
  final NativePolicy policy;

  /// Form factor for *layout*, derived from the current window rather than the
  /// device — an iPad in Slide Over reports [FormFactor.phone] here while its
  /// [era] stays an iPad era.
  final FormFactor formFactor;

  /// Resolves how [component] should be drawn under this configuration.
  RenderStrategy strategyFor(String component, {bool? override}) {
    return resolveStrategy(
      component: component,
      availableComponents: platform.nativeComponents,
      policy: policy,
      widgetOverride: override,
    );
  }
}
