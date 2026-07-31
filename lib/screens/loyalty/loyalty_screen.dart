import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';

class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = mockLoyalty();
    final progress = l.pointsToNext > 0 ? l.points / (l.points + l.pointsToNext) : 1.0;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text('loyalty.title'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          // Tier + points hero
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AccentColors.c400, AccentColors.c600],
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl3),
              boxShadow: AppShadows.cta,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: AccentColors.ink, size: 24),
                    const SizedBox(width: 8),
                    Text('loyalty.tiers.${l.tier}'.tr(),
                        style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AccentColors.ink)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${l.points} ${'loyalty.points_suffix'.tr()}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AccentColors.ink)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AccentColors.ink.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(AccentColors.ink),
                  ),
                ),
                const SizedBox(height: 6),
                if (l.nextTier != null)
                  Text(
                    '${'loyalty.to_next_tier'.tr(namedArgs: {'tier': 'loyalty.tiers.${l.nextTier}'.tr()})} · ${'loyalty.points_remaining'.tr(namedArgs: {'n': '${l.pointsToNext}'})}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AccentColors.ink.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // How to earn
          Text('loyalty.how_to_earn_section'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 10),
          _earn(dark, Icons.directions_car, 'loyalty.earn.driver'.tr(), '+10'),
          _earn(dark, Icons.event_seat, 'loyalty.earn.passenger'.tr(), '+5'),
          _earn(dark, Icons.star, 'loyalty.earn.five_stars'.tr(), '+3'),
          const SizedBox(height: 20),
          // History
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
  }

  Widget _earn(bool dark, IconData icon, String label, String pts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: dark ? BrandColors.c300 : BrandColors.c600),
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
        ],
      ),
    );
  }

  Widget _tx(bool dark, MockLoyaltyTx tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('loyalty.sources.${tx.sourceKey}'.tr(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : InkColors.c900)),
                Text(tx.dateLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
              ],
            ),
          ),
          Text('+${tx.points}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: BrandColors.c600)),
        ],
      ),
    );
  }
}
