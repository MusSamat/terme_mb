import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

// Real screens (built out from placeholders as we go).
export 'home/home_feed_screen.dart';
export 'trip/trip_detail_screen.dart';
export 'create/create_screen.dart';
export 'my/my_bookings_screen.dart';
export 'chat/chat_hub_screen.dart';
export 'chat/chat_thread_screen.dart';
export 'profile/profile_screen.dart';
export 'notifications/notifications_screen.dart';
export 'loyalty/loyalty_screen.dart';
export 'auth/login_screen.dart';

/// Remaining skeleton screens. Each maps to a ТЗ §6.3 spec — replaced by the
/// real implementation as we build them out.

class TripsFeedScreen extends StatelessWidget {
  const TripsFeedScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Поездки', subtitle: 'search-layout');
}

class RequestsFeedScreen extends StatelessWidget {
  const RequestsFeedScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Заявки пассажиров', subtitle: 'requests-feed');
}

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: 'Заявка $id', subtitle: 'request-detail');
}

class DriverVerificationScreen extends StatelessWidget {
  const DriverVerificationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Верификация водителя', subtitle: 'profile/driver', showAppBar: true);
}

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Удаление аккаунта', subtitle: 'profile/delete', showAppBar: true);
}

class RateScreen extends StatelessWidget {
  const RateScreen({super.key, required this.tripId, required this.rateeId});
  final String tripId;
  final String rateeId;
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: 'Оценка', subtitle: 'rate ($tripId/$rateeId)', showAppBar: true);
}

class ComplaintScreen extends StatelessWidget {
  const ComplaintScreen({super.key, this.userId, this.tripId});
  final String? userId;
  final String? tripId;
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Жалоба', subtitle: 'complaint', showAppBar: true);
}

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: 'Профиль $id', subtitle: 'drivers/:id', showAppBar: true);
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Регистрация', subtitle: 'auth/register', showAppBar: false);
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Добро пожаловать', subtitle: 'onboarding', showAppBar: false);
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final String kind; // about | privacy | terms
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: kind, subtitle: 'legal', showAppBar: true);
}
