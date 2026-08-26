import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/colors.dart';
import '../../theme/dimens.dart';

/// Shared classical-auth input fields (phone / password / OTP) used by the
/// login and register screens. Styling matches the design system tokens.

BoxDecoration _fieldBox(bool dark) => BoxDecoration(
      // Subtle fill one step off the surface + a hairline border, so the field
      // reads as an input rather than a heavy muddy block in dark mode.
      color: dark ? InkColors.c800 : InkColors.c50,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
    );

/// Uppercase label above a field — design-system "Card Field" pattern. Keeps
/// entered values distinct from hints so a placeholder never looks pre-filled.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
      ),
      child,
    ]);
  }
}

class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, required this.dark, this.onChanged});

  final TextEditingController controller;
  final bool dark;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 14),
      decoration: _fieldBox(dark),
      child: Row(children: [
        const Text('+996 ', style: TextStyle(fontWeight: FontWeight.w800, color: InkColors.c500)),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            onChanged: (_) => onChanged?.call(),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: dark ? Colors.white : InkColors.c900),
            decoration: const InputDecoration(
              hintText: '000 000 000',
              hintStyle: TextStyle(color: InkColors.c300, fontWeight: FontWeight.w500),
              border: InputBorder.none,
            ),
          ),
        ),
      ]),
    );
  }
}

class TextFieldBox extends StatelessWidget {
  const TextFieldBox({
    super.key,
    required this.controller,
    required this.dark,
    required this.hint,
    this.onChanged,
    this.textCapitalization = TextCapitalization.words,
    this.autofillHints,
    this.keyboardType,
  });

  final TextEditingController controller;
  final bool dark;
  final String hint;
  final VoidCallback? onChanged;
  final TextCapitalization textCapitalization;
  final List<String>? autofillHints;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _fieldBox(dark),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        keyboardType: keyboardType,
        onChanged: (_) => onChanged?.call(),
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: dark ? Colors.white : InkColors.c900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: InkColors.c300, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.dark,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.onChanged,
    this.onSubmit,
  });

  final TextEditingController controller;
  final bool dark;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: _fieldBox(dark),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            onChanged: (_) => onChanged?.call(),
            onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: dark ? Colors.white : InkColors.c900),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: InkColors.c400, fontWeight: FontWeight.w700),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: InkColors.c400),
        ),
      ]),
    );
  }
}

class OtpField extends StatelessWidget {
  const OtpField({super.key, required this.controller, required this.dark, required this.onChanged});

  final TextEditingController controller;
  final bool dark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofocus: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      onChanged: onChanged,
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8, color: dark ? Colors.white : InkColors.c900),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••••',
        hintStyle: const TextStyle(color: InkColors.c300, letterSpacing: 8),
        filled: true,
        fillColor: dark ? InkColors.c800 : InkColors.c50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: const BorderSide(color: BrandColors.c500, width: 2)),
      ),
    );
  }
}
