import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A primary/secondary two-pane layout, in the host platform's idiom.
///
/// HIG's split-views page: "Prefer using a split view in a **regular** — not
/// a compact — environment," naming iPhone portrait as the bad case. On a
/// regular window [primary] and [secondary] sit side by side, divided by a
/// hairline that is a literal **1 point** on macOS — the split-views page's
/// one published number — and the era's own separator thickness elsewhere.
///
/// On a compact window only [primary] is shown; [secondary] is not pushed
/// automatically, because this widget has no way to know which selection
/// inside [primary] should trigger that. Push it yourself with
/// `pushAdaptive` from wherever that selection happens:
///
/// ```dart
/// AdaptiveSplitView(
///   primary: ListView(children: [
///     for (final item in items)
///       AdaptiveListTile(
///         title: item.name,
///         onTap: () {
///           if (context.adaptive.formFactor.isCompact) {
///             pushAdaptive(context, (_) => DetailScreen(item));
///           } else {
///             onSelected(item); // updates `secondary` in the parent instead
///           }
///         },
///       ),
///   ]),
///   secondary: DetailScreen(selected),
/// )
/// ```
class AdaptiveSplitView extends StatelessWidget {
  const AdaptiveSplitView({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryWidth = 320,
  });

  final Widget primary;
  final Widget secondary;

  /// Width of the fixed [primary] pane on regular windows. [secondary] fills
  /// the remaining space, matching how `AdaptiveNavigationScaffold`'s sidebar
  /// layout sizes its own list pane.
  final double primaryWidth;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;
    final config = context.adaptive;

    if (config.formFactor.isCompact) return primary;

    final divider = Container(
      // "Prefer the thin divider style. The thin divider measures one point
      // in width" — macOS's own published number; every other era falls
      // back to the era's ordinary hairline thickness.
      width: era.isPointerFirst ? 1.0 : tokens.separatorThickness,
      color: era.isApple
          ? CupertinoColors.separator.resolveFrom(context)
          : Theme.of(context).dividerColor,
    );

    return Row(
      children: [
        SizedBox(width: primaryWidth, child: primary),
        divider,
        Expanded(child: secondary),
      ],
    );
  }
}
