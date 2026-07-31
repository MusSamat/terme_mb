import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_trips.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../widgets/trip_card.dart';

/// Home feed — passenger trip search (port of tappjet_ft home-feed +
/// search-layout + feed-header). Role-colored hero with route pickers and a
/// date rail, then a scrolling list of ride cards. Mock data for now.
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  int _selectedDate = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleThemeProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final trips = mockTrips();

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: Column(
        children: [
          _Hero(role: role),
          _DateRail(
            role: role,
            selected: _selectedDate,
            onSelect: (i) => setState(() => _selectedDate = i),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom,
              ),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => TripCard(
                trip: trips[i],
                onTap: () => context.push('/trips/${trips[i].id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.role});
  final RoleTheme role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    final mode = ref.watch(authProvider).activeMode;
    final driver = mode == ActiveMode.driver;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: role.headerGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl4)),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('feed.route_title'.tr(),
              style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 14),
          _RoutePickers(),
          const SizedBox(height: 12),
          _SubmitButton(label: driver ? 'feed.find_passenger'.tr() : 'feed.find_trip'.tr()),
        ],
      ),
    );
  }
}

class _RoutePickers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Column(
          children: [
            _PickerField(icon: Icons.trip_origin, hint: 'feed.from_placeholder'.tr()),
            const SizedBox(height: 8),
            _PickerField(icon: Icons.place, hint: 'feed.to_placeholder'.tr()),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.card,
            ),
            child: const Icon(Icons.swap_vert, size: 18, color: InkColors.c600),
          ),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.icon, required this.hint});
  final IconData icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    // Non-functional for now — opens the city picker in a later pass (ТЗ §7).
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: InkColors.c400),
          const SizedBox(width: 10),
          Text(hint,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c400)),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: kCreateFabGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.cta,
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: AccentColors.ink)),
    );
  }
}

class _DateRail extends StatelessWidget {
  const _DateRail({required this.role, required this.selected, required this.onSelect});
  final RoleTheme role;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final labels = <String>[
      'feed.today'.tr(),
      'feed.tomorrow'.tr(),
      for (var i = 2; i < 7; i++)
        () {
          final d = now.add(Duration(days: i));
          return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
        }(),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active
                    ? role.chipSelected
                    : (dark ? InkColors.c800 : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? Colors.white
                          : (dark ? InkColors.c200 : InkColors.c700))),
            ),
          );
        },
      ),
    );
  }
}
