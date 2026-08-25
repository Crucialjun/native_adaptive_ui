/// How a widget should be drawn.
enum RenderStrategy {
  /// A real host-OS control embedded through a platform view.
  native,

  /// A Flutter implementation of the same control.
  dart;

  bool get isNative => this == RenderStrategy.native;
}

/// App-wide policy for choosing between native and Dart rendering.
///
/// Native embedding buys authenticity and costs control: platform views have
/// their own lifecycle, they interact awkwardly with Flutter's gesture arena,
/// and they do not participate in hot reload. Making the policy explicit means
/// a team can ship native-first, then dial back to `dartOnly` for a screen that
/// misbehaves without rewriting a single widget.
enum NativePolicy {
  /// Use a native control whenever the device reports one, otherwise Dart.
  /// The default.
  auto,

  /// Never embed platform views. Every widget renders in Dart, still
  /// era-correct. Recommended for widget tests, golden tests, and screens with
  /// heavy custom gesture handling.
  dartOnly;
}

/// Resolves [RenderStrategy] for a single component.
///
/// Simulators deliberately take the same path as hardware. An earlier version
/// forced them to Dart on the theory that some materials render differently
/// there; the practical effect was that the native path never ran during
/// development, so nobody saw it until a device build. Liquid Glass renders
/// correctly in the iOS 26 simulator, and a path that is never exercised is a
/// path that is never right.
///
/// Kept as a free function rather than a method so widgets stay trivially
/// testable: pass a synthetic capability set and assert on the outcome.
RenderStrategy resolveStrategy({
  required String component,
  required Set<String> availableComponents,
  required NativePolicy policy,
  bool? widgetOverride,
}) {
  if (widgetOverride == false) return RenderStrategy.dart;
  if (policy == NativePolicy.dartOnly) return RenderStrategy.dart;
  if (!availableComponents.contains(component)) return RenderStrategy.dart;
  return RenderStrategy.native;
}
