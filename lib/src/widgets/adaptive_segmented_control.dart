import 'package:flutter/services.dart' show MethodChannel;

import '../core/native_bridge.dart';
import '../core/native_component_view.dart';
import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A small set of mutually exclusive choices.
///
/// On glass eras this is a real `UISegmentedControl`, because iOS 26 gives that
/// control a Liquid Glass selection thumb and slides it between segments — and
/// `CupertinoSlidingSegmentedControl`, faithful as it is to the iOS 13 control,
/// still draws the iOS 13 control. Same reasoning as [AdaptiveSwitch] and
/// [AdaptiveSlider]: the appearance belongs to the system, so the control has to
/// be the system's.
///
/// Classic Apple eras use the Cupertino sliding control; Material eras use
/// `SegmentedButton`. The two design systems have genuinely different affordances
/// — Material's shows check marks and supports multi-select, Cupertino's slides a
/// thumb — so this widget exposes only what both can honour, and does not pretend
/// to offer multi-select on a control that has no idiom for it.
class AdaptiveSegmentedControl<T extends Object> extends StatefulWidget
    with AdaptiveRenderMixin {
  const AdaptiveSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.preferNative,
  });

  /// Ordered choices. Insertion order is the display order on both eras.
  final Map<T, String> segments;

  final T value;
  final ValueChanged<T>? onChanged;

  @override
  final bool? preferNative;

  @override
  String? get nativeComponent => NativeComponents.segmentedControl;

  @override
  State<AdaptiveSegmentedControl<T>> createState() =>
      _AdaptiveSegmentedControlState<T>();
}

class _AdaptiveSegmentedControlState<T extends Object>
    extends State<AdaptiveSegmentedControl<T>> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(AdaptiveSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _channel?.invokeMethod<void>('setSelectedIndex', _indexOf(widget.value));
    }
  }

  int _indexOf(T value) => widget.segments.keys.toList().indexOf(value);

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;
    final segments = widget.segments;
    final value = widget.value;
    final onChanged = widget.onChanged;

    assert(
      segments.containsKey(value),
      'AdaptiveSegmentedControl: value $value is not one of the segments.',
    );
    assert(
      !context.adaptive.formFactor.isCompact || segments.length <= 5,
      'Apple caps segmented controls at about five segments on iPhone and '
      'five to seven in a wide interface. ${segments.length} will not read '
      'well in a compact window — consider a menu or a list instead.',
    );

    // Same gating as the switch and the slider: the real control is embedded
    // only on glass eras, where iOS 26 supplies the glass thumb. On iosClassic
    // the Cupertino control is the correct rendering, not a compromise.
    if (era.isApple &&
        tokens.hasGlass &&
        widget.strategyFor(context).isNative) {
      final keys = segments.keys.toList();

      return SizedBox(
        height: tokens.controlHeight,
        child: NativeComponentView(
          viewType: 'dev.gauravraj/${NativeComponents.segmentedControl}',
          creationParams: <String, Object?>{
            'titles': <String>[...segments.values],
            'selectedIndex': keys.indexOf(value),
            'enabled': onChanged != null,
          },
          onChannelReady: (channel) => _channel = channel,
          onEvent: (event, payload) {
            if (event == 'valueChanged' &&
                payload is int &&
                payload >= 0 &&
                payload < keys.length) {
              onChanged?.call(keys[payload]);
            }
          },
        ),
      );
    }

    if (era.isApple) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        onValueChanged: (next) {
          if (next != null) onChanged?.call(next);
        },
        children: {
          for (final entry in segments.entries)
            entry.key: Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing * 0.5),
              child: Text(entry.value),
            ),
        },
      );
    }

    return SegmentedButton<T>(
      segments: [
        for (final entry in segments.entries)
          ButtonSegment<T>(value: entry.key, label: Text(entry.value)),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) {
              if (selection.isNotEmpty) onChanged(selection.first);
            },
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: tokens.radius()),
      ),
    );
  }
}
