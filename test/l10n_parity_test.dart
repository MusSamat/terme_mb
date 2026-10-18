import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _flat(Map<String, dynamic> m, [String p = '']) {
  final out = <String, dynamic>{};
  const plural = {'zero', 'one', 'two', 'few', 'many', 'other'};
  m.forEach((k, v) {
    final key = p.isEmpty ? k : '$p.$k';
    if (v is Map<String, dynamic> && !v.keys.every(plural.contains)) {
      out.addAll(_flat(v, key));
    } else {
      out[key] = v;
    }
  });
  return out;
}

Map<String, dynamic> _load(String l) =>
    _flat(json.decode(File('assets/l10n/$l.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  final ru = _load('ru');
  final kg = _load('kg');

  test('ru and kg have the same keys', () {
    expect(kg.keys.toSet().difference(ru.keys.toSet()), isEmpty);
    expect(ru.keys.toSet().difference(kg.keys.toSet()), isEmpty);
  });

  test('kg plurals cover every form ru defines', () {
    ru.forEach((k, v) {
      if (v is Map) {
        final forms = (kg[k] as Map).keys.toSet();
        expect(forms.containsAll(v.keys), true, reason: '$k is missing ${v.keys.toSet().difference(forms)}');
      }
    });
  });

  test('no placeholder mismatch between ru and kg', () {
    final ph = RegExp(r'\{[a-z_]*\}');
    ru.forEach((k, v) {
      if (v is String) {
        expect(ph.allMatches(kg[k] as String).map((m) => m[0]).toSet(), ph.allMatches(v).map((m) => m[0]).toSet(),
            reason: k);
      }
    });
  });

  test('no auth leftovers (passwords / SMS / Telegram login)', () {
    for (final k in ru.keys) {
      expect(k.contains('password') || k.contains('sms') || k.contains('login_telegram'), false, reason: k);
    }
  });
}
