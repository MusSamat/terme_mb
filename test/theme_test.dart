import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/theme/app_theme.dart';
import 'package:terme_mb/theme/colors.dart';
import 'package:terme_mb/theme/role_theme.dart';

void main() {
  test('AppColors extension is attached to both themes', () {
    expect(AppTheme.light.extension<AppColors>(), isNotNull);
    expect(AppTheme.dark.extension<AppColors>(), isNotNull);
  });

  test('role themes cover all roles and share one teal recipe', () {
    expect(kRoleThemes.keys.toSet(), UiRole.values.toSet());
    for (final r in UiRole.values) {
      expect(roleThemeFor(r).header, BrandColors.c600);
      expect(roleThemeFor(r).navText(Brightness.light), BrandColors.c700);
    }
    expect(roleThemeFor(UiRole.driver).icon, isNot(roleThemeFor(UiRole.passenger).icon));
  });
}
