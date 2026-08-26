import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/review.dart';
import '../../models/self_user.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/query_error.dart';
import '../../widgets/verified_badge.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: ref.watch(publicProfileProvider(id)).when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
            error: (e, _) => Center(child: QueryError(error: e, onRetry: () => ref.invalidate(publicProfileProvider(id)))),
            data: (u) => _body(context, ref, dark, u),
          ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, bool dark, SelfUser u) {
    final role = roleThemeFor(u.isDriver ? UiRole.driver : UiRole.passenger);
    final reviews = ref.watch(userRatingsProvider(id)).valueOrNull ?? const <Review>[];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: role.headerGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl4)),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 56, 16, 24),
            child: Column(children: [
              DriverAvatar(name: u.name, imageUrl: u.avatarUrl, size: AvatarSize.xl, verified: u.isDriver),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: Text(u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                if (u.isDriver) ...[const SizedBox(width: 6), const VerifiedBadge(size: 18)],
              ]),
              const SizedBox(height: 4),
              Text(u.isDriver ? 'drivers.driver_badge'.tr() : 'roles.passenger'.tr(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
            ]),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _stat(dark, (u.rating ?? 0).toStringAsFixed(1), 'drivers.rating_label'.tr()),
              _stat(dark, '${u.ratingCount}', 'drivers.ratings_label'.tr()),
            ]),
            if ((u.bio ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              _card(dark, Text(u.bio!, style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: dark ? InkColors.c200 : InkColors.c700))),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('drivers.reviews_title'.tr(),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            ),
            const SizedBox(height: 10),
            if (reviews.isEmpty)
              Text('drivers.no_reviews'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400))
            else
              for (final r in reviews) _review(dark, r.raterName, r.score, r.comment ?? ''),
          ]),
        ),
      ],
    );
  }

  Widget _stat(bool dark, String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
        ]),
      );

  Widget _review(bool dark, String name, int stars, String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            const Spacer(),
            Row(children: [for (var i = 0; i < stars; i++) const Icon(Icons.star, size: 13, color: AccentColors.c400)]),
          ]),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: InkColors.c500)),
          ],
        ]),
      );

  Widget _card(bool dark, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}
