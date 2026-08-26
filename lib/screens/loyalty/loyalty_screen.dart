import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/query_error.dart';

/// Loyalty — 1:1 port of loyalty page: tier-colored status card, tier roadmap,
/// how-to-earn, history. Tier palette: novice ink · traveler sky · expert
/// grape · elite accent.
class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});

  static const _tiers = ['novice', 'traveler', 'expert', 'elite'];

  ({Color text, Color bg, Color progress}) _tierColors(String tier, bool dark) {
    switch (tier) {
      case 'traveler':
        return (
          text: dark ? SkyColors.c300 : SkyColors.c700,
          bg: dark ? SkyColors.c500.withValues(alpha: 0.1) : SkyColors.c50,
          progress: SkyColors.c600
        );
      case 'expert':
        return (
          text: dark ? GrapeColors.c300 : GrapeColors.c700,
          bg: dark ? GrapeColors.c500.withValues(alpha: 0.1) : GrapeColors.c50,
          progress: GrapeColors.c600
        );
      case 'elite':
        return (
          text: dark ? AccentColors.c300 : AccentColors.c700,
          bg: dark
              ? AccentColors.c500.withValues(alpha: 0.1)
              : AccentColors.c50,
          progress: AccentColors.c500
        );
      default:
        return (
          text: dark ? InkColors.c300 : InkColors.c600,
          bg: dark ? InkColors.c800 : InkColors.c100,
          progress: InkColors.c500
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
        title: Text('loyalty.title'.tr(),
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: Consumer(
          builder: (context, ref, _) => ref.watch(loyaltyStatusProvider).when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.6, color: BrandColors.c500)),
                error: (e, st) => QueryError(
                    error: e,
                    onRetry: () => ref.invalidate(loyaltyStatusProvider)),
                data: (l) {
                  final c = _tierColors(l.tier, dark);
                  final progress = l.pointsToNext > 0
                      ? l.points / (l.points + l.pointsToNext)
                      : 1.0;
                  final tierIndex = _tiers.indexOf(l.tier);
                  return RefreshIndicator(
                    color: BrandColors.c500,
                    onRefresh: () async {
                      ref.invalidate(loyaltyStatusProvider);
                      await ref.read(loyaltyStatusProvider.future);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16,
                          24 + MediaQuery.of(context).padding.bottom),
                      children: [
                        // Status card (tier-colored)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(AppRadii.xl3),
                            border: Border.all(
                                color: c.progress.withValues(alpha: 0.35)),
                            boxShadow: AppShadows.card,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.military_tech,
                                    size: 20, color: c.text),
                                const SizedBox(width: 8),
                                Text(
                                    'loyalty.tiers.${l.tier}'
                                        .tr()
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: c.text)),
                              ]),
                              const SizedBox(height: 8),
                              Text.rich(TextSpan(children: [
                                TextSpan(
                                    text: '${l.points}',
                                    style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 40,
                                        height: 1,
                                        fontWeight: FontWeight.w900,
                                        color: dark
                                            ? Colors.white
                                            : InkColors.c900)),
                                TextSpan(
                                    text: '  ${'loyalty.points_suffix'.tr()}',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: InkColors.c500)),
                              ])),
                              if (l.nextTier != null) ...[
                                const SizedBox(height: 18),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                          child: Text(
                                              'loyalty.to_next_tier'.tr(
                                                  namedArgs: {
                                                    'tier':
                                                        'loyalty.tiers.${l.nextTier}'
                                                            .tr()
                                                  }),
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: dark
                                                      ? InkColors.c300
                                                      : InkColors.c600))),
                                      Text(
                                          'loyalty.points_remaining'.tr(
                                              namedArgs: {
                                                'n': '${l.pointsToNext}'
                                              }),
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: c.text)),
                                    ]),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: dark
                                          ? InkColors.c950
                                              .withValues(alpha: 0.4)
                                          : Colors.white.withValues(alpha: 0.7),
                                      valueColor:
                                          AlwaysStoppedAnimation(c.progress)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tier roadmap
                        _card(
                            dark,
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('loyalty.tiers_section'.tr(),
                                      style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: dark
                                              ? Colors.white
                                              : InkColors.c900)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      for (var i = 0;
                                          i < _tiers.length;
                                          i++) ...[
                                        if (i > 0)
                                          Expanded(
                                              child: Container(
                                                  height: 2,
                                                  color: i <= tierIndex
                                                      ? c.progress
                                                      : (dark
                                                          ? InkColors.c700
                                                          : InkColors.c200))),
                                        Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: i <= tierIndex
                                                      ? c.progress
                                                      : (dark
                                                          ? InkColors.c800
                                                          : InkColors.c100),
                                                  shape: BoxShape.circle,
                                                  border: i == tierIndex
                                                      ? Border.all(
                                                          color: c.text,
                                                          width: 3)
                                                      : null,
                                                ),
                                                child: Icon(Icons.military_tech,
                                                    size: 16,
                                                    color: i <= tierIndex
                                                        ? Colors.white
                                                        : InkColors.c400),
                                              ),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                width: 60,
                                                child: Text(
                                                    'loyalty.tiers.${_tiers[i]}'
                                                        .tr(),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: i <= tierIndex
                                                            ? (dark
                                                                ? Colors.white
                                                                : InkColors
                                                                    .c800)
                                                            : InkColors.c400)),
                                              ),
                                            ]),
                                      ],
                                    ],
                                  ),
                                ])),
                        const SizedBox(height: 16),
                        Text('loyalty.how_to_earn_section'.tr(),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : InkColors.c900)),
                        const SizedBox(height: 10),
                        _earn(dark, Icons.directions_car,
                            'loyalty.earn.driver'.tr(), '+10'),
                        _earn(dark, Icons.event_seat,
                            'loyalty.earn.passenger'.tr(), '+5'),
                        _earn(dark, Icons.star, 'loyalty.earn.five_stars'.tr(),
                            '+3'),
                        const SizedBox(height: 16),
                        Text('loyalty.history_section'.tr(),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : InkColors.c900)),
                        const SizedBox(height: 10),
                        for (final tx in l.transactions) _tx(dark, tx),
                      ],
                    ),
                  );
                },
              )),
    );
  }

  Widget _earn(bool dark, IconData icon, String label, String pts) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: dark ? InkColors.c800 : InkColors.c100)),
        child: Row(children: [
          Icon(icon,
              size: 20, color: dark ? BrandColors.c300 : BrandColors.c600),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : InkColors.c900))),
          Text(pts,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: dark ? BrandColors.c300 : BrandColors.c600)),
        ]),
      );

  Widget _tx(bool dark, MockLoyaltyTx tx) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: dark ? InkColors.c800 : InkColors.c100)),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('loyalty.sources.${tx.sourceKey}'.tr(),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : InkColors.c900)),
              Text(tx.dateLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: InkColors.c400)),
            ]),
          ),
          Text('+${tx.points}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: BrandColors.c600)),
        ]),
      );

  Widget _card(bool dark, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl3),
            boxShadow: AppShadows.card),
        child: child,
      );
}
