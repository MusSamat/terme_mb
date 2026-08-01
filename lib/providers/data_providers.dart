import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/services/auth_service.dart';
import '../api/services/bookings_service.dart';
import '../api/services/misc_services.dart';
import '../api/services/requests_service.dart';
import '../api/services/trips_service.dart';
import '../data/mock_app_data.dart';
import '../data/mock_requests.dart';
import '../data/mock_trips.dart';
import '../models/feed_filters.dart';
import '../models/passenger_request.dart';
import '../models/trip_card_item.dart';
import '../utils/config.dart';
import 'core_providers.dart';

// ── Service singletons (built on the shared Dio) ─────────────────────────────
Dio _dio(Ref ref) => ref.watch(dioClientProvider).dio;

final tripsServiceProvider = Provider<TripsService>((ref) => TripsService(_dio(ref)));
final authServiceProvider = Provider<AuthService>((ref) => AuthService(_dio(ref)));
final requestsServiceProvider = Provider<RequestsService>((ref) => RequestsService(_dio(ref)));
final bookingsServiceProvider = Provider<BookingsService>((ref) => BookingsService(_dio(ref)));
final chatServiceProvider = Provider<ChatService>((ref) => ChatService(_dio(ref)));
final notificationsServiceProvider = Provider<NotificationsService>((ref) => NotificationsService(_dio(ref)));
final loyaltyServiceProvider = Provider<LoyaltyService>((ref) => LoyaltyService(_dio(ref)));
final citiesServiceProvider = Provider<CitiesService>((ref) => CitiesService(_dio(ref)));

/// Wires the Dio refresh interceptor to the auth service + token store, so a
/// 401 TOKEN_EXPIRED silently refreshes and retries. Call once at startup.
final apiBootstrapProvider = Provider<void>((ref) {
  final client = ref.watch(dioClientProvider);
  final auth = ref.watch(authServiceProvider);
  final tokens = ref.watch(tokenStoreProvider);
  client.attachRefresh(() async {
    final token = await auth.refresh();
    if (token != null) tokens.set(token);
    return token;
  });
});

// ── Feed data — mock now, real API when USE_MOCK=false ───────────────────────

/// Trips feed. Swaps between bundled mock data and `GET /trips` on the
/// [AppConfig.useMock] flag — the single switch to go live.
final tripsFeedProvider = FutureProvider.family<List<TripCardItem>, FeedFilters>((ref, filters) async {
  if (AppConfig.useMock) {
    return mockTrips();
  }
  final service = ref.watch(tripsServiceProvider);
  final page = await service.list(
    date: filters.date.isEmpty ? null : filters.date,
    filters: {
      if (filters.onlyVerified) 'only_verified': 'true',
      if (filters.luggage.isNotEmpty) 'luggage': filters.luggage,
      if (filters.minRating > 0) 'min_rating': filters.minRating.toString(),
      if (filters.minPrice != null) 'min_price': filters.minPrice.toString(),
      if (filters.maxPrice != null) 'max_price': filters.maxPrice.toString(),
      if (filters.sort != 'time') 'sort': filters.sort,
    },
  );
  return page.data;
});

/// Single trip detail — mock lookup or `GET /trips/{id}`.
final tripDetailProvider = FutureProvider.family<TripCardItem, String>((ref, id) async {
  if (AppConfig.useMock) return mockTripById(id);
  return ref.watch(tripsServiceProvider).detail(id);
});

/// Per-day trip counts for the calendar — mock or `GET /trips/calendar`.
final tripCalendarProvider = FutureProvider<Map<String, int>>((ref) async {
  if (AppConfig.useMock) return tripCalendarCounts();
  return ref.watch(tripsServiceProvider).calendar();
});

// ── Sibling domains (mock↔remote) ────────────────────────────────────────────

final requestsFeedProvider = FutureProvider<List<PassengerRequestItem>>((ref) async {
  if (AppConfig.useMock) return mockRequests();
  return (await ref.watch(requestsServiceProvider).list()).data;
});

final requestDetailProvider = FutureProvider.family<PassengerRequestItem, String>((ref, id) async {
  if (AppConfig.useMock) return mockRequestById(id);
  return ref.watch(requestsServiceProvider).detail(id);
});

final myBookingsProvider = FutureProvider<List<MockBooking>>((ref) async {
  if (AppConfig.useMock) return mockBookings();
  return (await ref.watch(bookingsServiceProvider).mine()).data;
});

final chatSummariesProvider = FutureProvider<List<MockChat>>((ref) async {
  if (AppConfig.useMock) return mockChats();
  return ref.watch(chatServiceProvider).summaries();
});

final notificationsListProvider = FutureProvider<List<MockNotif>>((ref) async {
  if (AppConfig.useMock) return mockNotifs();
  return ref.watch(notificationsServiceProvider).list();
});

final loyaltyStatusProvider = FutureProvider<MockLoyalty>((ref) async {
  if (AppConfig.useMock) return mockLoyalty();
  return ref.watch(loyaltyServiceProvider).status();
});
