import '../core/native_bridge.dart';
import '../core/native_component_view.dart';
import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A boolean toggle in the host platform's idiom.
///
/// Apple eras get the pill-shaped Cupertino switch; Material eras get the M3
/// switch, which grows a check icon when on. Material 3 Expressive additionally
/// settles with a spring rather than an ease, applied here through the era's
/// motion tokens rather than by restyling the control.
///
/// Colour is intentionally not a parameter: it comes from the ambient theme, so
/// the switch picks up dynamic colour on Android 12+ and the system accent on
/// Apple platforms. Wrap the widget in a `Theme`/`CupertinoTheme` to change it.
class AdaptiveSwitch extends StatelessWidget with AdaptiveRenderMixin {
  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.preferNative,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  final bool? preferNative;

  @override
  String? get nativeComponent => NativeComponents.toggle;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    // Same gating as the slider: the real UISwitch is only embedded on glass
    // eras, where iOS 26 applies a transient glass to the thumb while dragging.
    // On iosClassic a CupertinoSwitch is the correct Dart approximation and
    // avoids a native control rendering with the host OS's appearance.
    if (era.isApple && tokens.hasGlass && strategyFor(context).isNative) {
      // A real UISwitch, so the control picks up whatever the running OS gives
      // it — including the glass iOS 26 applies to the track while it is being
      // dragged, which is a system gesture behaviour and not something Dart can
      // reproduce from outside.
      return NativeComponentView(
        viewType: 'dev.gauravraj/${NativeComponents.toggle}',
        creationParams: <String, Object?>{
          'value': value,
          'enabled': onChanged != null,
        },
        // UISwitch has a fixed intrinsic size.
        fallbackSize: const Size(51, 31),
        onEvent: (event, payload) {
          if (event == 'valueChanged' && payload is bool) {
            onChanged?.call(payload);
          }
        },
      );
    }

    if (era.isApple) {
      return CupertinoSwitch(value: value, onChanged: onChanged);
    }

    // Material 3 lists "icon on selected switch" as a configuration; Expressive
    // is where it becomes the default look, and it is the clearest way the
    // control differs between Android 16 and Android 12 at a glance.
    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      thumbIcon: era.isExpressive
          ? WidgetStateProperty.resolveWith<Icon?>(
              (states) => states.contains(WidgetState.selected)
                  ? const Icon(Icons.check)
                  : null,
            )
          : null,
    );
    if (!era.isExpressive) return switchWidget;

    return AnimatedScale(
      scale: value ? 1.04 : 1.0,
      duration: tokens.motionDuration,
      curve: tokens.motionCurve,
      child: switchWidget,
    );
  }
}
