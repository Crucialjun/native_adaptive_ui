import '../design_systems/design_imports.dart';
import 'adaptive_base.dart';

/// A single-line text input in the host platform's idiom.
///
/// The two design systems disagree about where a field's label lives: Material
/// floats it into the border, Cupertino puts it outside or uses a placeholder.
/// [label] and [placeholder] are therefore separate parameters, and each era
/// uses whichever it actually has an idiom for instead of forcing both.
class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.prefix,
    this.suffix,
    this.showClearButton = false,
  });

  /// A field for sensitive entry — HIG's text-fields page: "Always use a
  /// secure field... for sensitive information." `obscureText` is fixed to
  /// true so the intent is named rather than left to a caller-passed bool.
  const AdaptiveTextField.secure({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.prefix,
    this.suffix,
  })  : obscureText = true,
        showClearButton = false;

  final TextEditingController? controller;

  /// Field name. Floats into the border on Material; rendered above the field
  /// on Apple eras, matching Settings-style forms.
  final String? label;

  /// Hint shown while the field is empty.
  final String? placeholder;

  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final Widget? prefix;
  final Widget? suffix;

  /// Shows a trailing clear button while the field has text. HIG's
  /// text-fields page: "the trailing end usually contains a clear button."
  /// Ignored when [suffix] is also supplied — the caller owns that slot.
  final bool showClearButton;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    if (!era.isApple) {
      return TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          prefixIcon: prefix,
          suffixIcon: suffix ??
              (showClearButton && controller != null
                  ? _MaterialClearButton(controller: controller!)
                  : null),
          border: OutlineInputBorder(borderRadius: tokens.radius()),
        ),
      );
    }

    final field = CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      prefix: prefix,
      suffix: suffix,
      clearButtonMode: suffix == null && showClearButton
          ? OverlayVisibilityMode.editing
          : OverlayVisibilityMode.never,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.horizontalPadding * 0.75,
        vertical: tokens.verticalPadding,
      ),
      decoration: BoxDecoration(
        borderRadius: tokens.radius(),
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      ),
    );

    final labelText = label;
    if (labelText == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labelText,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        SizedBox(height: tokens.spacing * 0.5),
        field,
      ],
    );
  }
}

/// The Material half of [AdaptiveTextField.showClearButton].
///
/// Cupertino's `clearButtonMode` already tracks the controller itself;
/// Material's `InputDecoration.suffixIcon` does not, so this listens directly
/// rather than relying on the field to rebuild on every keystroke.
class _MaterialClearButton extends StatelessWidget {
  const _MaterialClearButton({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.text.isEmpty
          ? const SizedBox.shrink()
          : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: controller.clear,
            ),
    );
  }
}
