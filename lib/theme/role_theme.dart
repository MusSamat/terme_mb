import 'package:flutter/material.dart';
import 'colors.dart';
import 'dimens.dart';

/// Role colour language — 1:1 port of terme_ft/src/lib/role-colors.ts.
///   guest = ink (warm gray) · passenger = brand (teal) · driver = grape (indigo).
/// Primary CTAs stay amber everywhere; role accents drive nav, headers, chips.
enum UiRole { guest, passenger, driver }

/// A resolved colour recipe for a role. Light/dark variants are provided as
/// pairs where the web used `dark:` classes.
@immutable
class RoleTheme {
  const RoleTheme({
    required this.role,
    required this.labelKey,
    required this.icon,
    required this.headerGradient,
    required this.bannerGradient,
    required this.ctaFilled,
    required this.ctaShadow,
    required this.navPillOn,
    required this.navPillOnDark,
    required this.navTextOn,
    required this.navTextOnDark,
    required this.textOn,
    required this.textOnDark,
    required this.chipSelected,
    required this.avatarTintBg,
    required this.avatarTintFg,
    required this.tabUnderline,
    required this.iconAccent,
  });

  final UiRole role;

  /// i18n key under `roles.*`.
  final String labelKey;

  /// lucide icon shown next to the role label.
  final IconData icon;

  /// Screen hero header gradient (top → bottom).
  final Gradient headerGradient;

  /// Wide banner gradient (left → right).
  final Gradient bannerGradient;

  /// Filled role CTA background + its glow shadow.
  final Color ctaFilled;
  final List<BoxShadow> ctaShadow;

  /// Bottom-nav active tab background.
  final Color navPillOn;
  final Color navPillOnDark;

  /// Bottom-nav active tab icon/label color.
  final Color navTextOn;
  final Color navTextOnDark;

  /// Accent "on" text (tabs, links).
  final Color textOn;
  final Color textOnDark;

  /// Selected date-chip background.
  final Color chipSelected;

  /// Role-tinted letter avatar.
  final Color avatarTintBg;
  final Color avatarTintFg;

  /// Active tab underline bar.
  final Color tabUnderline;

  /// Leading icons in inputs/fields.
  final Color iconAccent;

  Color navPill(Brightness b) => b == Brightness.dark ? navPillOnDark : navPillOn;
  Color navText(Brightness b) => b == Brightness.dark ? navTextOnDark : navTextOn;
  Color text(Brightness b) => b == Brightness.dark ? textOnDark : textOn;
}

const _guest = RoleTheme(
  role: UiRole.guest,
  labelKey: 'roles.guest',
  icon: Icons.visibility_outlined, // eye
  headerGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [InkColors.c500, InkColors.c600],
  ),
  bannerGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [InkColors.c500, InkColors.c600],
  ),
  ctaFilled: InkColors.c700,
  ctaShadow: AppShadows.lift,
  navPillOn: InkColors.c100,
  navPillOnDark: InkColors.c800,
  navTextOn: InkColors.c700,
  navTextOnDark: InkColors.c200,
  textOn: InkColors.c700,
  textOnDark: InkColors.c200,
  chipSelected: InkColors.c700,
  avatarTintBg: InkColors.c100,
  avatarTintFg: InkColors.c600,
  tabUnderline: InkColors.c500,
  iconAccent: InkColors.c500,
);

const _passenger = RoleTheme(
  role: UiRole.passenger,
  labelKey: 'roles.passenger',
  icon: Icons.person_outline, // user
  headerGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [BrandColors.c600, BrandColors.c500],
  ),
  bannerGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [BrandColors.c600, BrandColors.c500],
  ),
  ctaFilled: BrandColors.c600,
  ctaShadow: AppShadows.brandCta,
  navPillOn: BrandColors.c50,
  navPillOnDark: Color(0x2614B8A6), // brand-500 @15%
  navTextOn: BrandColors.c700,
  navTextOnDark: BrandColors.c300,
  textOn: BrandColors.c700,
  textOnDark: BrandColors.c300,
  chipSelected: BrandColors.c500,
  avatarTintBg: BrandColors.c100,
  avatarTintFg: BrandColors.c700,
  tabUnderline: BrandColors.c500,
  iconAccent: BrandColors.c500,
);

const _driver = RoleTheme(
  role: UiRole.driver,
  labelKey: 'roles.driver',
  icon: Icons.directions_car_filled_outlined, // car-front
  headerGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GrapeColors.c500, GrapeColors.c400],
  ),
  bannerGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [GrapeColors.c600, GrapeColors.c500],
  ),
  ctaFilled: GrapeColors.c600,
  ctaShadow: AppShadows.indigoCta,
  navPillOn: GrapeColors.c50,
  navPillOnDark: Color(0x266366F1), // grape-500 @15%
  navTextOn: GrapeColors.c600,
  navTextOnDark: GrapeColors.c300,
  textOn: GrapeColors.c600,
  textOnDark: GrapeColors.c300,
  chipSelected: GrapeColors.c500,
  avatarTintBg: GrapeColors.c100,
  avatarTintFg: GrapeColors.c700,
  tabUnderline: GrapeColors.c500,
  iconAccent: GrapeColors.c500,
);

const Map<UiRole, RoleTheme> kRoleThemes = {
  UiRole.guest: _guest,
  UiRole.passenger: _passenger,
  UiRole.driver: _driver,
};

RoleTheme roleThemeFor(UiRole role) => kRoleThemes[role]!;
