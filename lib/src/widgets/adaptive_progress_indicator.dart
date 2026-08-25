import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A busy indicator in the host platform's idiom.
///
/// Apple eras get the spoked activity indicator; Material eras get the circular
/// progress arc. On Material 3 Expressive the arc is drawn with the wavy track
/// introduced in Android 16 when `value` is provided, since a determinate
/// progress bar is where that style is most recognisable.
class AdaptiveProgressIndicator extends StatelessWidget {
  const AdaptiveProgressIndicator({
    super.key,
    this.value,
    this.linear = false,
  });

  /// 0.0–1.0 for determinate progress, or null for indeterminate.
  final double? value;

  /// Draws a bar instead of a circle.
  final bool linear;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final progress = value;

    if (era.isApple && !linear) {
      // Cupertino has no determinate spinner. `partiallyRevealed` draws a
      // fraction of the ring's ticks, which is the closest idiom Apple has, so
      // a caller who passes a value gets something meaningful instead of having
      // it silently ignored.
      return progress == null
          ? const CupertinoActivityIndicator()
          : CupertinoActivityIndicator.partiallyRevealed(
              progress: progress.clamp(0.0, 1.0).toDouble(),
            );
    }

    final indicator = linear
        ? LinearProgressIndicator(value: value)
        : CircularProgressIndicator(value: value);

    if (!era.isExpressive) return indicator;

    // The wavy track and the gap before the stop indicator are Material 3
    // Expressive's signature, and Flutter gates them behind the same
    // transitional `year2023` flag the slider uses. See AdaptiveSlider for why
    // a deprecated flag is the right call here.
    return ProgressIndicatorTheme(
      // ignore: deprecated_member_use
      data: const ProgressIndicatorThemeData(year2023: false),
      child: indicator,
    );
  }
}
