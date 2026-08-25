import 'package:flutter/widgets.dart';

import '../core/design_era.dart';

/// The measurable half of a design language: radii, spacing, motion, density.
///
/// Colour is deliberately *not* here. Colour comes from the host theme —
/// dynamic colour on Android 12+, the system accent on Apple platforms — and
/// baking a palette into a widget package is how adaptive libraries end up
/// looking foreign on every OS at once.
@immutable
class AdaptiveTokens {
  const AdaptiveTokens({
    required this.era,
    required this.cornerRadius,
    required this.continuousCorners,
    required this.controlHeight,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.spacing,
    required this.minTapTarget,
    required this.motionDuration,
    required this.motionCurve,
    required this.pressedScale,
    required this.separatorThickness,
    required this.glassBlurSigma,
    required this.glassOpacity,
    required this.glassBorderOpacity,
  });

  final DesignEra era;

  /// Base corner radius for controls.
  final double cornerRadius;

  /// Whether corners are drawn as continuous ("squircle") curves. Apple's
  /// platforms use them; Material does not. Getting this wrong is the single
  /// most recognisable tell that a UI is not native.
  final bool continuousCorners;

  /// Standard interactive control height.
  final double controlHeight;

  final double horizontalPadding;
  final double verticalPadding;

  /// Base spacing unit; multiply for larger gaps.
  final double spacing;

  /// Minimum hit target. 44pt on Apple, 48dp on Material, 28pt with a pointer.
  final double minTapTarget;

  final Duration motionDuration;
  final Curve motionCurve;

  /// Scale applied while a control is pressed. Apple shrinks and dims;
  /// Material 3 Expressive squashes noticeably more than Material 3.
  final double pressedScale;

  final double separatorThickness;

  /// Backdrop blur radius for Liquid Glass surfaces. Zero on non-glass eras.
  final double glassBlurSigma;

  /// Tint opacity layered over the blur.
  final double glassOpacity;

  /// Opacity of the specular hairline that separates glass from its backdrop.
  final double glassBorderOpacity;

  bool get hasGlass => glassBlurSigma > 0;

  /// A [BorderRadius] honouring [continuousCorners].
  ///
  /// Flutter has no true continuous-corner primitive, so Apple eras use a
  /// slightly larger radius, which is the closest visual match a rounded
  /// rectangle can make to a squircle at typical control sizes.
  BorderRadius radius([double? override]) {
    final base = override ?? cornerRadius;
    return BorderRadius.circular(continuousCorners ? base * 1.15 : base);
  }

  /// Apple's concentric-corner rule: a child nested inside a rounded container
  /// should use the parent radius minus the padding between them, so the two
  /// curves stay visually parallel. iOS 26 leans on this heavily.
  double concentricRadius(double parentRadius, double inset) =>
      (parentRadius - inset).clamp(0.0, parentRadius).toDouble();

  static const Map<DesignEra, AdaptiveTokens> _table = {
    DesignEra.iosLiquidGlass: AdaptiveTokens(
      era: DesignEra.iosLiquidGlass,
      cornerRadius: 22,
      continuousCorners: true,
      controlHeight: 50,
      horizontalPadding: 20,
      verticalPadding: 14,
      spacing: 8,
      minTapTarget: 44,
      motionDuration: Duration(milliseconds: 350),
      motionCurve: Curves.easeOutCubic,
      pressedScale: 0.96,
      separatorThickness: 0.33,
      glassBlurSigma: 24,
      glassOpacity: 0.18,
      glassBorderOpacity: 0.35,
    ),
    DesignEra.iosClassic: AdaptiveTokens(
      era: DesignEra.iosClassic,
      cornerRadius: 10,
      continuousCorners: true,
      controlHeight: 44,
      horizontalPadding: 16,
      verticalPadding: 12,
      spacing: 8,
      minTapTarget: 44,
      motionDuration: Duration(milliseconds: 250),
      motionCurve: Curves.easeInOut,
      pressedScale: 1.0,
      separatorThickness: 0.33,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
    DesignEra.ipadLiquidGlass: AdaptiveTokens(
      era: DesignEra.ipadLiquidGlass,
      cornerRadius: 24,
      continuousCorners: true,
      controlHeight: 46,
      horizontalPadding: 22,
      verticalPadding: 13,
      spacing: 10,
      minTapTarget: 44,
      motionDuration: Duration(milliseconds: 330),
      motionCurve: Curves.easeOutCubic,
      pressedScale: 0.97,
      separatorThickness: 0.33,
      glassBlurSigma: 28,
      glassOpacity: 0.16,
      glassBorderOpacity: 0.32,
    ),
    DesignEra.ipadClassic: AdaptiveTokens(
      era: DesignEra.ipadClassic,
      cornerRadius: 10,
      continuousCorners: true,
      controlHeight: 44,
      horizontalPadding: 18,
      verticalPadding: 12,
      spacing: 10,
      minTapTarget: 44,
      motionDuration: Duration(milliseconds: 250),
      motionCurve: Curves.easeInOut,
      pressedScale: 1.0,
      separatorThickness: 0.33,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
    DesignEra.materialExpressive: AdaptiveTokens(
      era: DesignEra.materialExpressive,
      cornerRadius: 20,
      continuousCorners: false,
      controlHeight: 56,
      horizontalPadding: 24,
      verticalPadding: 16,
      spacing: 8,
      minTapTarget: 48,
      motionDuration: Duration(milliseconds: 500),
      motionCurve: Curves.elasticOut,
      pressedScale: 0.92,
      separatorThickness: 1,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
    DesignEra.material3: AdaptiveTokens(
      era: DesignEra.material3,
      cornerRadius: 20,
      continuousCorners: false,
      controlHeight: 40,
      horizontalPadding: 24,
      verticalPadding: 10,
      spacing: 8,
      minTapTarget: 48,
      motionDuration: Duration(milliseconds: 300),
      motionCurve: Curves.easeInOutCubicEmphasized,
      pressedScale: 1.0,
      separatorThickness: 1,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
    DesignEra.material3Legacy: AdaptiveTokens(
      era: DesignEra.material3Legacy,
      cornerRadius: 16,
      continuousCorners: false,
      controlHeight: 40,
      horizontalPadding: 20,
      verticalPadding: 10,
      spacing: 8,
      minTapTarget: 48,
      motionDuration: Duration(milliseconds: 250),
      motionCurve: Curves.easeInOut,
      pressedScale: 1.0,
      separatorThickness: 1,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
    DesignEra.macosTahoe: AdaptiveTokens(
      era: DesignEra.macosTahoe,
      cornerRadius: 10,
      continuousCorners: true,
      controlHeight: 28,
      horizontalPadding: 14,
      verticalPadding: 6,
      spacing: 8,
      minTapTarget: 28,
      motionDuration: Duration(milliseconds: 220),
      motionCurve: Curves.easeOutCubic,
      pressedScale: 0.98,
      separatorThickness: 0.5,
      glassBlurSigma: 30,
      glassOpacity: 0.14,
      glassBorderOpacity: 0.28,
    ),
    DesignEra.macosClassic: AdaptiveTokens(
      era: DesignEra.macosClassic,
      cornerRadius: 6,
      continuousCorners: true,
      controlHeight: 24,
      horizontalPadding: 12,
      verticalPadding: 5,
      spacing: 8,
      minTapTarget: 24,
      motionDuration: Duration(milliseconds: 180),
      motionCurve: Curves.easeInOut,
      pressedScale: 1.0,
      separatorThickness: 0.5,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
    DesignEra.fallback: AdaptiveTokens(
      era: DesignEra.fallback,
      cornerRadius: 16,
      continuousCorners: false,
      controlHeight: 40,
      horizontalPadding: 20,
      verticalPadding: 10,
      spacing: 8,
      minTapTarget: 48,
      motionDuration: Duration(milliseconds: 250),
      motionCurve: Curves.easeInOut,
      pressedScale: 1.0,
      separatorThickness: 1,
      glassBlurSigma: 0,
      glassOpacity: 0,
      glassBorderOpacity: 0,
    ),
  };

  /// Tokens for [era]. Total — every era has an entry.
  static AdaptiveTokens of(DesignEra era) =>
      _table[era] ?? _table[DesignEra.fallback]!;
}
