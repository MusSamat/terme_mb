import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/theme/app_theme.dart';
import 'package:terme_mb/theme/colors.dart';
import 'package:terme_mb/theme/role_theme.dart';

void main() {
  test('AppColors extension is attached to both themes', () {
    expect(AppTheme.light.extension<AppColors>(), isNotNull);
    expect(AppTheme.dark.extension<AppColors>(), isNotNull);
  });

  test('role themes cover all roles and carry canonical accents', () {
    expect(kRoleThemes.keys.toSet(), UiRole.values.toSet());
    expect(roleThemeFor(UiRole.passenger).ctaFilled, BrandColors.c600);
    expect(roleThemeFor(UiRole.driver).ctaFilled, GrapeColors.c600);
    expect(roleThemeFor(UiRole.guest).ctaFilled, InkColors.c700);
  });
}
