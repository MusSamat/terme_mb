import 'package:flutter/services.dart';

/// Phone: E.164 with a +996 (Kyrgyzstan) default. +996 numbers must be exactly
/// 9 national digits; any other country code follows general E.164 (7–15 total
/// digits). Mirrors the web `lib/phone.ts` and the backend schema.
const String kDefaultDial = '+996';

/// Normalize free text to `+<digits>`. The leading "+" is always kept (never
/// deletable); digits can be cleared down to just "+". +996 caps at 9 national.
String sanitizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final max = digits.startsWith('996') ? 12 : 15;
  final capped = digits.length > max ? digits.substring(0, max) : digits;
  return '+$capped';
}

/// Valid when +996 has exactly 9 national digits, or general E.164 otherwise.
bool isValidPhone(String v) =>
    RegExp(r'^(?:\+996\d{9}|\+(?!996)[1-9]\d{6,14})$').hasMatch(v);

/// Keeps the field a sanitized E.164 string (leading `+`, digits, capped).
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final s = sanitizePhone(newValue.text);
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
