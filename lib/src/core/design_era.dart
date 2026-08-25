/// The design language a widget should render in.
///
/// An era is the product of three inputs — operating system, OS *version*, and
/// form factor — rather than the OS alone. This is the distinction that makes
/// `native_adaptive_ui` different from platform-only adaptive packages: an
/// iPhone on iOS 26 and an iPhone on iOS 18 are two different design targets,
/// not one.
enum DesignEra {
  /// iPhone running iOS 26 or newer — Apple's Liquid Glass material,
  /// concentric corner radii, floating tab bars, glass-backed navigation.
  iosLiquidGlass,

  /// iPhone running iOS 13–18 — classic flat Cupertino.
  iosClassic,

  /// iPad running iPadOS 26 or newer — Liquid Glass plus iPad layout idioms
  /// (sidebar-first navigation, popovers instead of sheets, split view).
  ipadLiquidGlass,

  /// iPad running iPadOS 13–18 — classic Cupertino with iPad idioms.
  ipadClassic,

  /// Android 16 (API 36) or newer — Material 3 Expressive: springy motion,
  /// shape morphing, expanded tonal palette.
  materialExpressive,

  /// Android 12–15 (API 31–35) — Material 3 with dynamic color.
  material3,

  /// Android 11 (API 30) or older — Material 3 geometry without dynamic color,
  /// since the wallpaper-derived palette is unavailable.
  material3Legacy,

  /// macOS 26 "Tahoe" or newer — Liquid Glass on desktop, with desktop
  /// densities and pointer affordances.
  macosTahoe,

  /// macOS 12–15 — classic Aqua-derived desktop chrome.
  macosClassic,

  /// Anything this package does not model (web, Windows, Linux, tests).
  /// Renders Material 3 so nothing ever crashes or blanks.
  fallback;

  /// True for every Apple design era.
  bool get isApple => const {
        DesignEra.iosLiquidGlass,
        DesignEra.iosClassic,
        DesignEra.ipadLiquidGlass,
        DesignEra.ipadClassic,
        DesignEra.macosTahoe,
        DesignEra.macosClassic,
      }.contains(this);

  /// True when the era draws from the Material design system.
  bool get isMaterial => !isApple;

  /// True when the era's chrome uses Apple's Liquid Glass material
  /// (iOS 26, iPadOS 26, macOS Tahoe).
  bool get hasLiquidGlass => const {
        DesignEra.iosLiquidGlass,
        DesignEra.ipadLiquidGlass,
        DesignEra.macosTahoe,
      }.contains(this);

  /// True when the era supports Material 3 Expressive motion and shape morphing.
  bool get isExpressive => this == DesignEra.materialExpressive;

  /// True when wallpaper-derived dynamic color is available.
  bool get hasDynamicColor => const {
        DesignEra.materialExpressive,
        DesignEra.material3,
      }.contains(this);

  /// True for eras that should prefer sidebar/split-view navigation over
  /// bottom tab bars, and popovers over full-width sheets.
  bool get prefersSidebarNavigation => const {
        DesignEra.ipadLiquidGlass,
        DesignEra.ipadClassic,
        DesignEra.macosTahoe,
        DesignEra.macosClassic,
      }.contains(this);

  /// True when a pointer (mouse/trackpad) is the primary input, which implies
  /// tighter densities, hover states and smaller hit targets.
  bool get isPointerFirst => const {
        DesignEra.macosTahoe,
        DesignEra.macosClassic,
      }.contains(this);

  /// The era to fall back to when a native component is unavailable.
  ///
  /// Falling back *within the same family* keeps an app visually coherent: an
  /// iOS 26 device that cannot host a native control still gets Cupertino, not
  /// Material.
  DesignEra get fallbackEra => switch (this) {
        DesignEra.iosLiquidGlass => DesignEra.iosClassic,
        DesignEra.ipadLiquidGlass => DesignEra.ipadClassic,
        DesignEra.macosTahoe => DesignEra.macosClassic,
        DesignEra.materialExpressive => DesignEra.material3,
        DesignEra.material3 => DesignEra.material3Legacy,
        _ => this,
      };
}

/// Physical form factor, resolved from the shortest screen dimension and the
/// host OS rather than from `Platform` alone.
enum FormFactor {
  /// Handset-sized. Bottom tabs, full-width sheets, single column.
  phone,

  /// Tablet-sized. Sidebars, popovers, two-column split views.
  tablet,

  /// Desktop. Pointer-first densities, menu bars, resizable windows.
  desktop;

  bool get isCompact => this == FormFactor.phone;
  bool get isExpanded => this != FormFactor.phone;
}
