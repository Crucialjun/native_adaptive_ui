import Cocoa
import FlutterMacOS

/// Reports the macOS version so the Dart side can tell Tahoe (26) apart from
/// earlier releases.
///
/// No platform views are registered on macOS yet. AppKit's glass materials are
/// reachable through `NSVisualEffectView`, but embedding one per control in a
/// resizable window costs more than the Dart approximation is currently worth;
/// the capability list is the single place to change that decision.
public class NativeAdaptiveUiPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.gauravraj/native_adaptive_ui",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(NativeAdaptiveUiPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "describePlatform":
      let version = ProcessInfo.processInfo.operatingSystemVersion
      result([
        "osName": "macos",
        "majorVersion": version.majorVersion,
        "minorVersion": version.minorVersion,
        "formFactor": "desktop",
        "isSimulator": false,
      ])
    case "availableComponents":
      result([String]())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
