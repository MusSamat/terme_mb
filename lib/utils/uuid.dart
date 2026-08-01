import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Fresh v4 UUID — used for Idempotency-Key headers on POST trips/bookings.
String uuidV4() => _uuid.v4();
