import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

// Real screens.
export 'home/home_feed_screen.dart';
export 'trip/trip_detail_screen.dart';
export 'create/create_screen.dart';
export 'my/my_bookings_screen.dart';
export 'chat/chat_hub_screen.dart';
export 'chat/chat_thread_screen.dart';
export 'profile/profile_screen.dart';
export 'profile/driver_verification_screen.dart';
export 'notifications/notifications_screen.dart';
export 'loyalty/loyalty_screen.dart';
export 'auth/login_screen.dart';
export 'auth/register_screen.dart';
export 'requests/requests_feed_screen.dart';
export 'requests/request_detail_screen.dart';
export 'rate/rate_screen.dart';
export 'complaint/complaint_screen.dart';
export 'drivers/public_profile_screen.dart';
export 'onboarding/onboarding_screen.dart';
export 'legal/legal_screen.dart';

/// Remaining stubs — low-priority screens still to be built out.

class TripsFeedScreen extends StatelessWidget {
  const TripsFeedScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Поездки', subtitle: 'search-layout');
}

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Удаление аккаунта', subtitle: 'profile/delete', showAppBar: true);
}
