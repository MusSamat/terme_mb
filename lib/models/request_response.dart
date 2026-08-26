import 'trip_card_item.dart' show TripDriver;

/// A driver's offer on a passenger request (GET /passenger-requests/{id}/responses).
/// Mirror of the web `RequestResponse` type.
class RequestResponse {
  const RequestResponse({
    required this.id,
    required this.requestId,
    required this.driverId,
    required this.price,
    required this.departureTime,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.driver,
    this.message,
    this.bookingId,
  });

  final String id;
  final String requestId;
  final String driverId;
  final int price;
  final String departureTime;
  final String? message;
  final String status; // pending | accepted | declined | expired
  final String? bookingId;
  final String expiresAt;
  final String createdAt;
  final TripDriver driver;

  bool get isPending => status == 'pending';

  factory RequestResponse.fromJson(Map<String, dynamic> j) => RequestResponse(
        id: (j['id'] ?? '') as String,
        requestId: (j['requestId'] ?? '') as String,
        driverId: (j['driverId'] ?? '') as String,
        price: ((j['price'] ?? 0) as num).toInt(),
        departureTime: (j['departureTime'] ?? '') as String,
        message: j['message'] as String?,
        status: (j['status'] ?? 'pending') as String,
        bookingId: j['bookingId'] as String?,
        expiresAt: (j['expiresAt'] ?? '') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        driver: TripDriver.fromJson((j['driver'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}
