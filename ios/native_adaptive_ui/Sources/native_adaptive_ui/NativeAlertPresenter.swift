import Flutter
import UIKit

// Real `UIAlertController` alerts and action sheets.
//
// `CupertinoAlertDialog` and `CupertinoActionSheet` are Dart reimplementations of
// the iOS 13 controls, and they still draw the iOS 13 controls on iOS 26 — where
// the system presents both on Liquid Glass. Apple's Materials page names alerts
// and action sheets as regular-glass surfaces, so the material is the system's to
// draw, not ours to approximate.
//
// Unlike the embedded controls in NativeComponentFactories, these are *presented*
// view controllers rather than platform views, so there is no Metal-layer
// backdrop problem to work around: UIKit presents over the whole Flutter surface
// and blurs it as it would any other content.

enum NativeAlertStyle {
  case alert
  case actionSheet
}

/// Presents one alert or action sheet and reports the chosen action's index.
///
/// The instance retains itself for the lifetime of the presentation, because the
/// only other reference UIKit keeps is a weak delegate pointer — and dropping it
/// early means an outside tap on an iPad popover never reports back, leaving the
/// awaiting Dart future to hang forever.
class NativeAlertPresenter: NSObject, UIPopoverPresentationControllerDelegate {
  private static var active = Set<NativeAlertPresenter>()

  private var reply: ((Int?) -> Void)?

  /// Presents the controller. Returns false when there is no view controller to
  /// present from, so the caller can fall back to the Dart implementation rather
  /// than silently doing nothing.
  @discardableResult
  func present(
    style: NativeAlertStyle,
    args: [String: Any],
    reply: @escaping (Int?) -> Void
  ) -> Bool {
    guard let host = Self.topViewController() else { return false }

    self.reply = reply

    let controller = UIAlertController(
      title: args["title"] as? String,
      message: args["message"] as? String,
      preferredStyle: style == .alert ? .alert : .actionSheet
    )

    let specs = args["actions"] as? [[String: Any]] ?? []
    var preferred: UIAlertAction?

    for (index, spec) in specs.enumerated() {
      let isDestructive = spec["isDestructive"] as? Bool ?? false
      let action = UIAlertAction(
        title: spec["label"] as? String ?? "",
        style: isDestructive ? .destructive : .default
      ) { [weak self] _ in
        self?.finish(index)
      }
      controller.addAction(action)
      if spec["isDefault"] as? Bool ?? false {
        preferred = action
      }
    }

    // UIKit always places a `.cancel` action last in an action sheet and fires it
    // when the sheet is dismissed by tapping away, which is exactly Apple's
    // ordering rule — so it is added last rather than ordered by hand.
    if let cancelLabel = args["cancelLabel"] as? String {
      controller.addAction(
        UIAlertAction(title: cancelLabel, style: .cancel) { [weak self] _ in
          self?.finish(nil)
        }
      )
    }

    if let preferred {
      controller.preferredAction = preferred
    }

    // An action sheet in a regular-width window is presented as a popover, and
    // UIKit raises an exception if the popover has nothing to point at. Flutter's
    // logical pixels are UIKit points, so the anchor rect crosses the boundary
    // unconverted.
    if let popover = controller.popoverPresentationController {
      popover.delegate = self
      popover.sourceView = host.view
      if let rect = args["anchorRect"] as? [String: Any],
        let x = rect["x"] as? Double,
        let y = rect["y"] as? Double,
        let width = rect["width"] as? Double,
        let height = rect["height"] as? Double
      {
        popover.sourceRect = CGRect(x: x, y: y, width: width, height: height)
      } else {
        // No anchor: point at the middle of the screen with no arrow. Not ideal
        // placement, but a presentable sheet beats an exception.
        popover.sourceRect = CGRect(
          x: host.view.bounds.midX,
          y: host.view.bounds.midY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }
    }

    Self.active.insert(self)
    host.present(controller, animated: true)
    return true
  }

  /// Reports the outcome exactly once and releases the self-reference.
  private func finish(_ index: Int?) {
    guard let reply else { return }
    self.reply = nil
    reply(index)
    Self.active.remove(self)
  }

  /// Fires when an iPad popover is dismissed by tapping outside it. Without this
  /// the Dart future would never complete.
  func popoverPresentationControllerDidDismissPopover(
    _ popoverPresentationController: UIPopoverPresentationController
  ) {
    finish(nil)
  }

  /// The controller currently on screen, so the alert is presented above any
  /// route Flutter has already pushed rather than behind it.
  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let window =
      scenes.flatMap(\.windows).first { $0.isKeyWindow }
      ?? scenes.first?.windows.first

    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
