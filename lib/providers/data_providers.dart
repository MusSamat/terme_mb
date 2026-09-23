import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/services/auth_service.dart';
import '../api/services/bookings_service.dart';
import '../api/services/cars_service.dart';
import '../api/services/complaints_service.dart';
import '../api/services/drivers_service.dart';
import '../api/services/likes_service.dart';
import '../api/services/misc_services.dart';
import '../api/services/profile_service.dart';
import '../api/services/ratings_service.dart';
import '../api/services/requests_service.dart';
import '../api/services/trips_service.dart';
import '../api/services/users_service.dart';
import '../api/services/presence_service.dart';
import '../data/mock_app_data.dart';
import '../data/mock_requests.dart';
import '../data/mock_trips.dart';
import '../models/car.dart';
import '../models/driver_stats.dart';
import '../models/feed_filters.dart';
import '../models/passenger_request.dart';
import '../models/pending_rating.dart';
import '../models/request_response.dart';
import '../models/review.dart';
import '../models/self_user.dart';
import '../models/trip_card_item.dart';
import '../utils/api_format.dart';
import '../utils/config.dart';
import '../utils/date_format.dart';
import 'auth_provider.dart';
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
final popularRoutesProvider = FutureProvider<List<PopularRoute>>((ref) => ref.read(citiesServiceProvider).popularRoutes());
final presenceServiceProvider = Provider<PresenceService>((ref) => PresenceService(_dio(ref)));

/// Live online count — polls every 20s for the badge. Keeps the last value on error.
final onlineCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final svc = ref.watch(presenceServiceProvider);
  while (true) {
    try {
      yield await svc.online();
    } catch (_) {
      // ignore transient errors, keep previous value
    }
    await Future<void>.delayed(const Duration(seconds: 20));
  }
});
final ratingsServiceProvider = Provider<RatingsService>((ref) => RatingsService(_dio(ref)));
final complaintsServiceProvider = Provider<ComplaintsService>((ref) => ComplaintsService(_dio(ref)));
final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService(_dio(ref)));
final carsServiceProvider = Provider<CarsService>((ref) => CarsService(_dio(ref)));
final driversServiceProvider = Provider<DriversService>((ref) => DriversService(_dio(ref)));
final usersServiceProvider = Provider<UsersService>((ref) => UsersService(_dio(ref)));
final likesServiceProvider = Provider<LikesService>((ref) => LikesService(_dio(ref)));

/// Wires the Dio refresh interceptor to the auth service + token store, so a
/// 401 TOKEN_EXPIRED silently refreshes and retries. Call once at startup.
final apiBootstrapProvider = Provider<void>((ref) {
  final client = ref.watch(dioClientProvider);
  final auth = ref.watch(authServiceProvider);
  final tokens = ref.watch(tokenStoreProvider);
  final notifier = ref.read(authProvider.notifier);

  client.attachRefresh(() async {
    final token = await auth.refresh();
    if (token != null) tokens.set(token);
    return token;
  });

  // Token reuse detected on /auth/refresh → the backend revoked every session.
  // Clear tokens/cookie and drop to anonymous so the router bounces to login.
  client.attachForceLogout(notifier.clearSession);

  // Cold-start session restore: the persistent refresh cookie lets us silently
  // re-authenticate, so a logged-in user stays logged in across app restarts
  // until they explicitly log out. Runs once (guards on the idle status).
  Future<void> restore() async {
    if (ref.read(authProvider).status != AuthStatus.idle) return;
    if (ref.read(hiveBoxProvider).get(StorageKeys.sessionHint) != '1') {
      notifier.setStatus(AuthStatus.anonymous);
      return;
    }
    // Optimistic hydrate: render the logged-in shell instantly from the cached
    // profile, then silently re-authenticate in the background (single refresh —
    // same as before, so no double-refresh / token-reuse risk).
    final cached = notifier.readCachedUser();
    if (cached != null) {
      notifier.setSession(cached); // authenticated now; the real token lands below
    } else {
      notifier.setStatus(AuthStatus.loading);
    }
    try {
      final token = await auth.refresh();
      if (token == null) throw Exception('refresh_failed');
      tokens.set(token);
      final me = await auth.me();
      notifier.setSession(me, accessToken: token);
    } on DioException catch (e) {
      // A definitive auth failure (dead / rotated cookie) → really log out. A mere
      // offline blip (no response) keeps the optimistic cached session, so a valid
      // 30-day login survives a network hiccup; the next online call refreshes.
      if (e.response?.statusCode == 401) {
        notifier.clearSession();
      } else if (cached == null) {
        notifier.setStatus(AuthStatus.anonymous);
      }
    } catch (_) {
      if (cached == null) notifier.setStatus(AuthStatus.anonymous);
    }
  }

  restore();
});

/// Real-time bridge (Flutter mirror of web NotificationListener): while
/// authenticated, connect the socket and refresh the affected lists as
/// server-pushed events arrive, so notifications / bookings / chats update live
/// across devices. Disconnects on logout.
final socketBootstrapProvider = Provider<void>((ref) {
  final authed = ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
  final socket = ref.watch(socketClientProvider);

  if (!authed) {
    socket.disconnect();
    return;
  }

  void invNotifs() { ref.invalidate(notificationsListProvider); ref.invalidate(unreadNotifProvider); }
  void invBookings() {
    ref.invalidate(myBookingsProvider);
    ref.invalidate(incomingBookingsProvider);
    ref.invalidate(myTripsProvider);
    ref.invalidate(myRequestsProvider);
    // Accept/cancel/expire changes the trip's free-seat count — refresh the
    // public feed and any open trip detail so seats stay in sync (mini-app parity).
    ref.invalidate(tripsFeedProvider);
    ref.invalidate(tripDetailProvider);
  }
  void invChats() { ref.invalidate(chatSummariesProvider); ref.invalidate(unreadChatProvider); }

  final handlers = <(String, void Function(dynamic))>[
    // Reconnect → resync everything (events fired while offline are lost).
    ('connect', (_) { invNotifs(); invBookings(); invChats(); }),
    ('notification:new', (_) => invNotifs()),
    ('booking:new_request', (_) { invBookings(); invNotifs(); }),
    ('booking:accepted', (_) { invBookings(); invNotifs(); }),
    ('booking:request_confirmed', (_) { invBookings(); invNotifs(); }),
    ('booking:rejected', (_) { invBookings(); invNotifs(); }),
    ('booking:cancelled', (_) { invBookings(); invNotifs(); }),
    ('booking:expired', (_) { invBookings(); invNotifs(); }),
    ('booking:viewed', (_) => invBookings()),
    ('trip:cancelled', (_) { invBookings(); invNotifs(); }),
    ('trip:completed_rate', (_) => invNotifs()),
    ('request:response_received', (_) => invNotifs()),
    ('request:response_accepted', (_) { invBookings(); invNotifs(); }),
    ('request:response_declined', (_) => invNotifs()),
    ('chat:message', (_) => invChats()),
  ];

  for (final (event, h) in handlers) {
    socket.on(event, h);
  }
  socket.connect();

  ref.onDispose(() {
    for (final (event, h) in handlers) {
      socket.off(event, h);
    }
  });
});

// ── Feed data — mock now, real API when USE_MOCK=false ───────────────────────

/// Trips feed with cursor pagination (mirror of web infinite scroll). Yields
/// AsyncValue<List> so `.when()` keeps working; `loadMore()` appends the next
/// page, `hasMore`/`nearby` drive the UI.
Map<String, dynamic> _tripFilterMap(FeedFilters f) => {
      if (f.seats != null) 'seats': f.seats.toString(),
      if (f.onlyVerified) 'only_verified': 'true',
      if (f.luggage.isNotEmpty) 'luggage': f.luggage,
      if (f.minRating > 0) 'min_rating': f.minRating.toString(),
      if (f.minPrice != null) 'min_price': f.minPrice.toString(),
      if (f.maxPrice != null) 'max_price': f.maxPrice.toString(),
      if (f.womenOnly) 'women_only': 'true',
      if (f.noSmoking) 'no_smoking': 'true',
      if (f.pets) 'pets': 'true',
      if (f.sort != 'time') 'sort': f.sort,
    };
// Web parity: an empty date means "today" (the stepper's default label is
// «Сегодня»), so the feed must filter to today — not return every day. Only the
// explicit «any» clears the date filter. Applies to trips AND requests.
// Feed date param — see apiFeedDate (utils/api_format.dart) for the contract
// (must be an ISO datetime with +06:00 offset, not a bare date).
String? _feedDate(FeedFilters f) => apiFeedDate(f.date);

class TripsFeedNotifier extends FamilyAsyncNotifier<List<TripCardItem>, FeedFilters> {
  String? _cursor;
  bool nearby = false;
  bool loadingMore = false;
  bool get hasMore => _cursor != null;

  @override
  Future<List<TripCardItem>> build(FeedFilters filters) async {
    if (AppConfig.useMock) {
      _cursor = null;
      return mockTrips();
    }
    final page = await ref.watch(tripsServiceProvider).list(
          from: filters.from,
          to: filters.to,
          date: _feedDate(filters),
          filters: _tripFilterMap(filters),
        );
    _cursor = page.nextCursor;
    nearby = page.nearby;
    return page.data;
  }

  Future<void> loadMore() async {
    if (loadingMore || _cursor == null || AppConfig.useMock) return;
    loadingMore = true;
    try {
      final f = arg;
      final page = await ref.read(tripsServiceProvider).list(
            from: f.from,
            to: f.to,
            date: _feedDate(f),
            filters: _tripFilterMap(f),
            cursor: _cursor,
          );
      _cursor = page.nextCursor;
      state = AsyncData([...(state.valueOrNull ?? const []), ...page.data]);
    } catch (_) {
      // keep what we have; the next scroll retries
    } finally {
      loadingMore = false;
    }
  }
}

final tripsFeedProvider =
    AsyncNotifierProvider.family<TripsFeedNotifier, List<TripCardItem>, FeedFilters>(TripsFeedNotifier.new);

/// Single trip detail — mock lookup or `GET /trips/{id}`.
final tripDetailProvider = FutureProvider.family<TripCardItem, String>((ref, id) async {
  if (AppConfig.useMock) return mockTripById(id);
  return ref.watch(tripsServiceProvider).detail(id);
});

/// Per-day trip counts for the calendar — mock or `GET /trips/calendar`.
/// Per-day availability counts for a route — mirror of web `useCalendarCounts`.
/// Route-scoped: only fetches when both cities are set (backend requires them);
/// returns {} otherwise. `kind` picks trips (passenger) vs requests (driver).
typedef CalendarKey = ({String kind, String from, String to});

final calendarCountsProvider = FutureProvider.family<Map<String, int>, CalendarKey>((ref, key) async {
  if (AppConfig.useMock) return tripCalendarCounts();
  if (key.from.isEmpty || key.to.isEmpty) return const {};
  return key.kind == 'requests'
      ? ref.watch(requestsServiceProvider).calendar(key.from, key.to)
      : ref.watch(tripsServiceProvider).calendar(key.from, key.to);
});

// ── Sibling domains (mock↔remote) ────────────────────────────────────────────

/// Requests feed (driver browsing) with cursor pagination. Route + date filtered
/// like web's driver filter subset.
class RequestsFeedNotifier extends FamilyAsyncNotifier<List<PassengerRequestItem>, FeedFilters> {
  String? _cursor;
  bool loadingMore = false;
  bool get hasMore => _cursor != null;

  @override
  Future<List<PassengerRequestItem>> build(FeedFilters filters) async {
    if (AppConfig.useMock) {
      _cursor = null;
      return mockRequests();
    }
    final page = await ref.watch(requestsServiceProvider).list(
          from: filters.from.isEmpty ? null : filters.from,
          to: filters.to.isEmpty ? null : filters.to,
          date: _feedDate(filters),
          seats: filters.seats,
        );
    _cursor = page.nextCursor;
    return page.data;
  }

  Future<void> loadMore() async {
    if (loadingMore || _cursor == null || AppConfig.useMock) return;
    loadingMore = true;
    try {
      final f = arg;
      final page = await ref.read(requestsServiceProvider).list(
            from: f.from.isEmpty ? null : f.from,
            to: f.to.isEmpty ? null : f.to,
            date: _feedDate(f),
            seats: f.seats,
            cursor: _cursor,
          );
      _cursor = page.nextCursor;
      state = AsyncData([...(state.valueOrNull ?? const []), ...page.data]);
    } catch (_) {
      // keep current items
    } finally {
      loadingMore = false;
    }
  }
}

final requestsFeedProvider =
    AsyncNotifierProvider.family<RequestsFeedNotifier, List<PassengerRequestItem>, FeedFilters>(RequestsFeedNotifier.new);

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

/// A single booking (GET /bookings/{id}) — hydrates the chat header/phone when a
/// thread is deep-linked and isn't yet in the summaries list. Null on failure.
final bookingDetailProvider = FutureProvider.family<MockBooking?, String>((ref, id) async {
  if (AppConfig.useMock) return null;
  try {
    return await ref.watch(bookingsServiceProvider).get(id);
  } catch (_) {
    return null;
  }
});

/// Message history for one booking, mapped to display bubbles (newest first, to
/// match the reversed ListView). `mine` is resolved against the current user id.
final chatThreadProvider = FutureProvider.family<List<MockMessage>, String>((ref, bookingId) async {
  if (AppConfig.useMock) return mockThread().reversed.toList();
  final myId = ref.watch(authProvider).user?.id;
  final rows = await ref.watch(chatServiceProvider).messages(bookingId);
  final msgs = rows.map((m) {
    final created = DateTime.tryParse((m['createdAt'] ?? '') as String)?.toLocal();
    return MockMessage(
      text: (m['text'] ?? '') as String,
      mine: myId != null && m['senderId'] == myId,
      timeLabel: created != null ? hhmm(created) : '',
      read: (m['isRead'] ?? false) as bool,
    );
  }).toList();
  return msgs.reversed.toList(); // newest first for the reversed list
});

final notificationsListProvider = FutureProvider<List<MockNotif>>((ref) async {
  if (AppConfig.useMock) return mockNotifs();
  return ref.watch(notificationsServiceProvider).list();
});

final loyaltyStatusProvider = FutureProvider<MockLoyalty>((ref) async {
  if (AppConfig.useMock) return mockLoyalty();
  return ref.watch(loyaltyServiceProvider).status();
});

/// Driver's incoming booking requests (accept/reject queue).
final incomingBookingsProvider = FutureProvider<List<MockBooking>>((ref) async {
  if (AppConfig.useMock) return mockBookings();
  return (await ref.watch(bookingsServiceProvider).incoming()).data;
});

/// Driver's own published trips.
final myTripsProvider = FutureProvider<List<TripCardItem>>((ref) async {
  if (AppConfig.useMock) return mockTrips().take(4).toList();
  return (await ref.watch(tripsServiceProvider).mine()).data;
});

/// Passenger's own posted ride requests.
final myRequestsProvider = FutureProvider<List<PassengerRequestItem>>((ref) async {
  if (AppConfig.useMock) return mockRequests();
  return (await ref.watch(requestsServiceProvider).mine()).data;
});

/// Car catalog — brands (cached reference data for the make/model pickers).
final carBrandsProvider = FutureProvider<List<CarBrand>>((ref) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(carsServiceProvider).brands();
});

/// Models for a selected brand.
final carModelsProvider = FutureProvider.family<List<CarModel>, int>((ref, brandId) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(carsServiceProvider).models(brandId);
});

/// Car catalog — colours (name + hex swatch).
final carColorsProvider = FutureProvider<List<CarColor>>((ref) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(carsServiceProvider).colors();
});

/// Driver's registered cars.
final carsProvider = FutureProvider<List<Car>>((ref) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(carsServiceProvider).list();
});

/// Driver verification status ({ status, ... }).
final driverStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  if (AppConfig.useMock) return const {'status': 'none'};
  return ref.watch(driversServiceProvider).status();
});

/// Public profile of another user (/users/{id}).
final publicProfileProvider = FutureProvider.family<SelfUser, String>((ref, id) async {
  return ref.watch(usersServiceProvider).publicProfile(id);
});

/// Reviews left about a user (/users/{id}/ratings).
final userRatingsProvider = FutureProvider.family<List<Review>, String>((ref, id) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(usersServiceProvider).ratings(id);
});

/// Liked trips — powers the passenger «Избранное» tab (/users/me/likes?type=trip).
final likedTripsProvider = FutureProvider<List<TripCardItem>>((ref) async {
  if (AppConfig.useMock) return mockTrips().where((t) => t.liked).toList();
  return (await ref.watch(likesServiceProvider).trips()).data;
});

/// Liked passenger requests — driver «Избранное» tab (/users/me/likes?type=passenger_request).
final likedRequestsProvider = FutureProvider<List<PassengerRequestItem>>((ref) async {
  if (AppConfig.useMock) return mockRequests().where((r) => r.liked).toList();
  return (await ref.watch(likesServiceProvider).requests()).data;
});

/// Trips awaiting the current user's rating (/ratings/pending).
final pendingRatingsProvider = FutureProvider<List<PendingRating>>((ref) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(ratingsServiceProvider).pending();
});

/// Driver performance summary (/drivers/me/stats).
final driverStatsProvider = FutureProvider<DriverStats>((ref) async {
  if (AppConfig.useMock) {
    return const DriverStats(totalTrips: 0, rating: null, ratingCount: 0, cancellations30d: 0);
  }
  return ref.watch(driversServiceProvider).stats();
});

/// Driver offers on a passenger request — owner-only responses list
/// (/passenger-requests/{id}/responses).
final requestResponsesProvider = FutureProvider.family<List<RequestResponse>, String>((ref, requestId) async {
  if (AppConfig.useMock) return const [];
  return ref.watch(requestsServiceProvider).responses(requestId);
});

/// Unread notification count for the badge.
final unreadNotifProvider = FutureProvider<int>((ref) async {
  if (AppConfig.useMock) return 0;
  return ref.watch(notificationsServiceProvider).unreadCount();
});

/// Total unread chat messages for the nav badge.
final unreadChatProvider = FutureProvider<int>((ref) async {
  if (AppConfig.useMock) return 0;
  return ref.watch(chatServiceProvider).unreadTotal();
});
