import Flutter
import UIKit

// Platform views that put real UIKit controls and real Liquid Glass into the
// Flutter scene.
//
// The Dart side can approximate a lot, but not this: `UIGlassEffect` samples,
// blurs and refracts whatever is actually behind it, frame by frame. A
// BackdropFilter can blur, and it can tint, but it cannot know what the system
// knows about the content underneath. On a moving background the difference is
// obvious, which is the whole reason these views exist.
//
// Every factory here is registered only when its API is available, and the
// plugin advertises a component id only when the matching factory is
// registered. See `availableComponents` in NativeAdaptiveUiPlugin.

// MARK: - Glass surface

/// A `UIVisualEffectView` carrying `UIGlassEffect`, used as an interactive
/// overlay on top of a Dart `BackdropFilter`.
///
/// Flutter renders its scene to a `CAMetalLayer`. `UIVisualEffectView` cannot
/// capture or blur Metal-layer content — its snapshot mechanism only sees UIKit
/// views. So the blur is handled by a Dart `BackdropFilter` underneath, and this
/// native view provides what Dart cannot: the real `UIGlassEffect` material with
/// `isInteractive` — the liquid animation that plays on touch, with refraction
/// and the specular highlights that make it read as Apple's material.
@available(iOS 26.0, *)
class GlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return GlassSurfaceView(frame: frame, args: args as? [String: Any] ?? [:])
  }
}

@available(iOS 26.0, *)
class GlassSurfaceView: NSObject, FlutterPlatformView {
  private let effectView: UIVisualEffectView

  init(frame: CGRect, args: [String: Any]) {
    let style: UIGlassEffect.Style =
      (args["style"] as? String) == "clear" ? .clear : .regular

    let effect = UIGlassEffect(style: style)
    effect.isInteractive = args["interactive"] as? Bool ?? false
    if let tint = args["tint"] as? NSNumber {
      effect.tintColor = UIColor(argb: tint.uint32Value)
    }

    effectView = UIVisualEffectView(effect: effect)
    effectView.frame = frame
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    effectView.alpha = 1
    effectView.backgroundColor = .clear

    if let radius = args["cornerRadius"] as? Double, radius > 0 {
      effectView.layer.cornerRadius = CGFloat(radius)
      effectView.layer.cornerCurve = .continuous
      effectView.clipsToBounds = true
    }

    super.init()
  }

  func view() -> UIView { effectView }
}

// MARK: - Tab bar

/// A real `UITabBar`.
///
/// This is the only way to get Apple's iOS 26 tab bar behaviour rather than an
/// imitation of it. `UIVisualEffectView` cannot help here: it samples its
/// backdrop from the UIKit view hierarchy, and Flutter's content lives in a
/// `CAMetalLayer` that UIKit's backdrop capture cannot read — so a glass surface
/// laid over Flutter content has nothing to sample and stays inert.
///
/// A genuine `UITabBar` sidesteps the problem entirely. The system owns the
/// material, the selection morph, and the interactive "liquid" response to touch
/// and hold, exactly as it does in a UIKit app. Same reasoning that puts a real
/// `UISwitch` and `UISlider` in this plugin: the system does it, we cannot.
///
/// Icons must be SF Symbol names — a `UITabBarItem` needs a `UIImage`, and
/// Flutter widgets cannot cross that boundary. The Dart side only selects this
/// view when every destination supplies one, and falls back to its own capsule
/// otherwise.
@available(iOS 26.0, *)
class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return NativeTabBarView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

@available(iOS 26.0, *)
class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let tabBar = UITabBar()
  private let channel: FlutterMethodChannel

  /// Set while `selectedItem` is being changed from Dart, so the resulting
  /// delegate callback is not echoed back as a user selection.
  private var isApplyingSelection = false

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "dev.gauravraj/tab_bar/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    tabBar.frame = frame
    tabBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tabBar.delegate = self

    // Spread items evenly. The default is `.automatic`, which centres them in a
    // narrow group on regular-width devices and reads as an iPad bar on iPhone.
    tabBar.itemPositioning = .fill

    // Deliberately no appearance configuration. On iOS 26 the default background
    // *is* Liquid Glass, and `UITabBarAppearance.configureWithOpaqueBackground()`
    // is what would throw it away. Apple's toolbar guidance says the same thing:
    // "Any custom backgrounds and appearances you use might overlay or interfere
    // with background effects that the system provides."

    applyItems(args)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setSelectedIndex":
        if let index = call.arguments as? Int {
          self.applySelection(index)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { tabBar }

  private func applyItems(_ args: [String: Any]) {
    // AdaptiveNavigationScaffold.selectedColor/unselectedColor. Left at the
    // system default (nil) when absent, so an app that never sets them keeps
    // following its own global accent colour exactly as before this existed.
    if let tint = args["tint"] as? NSNumber {
      tabBar.tintColor = UIColor(argb: tint.uint32Value)
    }
    if let unselectedTint = args["unselectedTint"] as? NSNumber {
      tabBar.unselectedItemTintColor = UIColor(argb: unselectedTint.uint32Value)
    }

    let labels = args["labels"] as? [String] ?? []
    let symbols = args["symbols"] as? [String] ?? []
    let selectedSymbols = args["selectedSymbols"] as? [String] ?? []
    // Custom brand/glyph icons, alongside SF Symbols — AdaptiveDestination's
    // iconImage/selectedIconImage. Sent as raw encoded PNG bytes rather than
    // a Flutter asset path: the app bundle's flutter_assets layout on disk is
    // private-API territory this plugin has no business depending on, and an
    // arbitrary ImageProvider (network, memory) has no asset path at all.
    let iconBytes = args["iconBytes"] as? [FlutterStandardTypedData?] ?? []
    let selectedIconBytes = args["selectedIconBytes"] as? [FlutterStandardTypedData?] ?? []
    // The Dart side resizes every custom icon to a fixed pixel size before
    // sending it and reports the scale that implies, so a decoded icon comes
    // out at the tab bar's own point size regardless of the source asset's
    // own dimensions — without this, `UIImage(data:)` defaults to scale 1 and
    // a designer's 512x512 export fills the whole bar.
    let iconScale = CGFloat((args["iconScale"] as? NSNumber)?.doubleValue ?? 3)
    // AdaptiveDestination.tintNativeIcon — recolours a custom icon to the tab
    // bar's own tint like an SF Symbol, instead of keeping its own baked-in
    // colours. Defaults to false (every index) when the whole app predates
    // this and never sends it.
    let tintIcons = args["tintIcons"] as? [Bool] ?? []
    // Optional per-item badge, mirroring AdaptiveDestination.badge. Sent as
    // `NSNull` for a destination with no badge — StandardMessageCodec has no
    // other way to carry a hole in a String array — so this checks the
    // dynamic type rather than trying `as? String`, which `NSNull` also fails
    // silently.
    let badges = args["badges"] as? [Any?] ?? []

    let items = labels.enumerated().map { index, label -> UITabBarItem in
      let tint = index < tintIcons.count && tintIcons[index]
      let item = UITabBarItem(
        title: label,
        image: tabImage(at: index, bytes: iconBytes, symbols: symbols, scale: iconScale, tint: tint),
        tag: index
      )
      item.selectedImage = tabImage(
        at: index, bytes: selectedIconBytes, symbols: selectedSymbols, scale: iconScale, tint: tint
      )
      if index < badges.count, let badge = badges[index] as? String {
        item.badgeValue = badge
      }
      return item
    }

    tabBar.setItems(items, animated: false)

    let selected = args["selectedIndex"] as? Int ?? 0
    applySelection(selected)
  }

  /// A custom brand icon when the caller supplied bytes for this index,
  /// otherwise the SF Symbol. A custom icon renders `.alwaysOriginal` by
  /// default so its own colour survives, or `.alwaysTemplate` when
  /// [tint] — AdaptiveDestination.tintNativeIcon — asks for it to follow the
  /// tab bar's tint like an SF Symbol does. SF Symbols are always left at
  /// their default template mode, matching every prior release.
  private func tabImage(
    at index: Int,
    bytes: [FlutterStandardTypedData?],
    symbols: [String],
    scale: CGFloat,
    tint: Bool
  ) -> UIImage? {
    if index < bytes.count,
      let data = bytes[index]?.data,
      let image = UIImage(data: data, scale: scale) {
      return image.withRenderingMode(tint ? .alwaysTemplate : .alwaysOriginal)
    }
    if index < symbols.count, !symbols[index].isEmpty {
      return UIImage(systemName: symbols[index])
    }
    return nil
  }

  private func applySelection(_ index: Int) {
    guard let items = tabBar.items, index >= 0, index < items.count else { return }
    isApplyingSelection = true
    tabBar.selectedItem = items[index]
    isApplyingSelection = false
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    guard !isApplyingSelection else { return }
    channel.invokeMethod("selected", arguments: item.tag)
  }
}

// MARK: - Segmented control

/// A real `UISegmentedControl`.
///
/// Same argument as the switch and the slider. `CupertinoSlidingSegmentedControl`
/// is a faithful copy of the iOS 13 control and still draws that way on iOS 26,
/// where the system control instead carries the Liquid Glass selection thumb and
/// animates it between segments. That thumb is the system's, so the control has
/// to be the system's too.
///
/// Not gated to iOS 26 in Swift: a system control renders with whatever
/// appearance the running OS gives it. The Dart side decides when to reach for
/// it, and only does so on glass eras.
class NativeSegmentedControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return NativeSegmentedControlView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

class NativeSegmentedControlView: NSObject, FlutterPlatformView {
  private let control: UISegmentedControl
  private let channel: FlutterMethodChannel

  /// Guards against echoing a selection that Dart itself just pushed down.
  private var isApplyingSelection = false

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    let titles = args["titles"] as? [String] ?? []
    control = UISegmentedControl(items: titles)
    channel = FlutterMethodChannel(
      name: "dev.gauravraj/segmented_control/\(viewId)",
      binaryMessenger: messenger
    )

    control.frame = frame
    control.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    control.isEnabled = args["enabled"] as? Bool ?? true

    let index = args["selectedIndex"] as? Int ?? 0
    if index >= 0 && index < titles.count {
      control.selectedSegmentIndex = index
    }

    super.init()

    control.addTarget(self, action: #selector(handleChange), for: .valueChanged)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setSelectedIndex":
        if let index = call.arguments as? Int,
           index >= 0,
           index < self.control.numberOfSegments {
          self.isApplyingSelection = true
          self.control.selectedSegmentIndex = index
          self.isApplyingSelection = false
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { control }

  @objc private func handleChange() {
    guard !isApplyingSelection else { return }
    channel.invokeMethod("valueChanged", arguments: control.selectedSegmentIndex)
  }
}

// MARK: - Switch

/// A real `UISwitch`.
///
/// Not gated to iOS 26: a system switch picks up whatever appearance the running
/// OS gives it, including the transient glass iOS 26 applies while the control
/// is being dragged — behaviour that cannot be reproduced from Dart because it
/// is driven by the system's own gesture state.
class NativeSwitchFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return NativeSwitchView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

class NativeSwitchView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let toggle = UISwitch()
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "dev.gauravraj/switch/\(viewId)",
      binaryMessenger: messenger
    )

    toggle.isOn = args["value"] as? Bool ?? false
    toggle.isEnabled = args["enabled"] as? Bool ?? true
    toggle.translatesAutoresizingMaskIntoConstraints = false

    container.frame = frame
    container.backgroundColor = .clear

    super.init()

    // A UISwitch has a fixed intrinsic size, so it is centred in the box Flutter
    // gave us rather than stretched into it.
    container.addSubview(toggle)
    NSLayoutConstraint.activate([
      toggle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    toggle.addTarget(self, action: #selector(handleChange), for: .valueChanged)
  }

  func view() -> UIView { container }

  @objc private func handleChange() {
    channel.invokeMethod("valueChanged", arguments: toggle.isOn)
  }
}

// MARK: - Slider

/// A real `UISlider`, for the same reason as the switch: iOS 26 gives the track
/// a glass treatment while it is being dragged.
class NativeSliderFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return NativeSliderView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

class NativeSliderView: NSObject, FlutterPlatformView {
  private let slider: UISlider
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    slider = UISlider(frame: frame)
    channel = FlutterMethodChannel(
      name: "dev.gauravraj/slider/\(viewId)",
      binaryMessenger: messenger
    )

    slider.minimumValue = Float(args["min"] as? Double ?? 0)
    slider.maximumValue = Float(args["max"] as? Double ?? 1)
    slider.value = Float(args["value"] as? Double ?? 0)
    slider.isEnabled = args["enabled"] as? Bool ?? true
    slider.autoresizingMask = [.flexibleWidth]

    super.init()
    slider.addTarget(self, action: #selector(handleChange), for: .valueChanged)
  }

  func view() -> UIView { slider }

  @objc private func handleChange() {
    channel.invokeMethod("valueChanged", arguments: Double(slider.value))
  }
}

// MARK: - Button

/// A Liquid Glass `UIButton`.
///
/// Reserved for buttons in the functional layer — bars and toolbars. Apple's
/// guidance keeps glass out of the content layer, so the Dart side only reaches
/// for this when a button is part of the chrome.
@available(iOS 26.0, *)
class GlassButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return GlassButtonView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

@available(iOS 26.0, *)
class GlassButtonView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let button: UIButton
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "dev.gauravraj/glass_button/\(viewId)",
      binaryMessenger: messenger
    )

    var configuration: UIButton.Configuration
    switch args["style"] as? String {
    case "prominent":
      configuration = .prominentGlass()
    case "destructive":
      configuration = .prominentGlass()
      configuration.baseBackgroundColor = .systemRed
    case "glass":
      configuration = .glass()
    default:
      configuration = .glass()
    }
    configuration.title = args["title"] as? String ?? ""

    button = UIButton(configuration: configuration)
    button.isEnabled = args["enabled"] as? Bool ?? true
    button.translatesAutoresizingMaskIntoConstraints = false

    container.frame = frame
    container.backgroundColor = .clear

    super.init()

    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
  }

  func view() -> UIView { container }

  @objc private func handleTap() {
    channel.invokeMethod("pressed", arguments: nil)
  }
}

// MARK: - Navigation bar

/// A real `UINavigationBar` with a single item — title, plus optional
/// leading/trailing bar buttons built from SF Symbol names.
///
/// Same argument as the tab bar: a `UIBarButtonItem` needs a `UIImage`, and a
/// Flutter widget cannot cross that boundary, so this is used only when the
/// Dart side supplies symbol names (`AdaptiveScaffold.leadingSfSymbol` /
/// `actionSfSymbols`) instead of arbitrary `leading`/`actions` widgets —
/// otherwise `CupertinoNavigationBar` renders exactly as it always has.
/// `UINavigationBar` also owns title and back-button styling, which this
/// keeps out of scope: no back button, no large-title mode, one item only.
@available(iOS 26.0, *)
class NativeNavigationBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return NativeNavigationBarView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

@available(iOS 26.0, *)
class NativeNavigationBarView: NSObject, FlutterPlatformView {
  private let navigationBar = UINavigationBar()
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "dev.gauravraj/navigation_bar/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    navigationBar.frame = frame
    navigationBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // Deliberately no appearance configuration — same reasoning as the tab
    // bar: the default background on iOS 26 already is Liquid Glass, and
    // configureWithOpaqueBackground() is what would throw it away.

    applyItem(args)
  }

  func view() -> UIView { navigationBar }

  private func applyItem(_ args: [String: Any]) {
    let item = UINavigationItem(title: args["title"] as? String ?? "")

    if let leadingSymbol = args["leadingSfSymbol"] as? String,
      let image = UIImage(systemName: leadingSymbol)
    {
      let button = UIBarButtonItem(
        image: image,
        style: .plain,
        target: self,
        action: #selector(handleLeadingTap)
      )
      item.leftBarButtonItem = button
    }

    if let symbols = args["actionSfSymbols"] as? [String] {
      // rightBarButtonItems lays out with items[0] closest to the trailing
      // edge, so the Dart side's leading-to-trailing reading order is
      // reversed here to land in the same visual order.
      item.rightBarButtonItems = symbols.enumerated().reversed()
        .compactMap { index, symbol -> UIBarButtonItem? in
          guard let image = UIImage(systemName: symbol) else { return nil }
          let button = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(handleActionTap(_:))
          )
          button.tag = index
          return button
        }
    }

    navigationBar.setItems([item], animated: false)
  }

  @objc private func handleLeadingTap() {
    channel.invokeMethod("leadingPressed", arguments: nil)
  }

  @objc private func handleActionTap(_ sender: UIBarButtonItem) {
    channel.invokeMethod("actionPressed", arguments: sender.tag)
  }
}

// MARK: - Colour bridging

extension UIColor {
  /// Builds a colour from Flutter's 32-bit ARGB integer.
  fileprivate convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255.0,
      green: CGFloat((argb >> 8) & 0xFF) / 255.0,
      blue: CGFloat(argb & 0xFF) / 255.0,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255.0
    )
  }
}
