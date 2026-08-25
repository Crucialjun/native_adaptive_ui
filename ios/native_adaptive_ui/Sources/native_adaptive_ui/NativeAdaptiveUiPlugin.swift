import Flutter
import UIKit

/// Answers two questions for the Dart side: what OS is this, and which native
/// components can it actually host.
///
/// The second question is deliberately not inferred from the first. A device
/// running iOS 26 only advertises a component once a factory for it is actually
/// registered below — that is what lets the Dart side fall back cleanly instead
/// of shipping a half-working platform view. Adding an id to
/// `availableComponents` without registering its factory is how a user ends up
/// looking at a blank rectangle.
public class NativeAdaptiveUiPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.gauravraj/native_adaptive_ui",
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeAdaptiveUiPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // System controls, every iOS version. They pick up whatever appearance the
    // running OS gives them, including iOS 26's transient glass while being
    // dragged — which is exactly why embedding them is worth the cost.
    registrar.register(
      NativeSwitchFactory(messenger: registrar.messenger()),
      withId: "dev.gauravraj/switch"
    )
    registrar.register(
      NativeSliderFactory(messenger: registrar.messenger()),
      withId: "dev.gauravraj/slider"
    )
    registrar.register(
      NativeSegmentedControlFactory(messenger: registrar.messenger()),
      withId: "dev.gauravraj/segmented_control"
    )

    // Liquid Glass, iOS 26 and later only.
    if #available(iOS 26.0, *) {
      registrar.register(
        GlassSurfaceFactory(),
        withId: "dev.gauravraj/glass_surface"
      )
      registrar.register(
        GlassButtonFactory(messenger: registrar.messenger()),
        withId: "dev.gauravraj/glass_button"
      )
      registrar.register(
        NativeTabBarFactory(messenger: registrar.messenger()),
        withId: "dev.gauravraj/tab_bar"
      )
      registrar.register(
        NativeNavigationBarFactory(messenger: registrar.messenger()),
        withId: "dev.gauravraj/navigation_bar"
      )
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "describePlatform":
      result(describePlatform())
    case "availableComponents":
      result(availableComponents())
    case "presentAlert":
      present(style: .alert, call: call, result: result)
    case "presentActionSheet":
      present(style: .actionSheet, call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Presents a real `UIAlertController` and returns the chosen action's index,
  /// or nil when it was dismissed without a choice.
  ///
  /// Returning `FlutterMethodNotImplemented` when there is nothing to present
  /// from is deliberate: the Dart side treats it exactly like a host that never
  /// advertised the component and renders its own dialog instead.
  private func present(
    style: NativeAlertStyle,
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any] ?? [:]
    let presented = NativeAlertPresenter().present(style: style, args: args) {
      index in
      result(index)
    }
    if !presented {
      result(FlutterMethodNotImplemented)
    }
  }

  private func describePlatform() -> [String: Any] {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let idiom = UIDevice.current.userInterfaceIdiom

    let formFactor: String
    switch idiom {
    case .pad: formFactor = "tablet"
    case .mac: formFactor = "desktop"
    default: formFactor = "phone"
    }

    return [
      "osName": "ios",
      "majorVersion": version.majorVersion,
      "minorVersion": version.minorVersion,
      "formFactor": formFactor,
      "isSimulator": isSimulator(),
    ]
  }

  /// Must stay in step with the factories registered above.
  private func availableComponents() -> [String] {
    // Alerts and action sheets are presented view controllers rather than
    // platform views, so they carry no Metal-layer caveat and are available on
    // every iOS version the plugin supports.
    var components = ["switch", "slider", "segmented_control", "alert", "action_sheet"]
    if #available(iOS 26.0, *) {
      components.append(
        contentsOf: ["glass_surface", "glass_button", "tab_bar", "navigation_bar"]
      )
    }
    return components
  }

  private func isSimulator() -> Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }
}
