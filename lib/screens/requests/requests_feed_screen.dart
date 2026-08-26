import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/feed_filters.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/list_card.dart';
import '../../widgets/query_error.dart';

class RequestsFeedScreen extends ConsumerWidget {
  const RequestsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final driverTheme = roleThemeFor(UiRole.driver);

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: driverTheme.headerGradient,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadii.xl4)),
            ),
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 16, 16, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('requests.page_title'.tr(),
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          Expanded(
            child: ref.watch(requestsFeedProvider(const FeedFilters())).when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.6, color: GrapeColors.c500)),
                  error: (e, _) => QueryError(
                      error: e,
                      onRetry: () => ref.invalidate(
                          requestsFeedProvider(const FeedFilters()))),
                  data: (requests) => RefreshIndicator(
                    color: BrandColors.c500,
                    onRefresh: () async {
                      ref.invalidate(requestsFeedProvider(const FeedFilters()));
                      await ref.read(
                          requestsFeedProvider(const FeedFilters()).future);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          AppLayout.pillNavClearance +
                              MediaQuery.of(context).padding.bottom),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = requests[i];
                        return ListCard(
                          grape: true,
                          when: r.dateLabel,
                          role: r.responded ? 'card.responded'.tr() : null,
                          origin: r.originCity,
                          destination: r.destinationCity,
                          avatar: DriverAvatar(
                              name: r.passengerName,
                              verified: r.passengerVerified),
                          actorName: r.passengerName,
                          actorSub: r.passengerRating != null
                              ? Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.star,
                                      size: 12, color: AccentColors.c400),
                                  const SizedBox(width: 3),
                                  Text(r.passengerRating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: InkColors.c500)),
                                ])
                              : null,
                          trailing: Text(
                              '${r.seatsNeeded} ${'booking_card.seats_word'.tr()}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: InkColors.c500)),
                          onTap: () => context.push('/requests/${r.id}'),
                        );
                      },
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
