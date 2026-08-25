import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';

import '../core/native_bridge.dart';
import '../core/native_component_view.dart';
import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// M3E's slider size ladder — [m3.material.io/components/sliders/specs](https://m3.material.io/components/sliders/specs).
/// Track height is the one dimension `SliderThemeData` can actually express;
/// handle width/height, track shape and inset-icon size are the rest of the
/// published table and are not reproduced pixel-for-pixel here.
enum AdaptiveSliderSize {
  /// 16dp track. The default, and the only size Material 3 (non-Expressive)
  /// ever draws.
  xs(16),

  /// 24dp track.
  s(24),

  /// 40dp track.
  m(40),

  /// 56dp track.
  l(56),

  /// 96dp track.
  xl(96);

  const AdaptiveSliderSize(this.trackHeight);

  /// dp, from the published table. Only applied on `DesignEra.isExpressive` —
  /// every other era ignores it, matching how [AdaptiveSlider] already
  /// ignores `year2023` outside Expressive.
  final double trackHeight;
}

/// A continuous value selector in the host platform's idiom.
///
/// This is one of the widgets where native embedding earns its cost on Apple
/// eras: the iOS 26 slider's glass track samples the wallpaper behind it in a
/// way Flutter cannot reproduce. When a native slider is unavailable the Dart
/// implementation takes over with no API change.
///
/// [size] and [vertical] cover the two M3E configurations `SliderThemeData`
/// can actually express. The spec's centered-origin variant and inset icons
/// are not — `SliderThemeData` has no knob for either — and are not
/// reproduced here rather than faked with a lookalike.
class AdaptiveSlider extends StatelessWidget with AdaptiveRenderMixin {
  const AdaptiveSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.preferNative,
    this.size = AdaptiveSliderSize.xs,
    this.vertical = false,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;

  /// Number of discrete stops. Null means continuous.
  final int? divisions;

  /// M3E's size ladder (XS–XL). Ignored on every era except
  /// `DesignEra.isExpressive`, and on Apple eras, which always take the
  /// native or Cupertino track regardless of this value.
  final AdaptiveSliderSize size;

  /// Rotates the Material slider onto a vertical axis. An M3E-only
  /// configuration; Flutter's `Slider` has no native vertical mode, so this
  /// is a `RotatedBox` approximation rather than a distinct widget the way
  /// the system's own vertical slider is.
  final bool vertical;

  @override
  final bool? preferNative;

  @override
  String? get nativeComponent => NativeComponents.slider;

  double get _clamped => value.clamp(min, max).toDouble();

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    // Native embedding is gated to glass eras: on iOS 26 the real UISlider's
    // track picks up the transient glass treatment while being dragged, which
    // is the whole point of paying for a platform view. On iosClassic the
    // CupertinoSlider is the correct Dart approximation and avoids a native
    // control that would render with the host OS's appearance regardless of
    // the era override.
    if (strategyFor(context).isNative && era.isApple && tokens.hasGlass) {
      return NativeComponentView(
        viewType: 'dev.gauravraj/${NativeComponents.slider}',
        creationParams: <String, Object?>{
          'value': _clamped,
          'min': min,
          'max': max,
          'divisions': divisions,
          'enabled': onChanged != null,
        },
        fallbackSize: Size(double.infinity, tokens.controlHeight),
        // Without a horizontal drag recognizer the platform view loses every
        // drag to an enclosing scrollable, which makes the slider look broken
        // inside a list. This is the most common platform-view bug in adaptive
        // packages, so it is handled here once for every native control.
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          const Factory<OneSequenceGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
          ),
        },
        onEvent: (event, payload) {
          if (event == 'valueChanged' && payload is num) {
            onChanged?.call(payload.toDouble());
          }
        },
      );
    }

    if (era.isApple) {
      return CupertinoSlider(
        value: _clamped,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
      );
    }

    final slider = Slider(
      value: _clamped,
      onChanged: onChanged,
      min: min,
      max: max,
      divisions: divisions,
    );

    if (!era.isExpressive) return slider;

    // Material 3 Expressive's slider is a different object, not a restyled one:
    // the handle is a 4dp vertical bar rather than a circle, the active and
    // inactive tracks are separated by a gap, and a stop indicator marks the
    // end of the range. Flutter gates all of that behind `year2023: false`.
    //
    // The flag is deprecated because it is a transition switch — it disappears
    // once the newer drawing becomes the default — but it is the only way to
    // reach the Expressive appearance today, and applying it through the theme
    // keeps the opt-in to this one place.
    final themed = SliderTheme(
      data: SliderThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        trackHeight: size.trackHeight,
      ),
      child: slider,
    );

    // Flutter's Slider has no vertical mode of its own, so this rotates the
    // whole themed widget — a `RotatedBox` approximation of M3E's vertical
    // orientation, not a distinct vertical control the way the system has.
    if (!vertical) return themed;
    return RotatedBox(quarterTurns: -1, child: themed);
  }
}
