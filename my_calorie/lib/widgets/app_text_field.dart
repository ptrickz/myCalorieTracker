import "package:flutter/cupertino.dart";
import "../theme.dart";

/// iOS-style text field matching the app's dark input styling — the drop-in
/// replacement for the Material TextField + InputDecoration combos. Labels
/// become placeholders (iOS fields don't float labels).
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final Widget? suffix;

  const AppTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.onChanged,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofocus: autofocus,
      onChanged: onChanged,
      prefix: prefix == null
          ? null
          : Padding(padding: const EdgeInsets.only(left: 16), child: prefix),
      suffix: suffix == null
          ? null
          : Padding(padding: const EdgeInsets.only(right: 4), child: suffix),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      placeholderStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
      cursorColor: AppColors.accent,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        // A visible outline so a filled field still reads as an input, even
        // when it sits on a same-coloured surface (e.g. a card or dialog).
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
