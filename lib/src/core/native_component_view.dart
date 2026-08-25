import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Embeds a host-OS control as a platform view, with a per-view method channel
/// for events flowing back into Dart.
///
/// Platform views are the expensive path: each one is a real UIView/View
/// composited into the Flutter scene, they do not participate in hot reload,
/// and they compete with Flutter for gestures. This widget centralises the
/// awkward parts so individual adaptive widgets stay readable, and so a bug in
/// the embedding is fixed once rather than thirty times.
class NativeComponentView extends StatefulWidget {
  const NativeComponentView({
    super.key,
    required this.viewType,
    required this.creationParams,
    this.fallbackSize,
    this.onEvent,
    this.onChannelReady,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  /// Registered view type on the host side, e.g. `dev.gauravraj/glass_button`.
  final String viewType;

  /// Serialisable configuration handed to the native constructor.
  final Map<String, Object?> creationParams;

  /// Size used while the platform view is being created, and on hosts where it
  /// never arrives. Keeping a concrete size avoids a layout jump when the
  /// native view attaches.
  ///
  /// Null means "fill whatever the parent gives me", which is what a backdrop
  /// surface wants.
  final Size? fallbackSize;

  /// Events raised by the native control: `('pressed', null)`,
  /// `('valueChanged', 0.4)`, and so on.
  final void Function(String event, Object? payload)? onEvent;

  /// Hands back the per-view channel once the platform view exists, for controls
  /// that need state pushed *down* as well as events coming up — a native tab
  /// bar whose selection can change from a deep link, for instance.
  ///
  /// Called once per platform view. The channel is torn down with the widget, so
  /// callers must not retain it past [State.dispose].
  final void Function(MethodChannel channel)? onChannelReady;

  /// Gesture recognizers the platform view should win outright. Without at
  /// least one vertical/horizontal drag recognizer, a native control inside a
  /// scroll view will lose every drag to the scrollable.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<NativeComponentView> createState() => _NativeComponentViewState();
}

class _NativeComponentViewState extends State<NativeComponentView> {
  MethodChannel? _channel;

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('${widget.viewType}/$id');
    channel.setMethodCallHandler((call) async {
      widget.onEvent?.call(call.method, call.arguments);
      return null;
    });
    _channel = channel;
    widget.onChannelReady?.call(channel);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = <String, Object?>{
      ...widget.creationParams,
      'brightness':
          (MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light)
              .name,
      'textScale': MediaQuery.maybeTextScalerOf(context)?.scale(1.0) ?? 1.0,
    };

    final Widget view = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => UiKitView(
          viewType: widget.viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
        ),
      TargetPlatform.macOS => AppKitView(
          viewType: widget.viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
        ),
      TargetPlatform.android => AndroidView(
          viewType: widget.viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
        ),
      _ => const SizedBox.shrink(),
    };

    final size = widget.fallbackSize;
    if (size == null) return view;
    return SizedBox(width: size.width, height: size.height, child: view);
  }
}
