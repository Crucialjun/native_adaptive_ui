import '../core/design_era.dart';
import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A search field in the host platform's idiom.
///
/// HIG's search page: iOS has exactly three valid placements — a dedicated
/// `AdaptiveDestination` at the trailing end of a tab bar, an
/// [AdaptiveSearchToolbarButton] in `AdaptiveScaffold.actions` for the
/// toolbar-top placement ("a button that animates into a field above the
/// keyboard"), or this field inline with content. iPadOS and macOS share one
/// rule set — trailing side of the toolbar, top of a sidebar for filtering,
/// or a dedicated item for discovery — the same three building blocks apply
/// there too. None of that is enforced structurally; it is where these two
/// widgets are meant to be used.
class AdaptiveSearchField extends StatelessWidget {
  const AdaptiveSearchField({
    super.key,
    this.controller,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    bool? autofocus,
    this.enabled = true,
  }) : _autofocusOverride = autofocus;

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool? _autofocusOverride;

  /// HIG's search page: don't auto-focus a dedicated search field "on iPad
  /// when only a virtual keyboard is available, in which case it's better to
  /// leave the field unfocused to prevent the keyboard from unexpectedly
  /// covering the view." Flutter cannot detect whether a hardware keyboard is
  /// attached, so this defaults to *not* auto-focusing on the iPad idiom —
  /// the safer default — rather than guessing. Pass `autofocus: true`
  /// explicitly to override.
  bool _resolveAutofocus(BuildContext context) {
    final override = _autofocusOverride;
    if (override != null) return override;
    final config = context.adaptive;
    final isIPad = config.era.isApple &&
        config.platform.deviceFormFactor == FormFactor.tablet;
    return !isIPad;
  }

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final autofocus = _resolveAutofocus(context);

    if (era.isApple) {
      return CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        enabled: enabled,
      );
    }

    return SearchBar(
      controller: controller,
      hintText: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autoFocus: autofocus,
      enabled: enabled,
      leading: const Icon(Icons.search),
    );
  }
}

/// A toolbar-top search placement: an icon button that expands in place into
/// an [AdaptiveSearchField], matching HIG's "a button that animates into a
/// field above the keyboard."
class AdaptiveSearchToolbarButton extends StatefulWidget {
  const AdaptiveSearchToolbarButton({
    super.key,
    this.onChanged,
    this.onSubmitted,
    this.placeholder = 'Search',
    this.expandedWidth = 220,
  });

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final double expandedWidth;

  @override
  State<AdaptiveSearchToolbarButton> createState() =>
      _AdaptiveSearchToolbarButtonState();
}

class _AdaptiveSearchToolbarButtonState
    extends State<AdaptiveSearchToolbarButton> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    return AnimatedSize(
      duration: tokens.motionDuration,
      curve: tokens.motionCurve,
      alignment: Alignment.centerRight,
      child: _expanded
          ? SizedBox(
              width: widget.expandedWidth,
              child: AdaptiveSearchField(
                autofocus: true,
                placeholder: widget.placeholder,
                onChanged: widget.onChanged,
                onSubmitted: (value) {
                  widget.onSubmitted?.call(value);
                },
              ),
            )
          : (era.isApple
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(tokens.minTapTarget, tokens.minTapTarget),
                  onPressed: () => setState(() => _expanded = true),
                  child: const Icon(CupertinoIcons.search),
                )
              : IconButton(
                  onPressed: () => setState(() => _expanded = true),
                  icon: const Icon(Icons.search),
                )),
    );
  }
}
