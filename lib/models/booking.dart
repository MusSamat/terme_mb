class Booking {
  const Booking({
    required this.id,
    required this.otherName,
    required this.origin,
    required this.destination,
    required this.dateLabel,
    required this.seats,
    required this.status,
    required this.sum,
    this.verified = false,
    this.phone,
    this.comment,
    this.avatarUrl,
    this.tripId,
    this.departureAt,
  });
  final String id;
  final String? tripId; // parent trip id — used to match a pending rating
  final DateTime? departureAt; // for timeline sorting in «Мои»
  final String otherName;
  final String origin;
  final String destination;
  final String dateLabel;
  final int seats;
  final String status; // key under status.*
  final int sum;
  final bool verified;
  final String? phone;
  final String? comment;
  final String? avatarUrl;

  /// [incoming] — the driver's view (/bookings/incoming): the counterpart is the
  /// passenger. Otherwise (/bookings/my) it's the trip's driver — the DTO
  /// carries both, so picking by presence would show the user themselves.
  /// With [selfId] (GET /bookings/:id, either side) the side is inferred.
  factory Booking.fromJson(Map<String, dynamic> j, {bool incoming = false, String? selfId}) {
    final trip = (j['trip'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (selfId != null) incoming = j['passengerId'] != selfId;
    final other = ((incoming ? j['passenger'] : trip['driver']) as Map?)?.cast<String, dynamic>() ?? const {};
    final dep = trip['departureAt'] != null ? DateTime.tryParse(trip['departureAt'] as String)?.toLocal() : null;
    return Booking(
      id: j['id'] as String,
      tripId: (j['tripId'] ?? trip['id']) as String?,
      departureAt: dep,
      otherName: (other['name'] ?? '') as String,
      origin: (trip['originCity'] ?? '') as String,
      destination: (trip['destinationCity'] ?? '') as String,
      dateLabel: dep != null ? '${dep.day.toString().padLeft(2, '0')}.${dep.month.toString().padLeft(2, '0')}' : '',
      seats: (j['seatsCount'] ?? 1) as int,
      status: (j['status'] ?? 'pending') as String,
      // Total = price frozen at booking time (pricePerSeatSnapshot) × seats;
      // legacy rows without a snapshot fall back to the trip's live price.
      sum: (((j['pricePerSeatSnapshot'] ?? trip['pricePerSeat'] ?? 0) as num).toInt()) *
          ((j['seatsCount'] ?? 1) as int),
      // Verified badge: the DTO has no `verified` flag — an established
      // counterparty is one with at least one rating.
      verified: ((other['ratingCount'] ?? 0) as num) > 0,
      phone: other['phone'] as String?,
      comment: j['comment'] as String?,
    );
  }
}
