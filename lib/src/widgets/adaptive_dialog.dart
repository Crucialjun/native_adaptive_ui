import 'dart:async';

import '../core/adaptive_config.dart';
import '../core/design_era.dart';
import '../core/native_bridge.dart';
import '../design_systems/design_imports.dart';
import '../effects/liquid_glass.dart';
import '../tokens/adaptive_tokens.dart';

/// Key on the widget a popover should be anchored to.
///
/// A plain `GlobalKey()` satisfies this. The type argument is spelled out only
/// because the package analyses under `strict-raw-types`, where a bare
/// `GlobalKey` is an error.
typedef AnchorKey = GlobalKey<State<StatefulWidget>>;

/// One choice in an adaptive dialog or action sheet.
@immutable
class AdaptiveAction {
  const AdaptiveAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Renders red and, on Apple eras, is grouped away from the safe choice.
  final bool isDestructive;

  /// The action the Return key triggers, emphasised on every era.
  final bool isDefault;
}

/// Shows a modal alert in the host platform's idiom.
///
/// The dialog is dismissed before [AdaptiveAction.onPressed] runs, which is the
/// behaviour every caller expects and the one that is easiest to get wrong:
/// invoking the callback first leaves a route on the stack that the callback
/// may itself try to pop.
///
/// Returns the index of the chosen action, or null if dismissed.
Future<int?> showAdaptiveAlert(
  BuildContext context, {
  required String title,
  String? message,
  required List<AdaptiveAction> actions,
  bool barrierDismissible = true,
}) {
  final era = AdaptiveScope.of(context).era;

  assert(
    actions.length <= 3,
    'An alert takes at most three buttons; Apple\'s guidance is a limit, not a '
    'suggestion. Use an action sheet for a longer list of choices.',
  );

  // A real UIAlertController on glass eras, for the same reason as the action
  // sheet: Apple's Materials page names alerts as regular-glass surfaces, and
  // CupertinoAlertDialog draws the iOS 13 alert.
  //
  // `barrierDismissible` is deliberately not forwarded. A UIKit alert is modal
  // and cannot be dismissed by tapping outside it, so there is nothing to map it
  // onto — and faking one by adding a hidden cancel action would change which
  // buttons the alert reports.
  if (era.isApple &&
      AdaptiveTokens.of(era).hasGlass &&
      AdaptiveScope.of(context).strategyFor(NativeComponents.alert).isNative) {
    return NativeBridge.presentAlert(
      actionSheet: false,
      title: title,
      message: message,
      actions: [
        for (final action in actions)
          <String, Object?>{
            'label': action.label,
            'isDestructive': action.isDestructive,
            'isDefault': action.isDefault,
          },
      ],
    ).then((outcome) {
      if (outcome.presented) return _dispatch(outcome.index, actions);
      if (!context.mounted) return null;
      return _showDartAlert(
        context,
        era: era,
        title: title,
        message: message,
        actions: actions,
        barrierDismissible: barrierDismissible,
      );
    });
  }

  return _showDartAlert(
    context,
    era: era,
    title: title,
    message: message,
    actions: actions,
    barrierDismissible: barrierDismissible,
  );
}

/// The Dart alert: Cupertino on Apple eras, Material elsewhere.
Future<int?> _showDartAlert(
  BuildContext context, {
  required DesignEra era,
  required String title,
  String? message,
  required List<AdaptiveAction> actions,
  required bool barrierDismissible,
}) {
  if (era.isApple) {
    return showCupertinoDialog<int>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          for (final (index, action) in actions.indexed)
            CupertinoDialogAction(
              isDestructiveAction: action.isDestructive,
              isDefaultAction: action.isDefault,
              onPressed: () => Navigator.of(dialogContext).pop(index),
              child: Text(action.label),
            ),
        ],
      ),
    ).then((index) => _dispatch(index, actions));
  }

  return showDialog<int>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          for (final (index, action) in actions.indexed)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(index),
              style: action.isDestructive
                  ? TextButton.styleFrom(foregroundColor: scheme.error)
                  : null,
              child: Text(action.label),
            ),
        ],
      );
    },
  ).then((index) => _dispatch(index, actions));
}

/// Shows a list of choices anchored the way the platform expects.
///
/// On iPhone and Android this is a sheet from the bottom. On iPad and macOS it
/// is a popover anchored to [anchor] — a full-width sheet on a 13-inch iPad is
/// the clearest sign an app was designed for phones and shipped to tablets.
Future<int?> showAdaptiveActionSheet(
  BuildContext context, {
  String? title,
  String? message,
  required List<AdaptiveAction> actions,
  String? cancelLabel,
  AnchorKey? anchor,
}) async {
  // Apple puts destructive choices at the top of an action sheet and Cancel at
  // the bottom. Callers pass actions in whatever order reads well in their
  // code; the ordering rule belongs here, once, rather than in every call site.
  actions = [
    ...actions.where((action) => action.isDestructive),
    ...actions.where((action) => !action.isDestructive),
  ];
  final config = AdaptiveScope.of(context);
  final era = config.era;

  // A real UIAlertController on glass eras. CupertinoActionSheet is a faithful
  // copy of the iOS 13 sheet and still draws it on iOS 26, where the system
  // presents action sheets on Liquid Glass — and Apple's Materials page names
  // them as regular-glass surfaces. Because this is a presented view controller
  // rather than a platform view, UIKit owns the whole surface and blurs the
  // Flutter content beneath it, which no embedded glass view can do.
  //
  // UIKit also handles the popover-versus-sheet decision itself, from the
  // window's own trait collection — so an iPad in Slide Over gets the sheet
  // without this code having to reason about it.
  if (era.isApple &&
      AdaptiveTokens.of(era).hasGlass &&
      config.strategyFor(NativeComponents.actionSheet).isNative) {
    final outcome = await NativeBridge.presentAlert(
      actionSheet: true,
      title: title,
      message: message,
      actions: [
        for (final action in actions)
          <String, Object?>{
            'label': action.label,
            'isDestructive': action.isDestructive,
            'isDefault': action.isDefault,
          },
      ],
      cancelLabel: cancelLabel,
      anchorRect: _anchorRect(anchor),
    );
    if (outcome.presented) return _dispatch(outcome.index, actions);
    // Fell through: the host had nothing to present from. Carry on to Dart, if
    // the caller's element is still around to present from.
    if (!context.mounted) return null;
  }

  // Apple's rule is about the *window*, not the device: "Avoid displaying
  // popovers in compact views… for compact views, use all available screen
  // space by presenting information in a full-screen modal view like a sheet
  // instead." An iPad in Slide Over is a compact view and gets the sheet.
  if (era.isApple && config.formFactor.isExpanded && anchor != null) {
    final index = await _showPopover(context, anchor, actions);
    return _dispatch(index, actions);
  }

  if (era.isApple) {
    final index = await showCupertinoModalPopup<int>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final (i, action) in actions.indexed)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              isDefaultAction: action.isDefault,
              onPressed: () => Navigator.of(sheetContext).pop(i),
              child: Text(action.label),
            ),
        ],
        cancelButton: cancelLabel == null
            ? null
            : CupertinoActionSheetAction(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(cancelLabel),
              ),
      ),
    );
    return _dispatch(index, actions);
  }

  final index = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  message,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
              ),
            for (final (i, action) in actions.indexed)
              ListTile(
                title: Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
          ],
        ),
      );
    },
  );
  return _dispatch(index, actions);
}

/// The anchor's frame in logical pixels, which are UIKit points — so the rect
/// crosses the platform boundary without conversion.
///
/// Returns null when there is no anchor or it is not laid out, in which case the
/// host centres the popover rather than pointing it at nothing.
Map<String, double>? _anchorRect(AnchorKey? anchor) {
  final box = anchor?.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  return <String, double>{
    'x': origin.dx,
    'y': origin.dy,
    'width': box.size.width,
    'height': box.size.height,
  };
}

Future<int?> _showPopover(
  BuildContext context,
  AnchorKey anchor,
  List<AdaptiveAction> actions,
) {
  final anchorBox = anchor.currentContext?.findRenderObject() as RenderBox?;
  final overlayBox =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (anchorBox == null || overlayBox == null) {
    return Future<int?>.value();
  }

  final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final bottomRight = anchorBox.localToGlobal(
    anchorBox.size.bottomRight(Offset.zero),
    ancestor: overlayBox,
  );

  return showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      topLeft.dx,
      bottomRight.dy,
      overlayBox.size.width - bottomRight.dx,
      overlayBox.size.height - bottomRight.dy,
    ),
    items: [
      for (final (i, action) in actions.indexed)
        PopupMenuItem<int>(value: i, child: Text(action.label)),
    ],
  );
}

/// Runs the chosen action's callback after the route has been popped.
int? _dispatch(int? index, List<AdaptiveAction> actions) {
  if (index == null || index < 0 || index >= actions.length) return null;
  actions[index].onPressed?.call();
  return index;
}

/// Tracks whether a popover from [showAdaptivePopover] is currently open.
///
/// HIG's popovers page: "Never show a cascade or hierarchy of popovers" — one
/// at a time, package-wide.
final ValueNotifier<bool> _popoverOpen = ValueNotifier<bool>(false);

/// Shows arbitrary content anchored to [anchor], the way the platform expects
/// a popover to behave.
///
/// This is the general-purpose counterpart to the popover
/// [showAdaptiveActionSheet] already shows for an action list — use this one
/// for any other content.
///
/// HIG's popovers page: "Avoid displaying popovers in compact views... use a
/// full-screen modal view like a sheet instead" — a **size-class** rule, not
/// a device one, so this reuses the same `formFactor.isExpanded` gate
/// [showAdaptiveActionSheet] already applies, and is the default here too.
/// "Never show a cascade or hierarchy of popovers" — a second call while one
/// is open is a no-op.
///
/// Set [preferSheetOnCompact] to false to show the real anchored popover on a
/// compact window as well, when an app has a specific reason to want that
/// over HIG's own recommendation.
Future<T?> showAdaptivePopover<T>(
  BuildContext context, {
  required AnchorKey anchor,
  required WidgetBuilder builder,
  double width = 280,
  bool preferSheetOnCompact = true,
}) {
  final config = AdaptiveScope.of(context);

  if (preferSheetOnCompact && !config.formFactor.isExpanded) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: builder,
    );
  }

  if (_popoverOpen.value) return Future<T?>.value();

  final anchorBox = anchor.currentContext?.findRenderObject() as RenderBox?;
  final overlay = Navigator.of(context).overlay;
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  if (anchorBox == null || overlay == null || overlayBox == null) {
    return Future<T?>.value();
  }

  _popoverOpen.value = true;
  final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorRect = topLeft & anchorBox.size;
  final tokens = AdaptiveTokens.of(config.era);

  final completer = Completer<T?>();
  late final OverlayEntry entry;
  void dismiss([T? result]) {
    if (!_popoverOpen.value) return;
    entry.remove();
    _popoverOpen.value = false;
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (overlayContext) => _PopoverOverlay<T>(
      anchorRect: anchorRect,
      overlaySize: overlayBox.size,
      tokens: tokens,
      width: width,
      onDismiss: dismiss,
      builder: builder,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// The popover surface itself: a barrier that dismisses on tap, an arrow
/// pointing at [anchorRect], and [builder]'s content in a glass card on
/// glass eras.
class _PopoverOverlay<T> extends StatelessWidget {
  const _PopoverOverlay({
    required this.anchorRect,
    required this.overlaySize,
    required this.tokens,
    required this.width,
    required this.onDismiss,
    required this.builder,
  });

  final Rect anchorRect;
  final Size overlaySize;
  final AdaptiveTokens tokens;
  final double width;
  final void Function([T? result]) onDismiss;
  final WidgetBuilder builder;

  static const double _arrowHeight = 10;
  static const double _arrowWidth = 20;
  static const double _margin = 8;

  @override
  Widget build(BuildContext context) {
    final left = (anchorRect.center.dx - width / 2)
        .clamp(_margin, overlaySize.width - width - _margin);
    final top = anchorRect.bottom + 6;
    final arrowDx = (anchorRect.center.dx - left).clamp(16.0, width - 16.0);

    final isDark =
        (MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light) ==
            Brightness.dark;
    final fallbackColor = tokens.era.isApple
        ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final arrowColor = tokens.hasGlass
        ? (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFFFFFFF))
            .withValues(alpha: isDark ? 0.85 : 0.95)
        : fallbackColor;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onDismiss(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(_arrowWidth, _arrowHeight),
                painter: _PopoverArrowPainter(dx: arrowDx, color: arrowColor),
              ),
              ConditionalGlass(
                tokens: tokens,
                borderRadius: tokens.radius(),
                fallbackColor: fallbackColor,
                padding: EdgeInsets.all(tokens.spacing * 1.5),
                child: Builder(builder: builder),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopoverArrowPainter extends CustomPainter {
  const _PopoverArrowPainter({required this.dx, required this.color});

  final double dx;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(dx - size.width / 2, size.height)
      ..lineTo(dx, 0)
      ..lineTo(dx + size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PopoverArrowPainter oldDelegate) =>
      oldDelegate.dx != dx || oldDelegate.color != color;
}
