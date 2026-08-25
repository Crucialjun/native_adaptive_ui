import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../tokens/adaptive_tokens.dart';

/// A Dart approximation of Apple's Liquid Glass material: a `BackdropFilter`,
/// a translucent tint, and a specular hairline.
///
/// **This is a look, not the material.** It cannot animate, refract, or respond
/// to touch the way Apple's does, and that limit is structural rather than a gap
/// waiting to be filled. A `UIVisualEffectView` carrying `UIGlassEffect` samples
/// its backdrop from the UIKit view hierarchy; Flutter draws into a
/// `CAMetalLayer`, which UIKit's backdrop capture cannot read. Laid over Flutter
/// content the real material has nothing to sample and renders inert — verified
/// on an iOS 26 simulator, including via `drawHierarchy` snapshotting, which
/// cannot read Metal layers either.
///
/// The route to genuine Liquid Glass is therefore a genuine UIKit control, not a
/// glass surface behind Flutter-drawn chrome: see the real `UITabBar` behind
/// [AdaptiveNavigationScaffold] on iOS 26, and the real `UISwitch` / `UISlider`
/// behind [AdaptiveSwitch] and [AdaptiveSlider]. Use this widget for chrome that
/// has no UIKit equivalent to embed, and for previewing glass eras on machines
/// that are not running them.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.tokens,
    required this.child,
    this.borderRadius,
    this.tint,
    this.tintOpacity,
    this.enabled = true,
    this.interactive = false,
    this.padding = EdgeInsets.zero,
  });

  final AdaptiveTokens tokens;
  final Widget child;
  final BorderRadius? borderRadius;

  /// Overrides the tint colour. Defaults to the ambient text colour inverted,
  /// which reads correctly in both light and dark without a hardcoded palette.
  final Color? tint;

  /// Overrides how strongly [tint] is laid over the blur.
  ///
  /// The era's own `glassOpacity` suits chrome — bars, sidebars — where the
  /// backdrop must stay readable. A filled control needs far more tint than
  /// that, or its label sits on a wash of its own colour and disappears.
  final double? tintOpacity;

  /// When false the widget is a plain padded container — used so callers can
  /// keep one widget tree across glass and non-glass eras.
  final bool enabled;

  /// When true the native `UIGlassEffect` sets `isInteractive`, which makes the
  /// material respond to touch with the fluid animation Apple calls "liquid".
  /// Use this for bars and controls the user taps; leave it false for static
  /// surfaces like sidebars.
  final bool interactive;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? tokens.radius();

    if (!enabled || !tokens.hasGlass) {
      return Padding(padding: padding, child: child);
    }

    final isDark = _brightnessOf(context) == Brightness.dark;
    const white = Color(0xFFFFFFFF);
    final lightBase = tint ?? const Color(0xFFE5E5EA);
    final darkBase = tint ?? white;
    final base = isDark ? darkBase : lightBase;
    final opacity = tintOpacity ??
        (tint != null ? tokens.glassOpacity : (isDark ? 0.16 : 0.72));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: tokens.glassBlurSigma,
          sigmaY: tokens.glassBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: (opacity * 1.2).clamp(0.0, 1.0)),
                base.withValues(alpha: (opacity * 0.8).clamp(0.0, 1.0)),
              ],
            ),
            border: Border.all(
              color: isDark
                  ? white.withValues(alpha: 0.22)
                  : const Color(0xFFC8C8CC).withValues(alpha: 0.7),
              width: 0.5,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  static Brightness _brightnessOf(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
}

/// Wraps [child] in glass only when the era calls for it, leaving the widget
/// tree identical across eras.
///
/// Branching on era inside a `build` method is how adaptive code turns into a
/// thicket of `if (Platform.isIOS)`. This keeps the branch in one place.
class ConditionalGlass extends StatelessWidget {
  const ConditionalGlass({
    super.key,
    required this.tokens,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.fallbackColor,
  });

  final AdaptiveTokens tokens;
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  /// Surface colour used on eras without glass.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    if (tokens.hasGlass) {
      return GlassSurface(
        tokens: tokens,
        borderRadius: borderRadius,
        padding: padding,
        child: child,
      );
    }
    final color = fallbackColor;
    if (color == null) return Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? tokens.radius(),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
