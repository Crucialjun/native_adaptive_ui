import 'package:flutter/widgets.dart';

import '../core/adaptive_config.dart';
import '../core/design_era.dart';
import '../core/render_strategy.dart';
import '../tokens/adaptive_tokens.dart';

/// Convenience accessors shared by every adaptive widget.
extension AdaptiveContext on BuildContext {
  /// Resolved configuration for this subtree.
  AdaptiveConfig get adaptive => AdaptiveScope.of(this);

  /// Design era in effect here.
  DesignEra get era => adaptive.era;

  /// Measurable design tokens for the era in effect.
  AdaptiveTokens get adaptiveTokens => AdaptiveTokens.of(adaptive.era);

  /// Padding a scrollable body needs so its first and last items clear the
  /// translucent chrome above and below, while still scrolling beneath it.
  ///
  /// A `ListView` with no `padding` picks this inset up from `MediaQuery` on
  /// its own. The moment an explicit `padding` is supplied that automatic inset
  /// is lost, and the first rows disappear behind the navigation bar — the most
  /// common way an otherwise correct adaptive screen looks broken on iOS.
  ///
  /// Call this from a context *inside* the scaffold — a `Builder` is usually
  /// the shortest way — since the bar's height only reaches `MediaQuery` below
  /// the scaffold itself.
  /// When a keyboard is open, `viewInsets.bottom` carries its height while
  /// `padding.bottom` collapses to zero. Taking the larger of the two is what
  /// keeps the last rows of a form reachable above the keyboard instead of
  /// sliding underneath it.
  EdgeInsets adaptiveScrollPadding({
    double horizontal = 0,
    double vertical = 0,
  }) {
    final media = MediaQuery.of(this);
    final bottom = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    return EdgeInsets.fromLTRB(
      horizontal,
      media.padding.top + vertical,
      horizontal,
      bottom + vertical,
    );
  }
}

/// Mixin for widgets that can render either natively or in Dart.
///
/// Widgets call [strategyFor] rather than inspecting the platform directly, so
/// that policy, capability probing and per-widget overrides are applied in one
/// consistent order.
mixin AdaptiveRenderMixin {
  /// The native component identifier this widget can be backed by, or `null`
  /// when it is Dart-only by design.
  String? get nativeComponent => null;

  /// Per-instance override: `true` forces native when available, `false`
  /// forces Dart, `null` follows policy.
  bool? get preferNative => null;

  RenderStrategy strategyFor(BuildContext context) {
    final component = nativeComponent;
    if (component == null) return RenderStrategy.dart;
    return context.adaptive.strategyFor(component, override: preferNative);
  }
}

/// Applies the era's press feedback: Apple dims and shrinks slightly, Material
/// 3 Expressive squashes hard and springs back, Material 3 relies on ripple
/// alone.
///
/// Written as a shared widget because press feel is one of the details that
/// reads as "not native" when it is even slightly wrong, and duplicating it per
/// widget guarantees drift.
class AdaptivePressable extends StatefulWidget {
  const AdaptivePressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<AdaptivePressable> createState() => _AdaptivePressableState();
}

class _AdaptivePressableState extends State<AdaptivePressable> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.adaptiveTokens;
    final scale = _pressed ? tokens.pressedScale : 1.0;
    final opacity = _pressed && tokens.era.isApple ? 0.72 : 1.0;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _interactive ? widget.onPressed : null,
      child: AnimatedScale(
        scale: scale,
        duration: tokens.motionDuration,
        curve: tokens.motionCurve,
        child: AnimatedOpacity(
          opacity: _interactive ? opacity : 0.4,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}
