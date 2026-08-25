import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin, dependency-free wrapper over the plugin's platform channel.
///
/// The package deliberately ships its own channel instead of depending on
/// `device_info_plus`: OS version is the core input to era resolution, and a
/// UI package should not force a version constraint on an unrelated plugin
/// into every consumer's dependency graph.
@immutable
class NativeBridge {
  const NativeBridge._();

  static const MethodChannel channel =
      MethodChannel('dev.gauravraj/native_adaptive_ui');

  /// Raw platform description from the host OS.
  ///
  /// Returns `null` on platforms with no native implementation (web, Windows,
  /// Linux) or when the channel is unavailable (unit tests, add-to-app hosts
  /// that have not registered the plugin). Callers must degrade, never throw.
  static Future<Map<String, Object?>?> describePlatform() async {
    try {
      final result =
          await channel.invokeMapMethod<String, Object?>('describePlatform');
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error, stack) {
      _report('describePlatform failed', error, stack);
      return null;
    }
  }

  /// Identifiers of native components this device can actually host.
  ///
  /// A component appearing here means the OS ships it *and* the plugin has a
  /// verified embedding for it. Anything absent renders through the Dart
  /// fallback, which is why this list is queried rather than inferred from the
  /// OS version.
  static Future<Set<String>> availableComponents() async {
    try {
      final result =
          await channel.invokeListMethod<String>('availableComponents');
      return result?.toSet() ?? const <String>{};
    } on MissingPluginException {
      return const <String>{};
    } on PlatformException catch (error, stack) {
      _report('availableComponents failed', error, stack);
      return const <String>{};
    }
  }

  /// Presents a real `UIAlertController` and resolves to the chosen action's
  /// index, or null when it was dismissed without a choice.
  ///
  /// [style] selects `presentAlert` or `presentActionSheet`. The outer future
  /// resolves to `false` when the host could not present at all, which is the
  /// signal for the caller to render its own dialog instead — a null *index* from
  /// a successful presentation means "dismissed", and the two must not be
  /// confused.
  static Future<({bool presented, int? index})> presentAlert({
    required bool actionSheet,
    String? title,
    String? message,
    required List<Map<String, Object?>> actions,
    String? cancelLabel,
    Map<String, double>? anchorRect,
  }) async {
    try {
      final index = await channel.invokeMethod<int>(
        actionSheet ? 'presentActionSheet' : 'presentAlert',
        <String, Object?>{
          'title': title,
          'message': message,
          'actions': actions,
          'cancelLabel': cancelLabel,
          'anchorRect': anchorRect,
        },
      );
      return (presented: true, index: index);
    } on MissingPluginException {
      return (presented: false, index: null);
    } on PlatformException catch (error, stack) {
      _report('presentAlert failed', error, stack);
      return (presented: false, index: null);
    }
  }

  static void _report(String message, Object error, StackTrace stack) {
    if (kDebugMode) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'native_adaptive_ui',
          context: ErrorDescription(message),
        ),
      );
    }
  }
}

/// Stable identifiers for every component that has a native implementation.
///
/// These strings are the contract between Dart and the Swift/Kotlin sides;
/// keep them in sync with the `availableComponents` switch in each host plugin.
abstract final class NativeComponents {
  /// A `UIVisualEffectView` carrying `UIGlassEffect`, used as a backdrop behind
  /// Flutter-drawn chrome. iOS 26 and later.
  static const String glassSurface = 'glass_surface';

  /// A Liquid Glass `UIButton`, for buttons in the functional layer only.
  /// iOS 26 and later.
  static const String glassButton = 'glass_button';

  /// A real `UISwitch`. Every iOS version.
  static const String toggle = 'switch';

  /// A real `UISlider`. Every iOS version.
  static const String slider = 'slider';

  /// A real `UISegmentedControl`. Every iOS version.
  ///
  /// `CupertinoSlidingSegmentedControl` still draws the iOS 13 control on iOS 26,
  /// where the system one carries a Liquid Glass selection thumb and animates it
  /// between segments.
  static const String segmentedControl = 'segmented_control';

  /// A real `UIAlertController` in `.alert` style. Every iOS version.
  ///
  /// A presented view controller rather than a platform view, so UIKit owns the
  /// whole surface — including its blur over the Flutter content beneath, which a
  /// platform view could not achieve.
  static const String alert = 'alert';

  /// A real `UIAlertController` in `.actionSheet` style, presented as a popover in
  /// regular-width windows. Every iOS version.
  static const String actionSheet = 'action_sheet';

  /// A real `UITabBar`. iOS 26 and later.
  ///
  /// The system owns the glass material, the selection morph and the interactive
  /// liquid response to touch — none of which can be reproduced over Flutter
  /// content, because `UIVisualEffectView` cannot sample a `CAMetalLayer`
  /// backdrop. Requires every destination to carry either an SF Symbol name or
  /// a decoded custom icon, since a `UITabBarItem` needs a `UIImage` and a
  /// Flutter widget cannot become one — see `AdaptiveDestination.sfSymbol` and
  /// `AdaptiveDestination.iconImage`.
  static const String tabBar = 'tab_bar';

  /// A real `UINavigationBar`. iOS 26 and later.
  ///
  /// `CupertinoNavigationBar` still draws the iOS 18 bar. A real one carries
  /// the system's own Liquid Glass material the same way the tab bar does —
  /// but it also owns the title and back button, so it is used only when
  /// `AdaptiveScaffold.leadingSfSymbol`/`actionSfSymbols` supply SF Symbol
  /// names for a plain title bar; `leading`/`actions` widgets still render
  /// `CupertinoNavigationBar` exactly as before.
  static const String navigationBar = 'navigation_bar';
}
