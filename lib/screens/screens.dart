import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

// Real screens (built out from placeholders as we go).
export 'home/home_feed_screen.dart';
export 'trip/trip_detail_screen.dart';
export 'create/create_screen.dart';

/// Skeleton screens. Each maps to a ТЗ §6.3 spec — replace with the real
/// implementation. Kept in one file to keep the skeleton compact; split into
/// per-feature folders as they get built out.

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

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key, this.tab});
  final String? tab;
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: 'Мои', subtitle: 'bookings-hub (tab=$tab)');
}

class ChatHubScreen extends StatelessWidget {
  const ChatHubScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Чаты', subtitle: 'chat-hub');
}

class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: 'Диалог', subtitle: 'chat-panel ($bookingId)', showAppBar: true);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Профиль', subtitle: 'profile');
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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Уведомления', subtitle: 'notifications', showAppBar: true);
}

class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Лояльность', subtitle: 'loyalty', showAppBar: true);
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

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Вход', subtitle: 'auth/login', showAppBar: false);
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
