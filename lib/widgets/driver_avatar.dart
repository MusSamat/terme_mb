import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Letter avatar — port of tappjet_ft driver-avatar.tsx.
/// Grape tint, font-900 initials; optional brand check-dot overlay.
enum AvatarSize { xs, sm, md, lg, xl }

class DriverAvatar extends StatelessWidget {
  const DriverAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AvatarSize.sm,
    this.square = false,
    this.verified = false,
  });

  final String name;
  final String? imageUrl;
  final AvatarSize size;
  final bool square;
  final bool verified;

  static const _px = {
    AvatarSize.xs: 24.0,
    AvatarSize.sm: 32.0,
    AvatarSize.md: 40.0,
    AvatarSize.lg: 56.0,
    AvatarSize.xl: 64.0,
  };
  static const _fontPx = {
    AvatarSize.xs: 11.0,
    AvatarSize.sm: 12.0,
    AvatarSize.md: 16.0,
    AvatarSize.lg: 20.0,
    AvatarSize.xl: 21.0,
  };

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).take(2);
    final s = parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    return s.isEmpty ? '?' : s;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dim = _px[size]!;
    final radius = square ? 16.0 : dim / 2;

    final letter = Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? GrapeColors.c500.withValues(alpha: 0.2) : GrapeColors.c100,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: _fontPx[size],
          color: dark ? GrapeColors.c300 : GrapeColors.c600,
        ),
      ),
    );

    final avatar = imageUrl != null && imageUrl!.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.network(
              imageUrl!,
              width: dim,
              height: dim,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => letter,
            ),
          )
        : letter;

    if (!verified) return avatar;

    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.c600,
                shape: BoxShape.circle,
                border: Border.all(color: dark ? InkColors.c900 : Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
