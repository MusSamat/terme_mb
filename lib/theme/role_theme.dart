import 'package:flutter/material.dart';
import 'colors.dart';

/// Role language. Roles are told apart by [RoleTheme.icon] + [RoleTheme.labelKey]
/// only — every role shares the same teal/neutral colour recipe.
enum UiRole { guest, passenger, driver }

@immutable
class RoleTheme {
  const RoleTheme({
    required this.role,
    required this.labelKey,
    required this.icon,
  });

  final UiRole role;

  /// i18n key under `roles.*`.
  final String labelKey;

  /// lucide icon shown next to the role label.
  final IconData icon;

  /// Flat screen hero header surface.
  Color get header => BrandColors.c600;

  /// Bottom-nav active tab background.
  Color navPill(Brightness b) =>
      b == Brightness.dark ? const Color(0x2614B8A6) : BrandColors.c50; // brand-500 @15%

  /// Bottom-nav active tab icon/label color.
  Color navText(Brightness b) => b == Brightness.dark ? BrandColors.c300 : BrandColors.c700;
}

const Map<UiRole, RoleTheme> kRoleThemes = {
  UiRole.guest: RoleTheme(role: UiRole.guest, labelKey: 'roles.guest', icon: Icons.visibility_outlined),
  UiRole.passenger: RoleTheme(role: UiRole.passenger, labelKey: 'roles.passenger', icon: Icons.person_outline),
  UiRole.driver: RoleTheme(role: UiRole.driver, labelKey: 'roles.driver', icon: Icons.directions_car_filled_outlined),
};

RoleTheme roleThemeFor(UiRole role) => kRoleThemes[role]!;
