import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../data/mock_app_data.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/config.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/query_error.dart';

/// Notifications — tinted icon-medallion cards. Tapping a card marks it read on
/// the server and (when the type is navigable) deep-links to the trip/chat.
/// Read-state is server-authoritative and re-fetched on open / app-resume, so a
/// notification read on one device shows as read on the others.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pull fresh read-state whenever the screen opens (cross-device sync).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotifProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotifProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _readAll() async {
    if (AppConfig.useMock) return;
    try {
      await ref.read(notificationsServiceProvider).markAllRead();
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotifProvider);
    } catch (e) {
      Toasts.error(friendlyError(e));
    }
  }

  Future<void> _open(MockNotif n) async {
    // Mark read on the server first so every device converges on the same state.
    if (n.unread && n.id.isNotEmpty && !AppConfig.useMock) {
      try {
        await ref.read(notificationsServiceProvider).markRead(n.id);
        ref.invalidate(notificationsListProvider);
        ref.invalidate(unreadNotifProvider);
      } catch (_) {/* navigate anyway */}
    }
    // go() (not push): deep-link targets include shell-branch routes
    // (/my/bookings) — pushing those from this root-level screen was unreliable
    // (tap appeared to do nothing). go() switches branch/route consistently.
    if (n.route != null && mounted) context.go(n.route!);
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
        title: Text('notif.default_label'.tr(),
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
        actions: [
          TextButton(
            onPressed: _readAll,
            child: Text('notif.read_all'.tr(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: dark ? BrandColors.c300 : BrandColors.c600)),
          ),
        ],
      ),
      body: ref.watch(notificationsListProvider).when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: BrandColors.c500)),
            error: (e, _) => QueryError(
                error: e,
                onRetry: () => ref.invalidate(notificationsListProvider)),
            data: (items) => RefreshIndicator(
              color: BrandColors.c500,
              onRefresh: () async {
                ref.invalidate(notificationsListProvider);
                ref.invalidate(unreadNotifProvider);
                await ref.read(notificationsListProvider.future);
              },
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                              child: Text('notif.empty'.tr(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: InkColors.c400))),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _NotifCard(
                          notif: items[i], onTap: () => _open(items[i])),
                    ),
            ),
          ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.onTap});
  final MockNotif notif;
  final VoidCallback onTap;

  // Per-type icon + colour — 1:1 port of the web `TYPE_CONFIG`, so each
  // notification gets its own medallion (blue clock for reminders, red warning
  // for rejections, amber star for ratings…) instead of a generic kind icon.
  static const _typeVisual = <String, ({IconData icon, Color color})>{
    'new_booking_request': (
      icon: Icons.directions_car,
      color: BrandColors.c600
    ),
    'booking_accepted': (icon: Icons.check_circle, color: BrandColors.c600),
    'booking_request_confirmed': (
      icon: Icons.check_circle,
      color: BrandColors.c600
    ),
    'booking_rejected': (icon: Icons.error, color: CoralColors.c500),
    'booking_expired': (icon: Icons.error, color: CoralColors.c500),
    'booking_cancelled_by_passenger': (
      icon: Icons.error,
      color: CoralColors.c500
    ),
    'booking_cancelled_by_driver': (icon: Icons.error, color: CoralColors.c500),
    'trip_cancelled': (icon: Icons.directions_car, color: CoralColors.c500),
    'trip_reminder': (icon: Icons.schedule, color: SkyColors.c600),
    'trip_completed_rate': (icon: Icons.star, color: AccentColors.c500),
    'request_response_received': (icon: Icons.group, color: SkyColors.c600),
    'request_response_accepted': (
      icon: Icons.check_circle,
      color: BrandColors.c600
    ),
    'request_response_declined': (icon: Icons.error, color: CoralColors.c500),
    'request_cancelled_admin': (icon: Icons.error, color: CoralColors.c500),
    'new_message': (icon: Icons.chat_bubble, color: BrandColors.c600),
    'rating_received': (icon: Icons.star, color: AccentColors.c500),
    'rating_warning': (icon: Icons.error, color: CoralColors.c500),
    'verification_approved': (
      icon: Icons.check_circle,
      color: BrandColors.c600
    ),
    'verification_rejected': (icon: Icons.error, color: CoralColors.c500),
    'verification_need_docs': (icon: Icons.error, color: AccentColors.c500),
    'account_blocked': (icon: Icons.error, color: CoralColors.c500),
    'loyalty_tier_changed': (icon: Icons.star, color: AccentColors.c500),
    'security_alert_reuse': (icon: Icons.error, color: CoralColors.c500),
  };

  ({IconData icon, Color color}) _visual() {
    // Real notifications carry the raw backend `type`; mock ones only the
    // `typeKey` (notif.type_<type>) — strip the prefix so both resolve.
    final type = notif.type.isNotEmpty
        ? notif.type
        : (notif.typeKey.startsWith('notif.type_')
            ? notif.typeKey.substring('notif.type_'.length)
            : '');
    return _typeVisual[type] ?? (icon: Icons.info, color: InkColors.c600);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = _visual();
    final unread = notif.unread;

    // Unread card: tinted bg + ring; read: white + ink ring.
    final cardBg = unread
        ? v.color.withValues(alpha: dark ? 0.1 : 0.08)
        : (dark ? InkColors.c900 : Colors.white);
    final cardBorder = unread
        ? v.color.withValues(alpha: 0.25)
        : (dark ? InkColors.c800 : InkColors.c100);

    // Medallion: filled when unread, tinted when read.
    final medBg =
        unread ? v.color : v.color.withValues(alpha: dark ? 0.15 : 0.15);
    final medFg = unread ? Colors.white : v.color;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: cardBorder),
          boxShadow: unread ? null : AppShadows.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: medBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(v.icon, size: 20, color: medFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.typeKey.tr(),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : InkColors.c900)),
                      ),
                      Text(notif.timeLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: InkColors.c400)),
                    ],
                  ),
                  if (notif.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notif.body,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: InkColors.c500)),
                  ],
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: CoralColors.c500, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
