import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A row in an [AdaptiveListSection].
///
/// Apple eras render a Cupertino list tile with a chevron and hairline
/// separator; Material eras render a `ListTile` with a ripple. The trailing
/// chevron is added automatically when [onTap] is set and no [trailing] is
/// given, because a tappable row without an affordance is an Apple HIG
/// violation and a Material one is not.
class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final era = context.era;

    if (era.isApple) {
      return CupertinoListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        leading: leading,
        trailing: trailing ??
            (onTap != null ? const CupertinoListTileChevron() : null),
        onTap: onTap,
      );
    }

    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      leading: leading,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// A grouped list section — a Settings-style block of related rows.
///
/// This is the widget where the two design systems diverge most: Apple insets
/// the group in a rounded card with a small-caps header, Material lays rows
/// edge to edge under a coloured label. Apps that ignore the difference are the
/// ones users describe as "feeling like a website".
class AdaptiveListSection extends StatelessWidget {
  const AdaptiveListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    if (era.isApple) {
      // Flutter styles an inset-grouped header at 20pt bold and leaves the
      // footer at the full 17pt body style. iOS renders both as 13pt secondary
      // label — the quiet grey caption people recognise from Settings — so both
      // are restyled here rather than inherited.
      final caption = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      );

      return CupertinoListSection.insetGrouped(
        header: header == null
            ? null
            : DefaultTextStyle.merge(style: caption, child: Text(header!)),
        footer: footer == null
            ? null
            : DefaultTextStyle.merge(style: caption, child: Text(footer!)),
        // The inset-grouped variant fixes its own margins to Apple's metrics
        // and exposes no `margin` parameter — deliberately, since the inset is
        // part of what makes the variant recognisable. Overriding it is not
        // available and would not be correct.
        children: children,
      );
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.horizontalPadding,
              tokens.spacing * 2,
              tokens.horizontalPadding,
              tokens.spacing,
            ),
            child: Text(
              header!,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ...children,
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.horizontalPadding,
              tokens.spacing,
              tokens.horizontalPadding,
              tokens.spacing * 2,
            ),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
