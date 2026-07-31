import '../models/trip_card_item.dart';

/// Temporary in-memory sample data so the feed renders without a backend.
/// Removed once trips_api + providers land (ТЗ step 2).
List<TripCardItem> mockTrips() {
  final now = DateTime.now();
  DateTime at(int addDays, int h, int m) =>
      DateTime(now.year, now.month, now.day + addDays, h, m);

  return [
    TripCardItem(
      id: 't1',
      originCity: 'Бишкек',
      destinationCity: 'Ош',
      departureAt: at(0, 6, 0),
      seatsAvailable: 3,
      seatsTotal: 4,
      pricePerSeat: 1200,
      pickupCities: const ['Кара-Балта', 'Токтогул'],
      instant: true,
      driver: const TripDriver(
        id: 'd1',
        name: 'Азамат Кыдыров',
        rating: 4.9,
        ratingCount: 128,
        verified: true,
        car: TripCar(make: 'Toyota', model: 'Camry', plate: '01KG777'),
      ),
    ),
    TripCardItem(
      id: 't2',
      originCity: 'Ош',
      destinationCity: 'Джалал-Абад',
      departureAt: at(0, 9, 30),
      seatsAvailable: 1,
      seatsTotal: 4,
      pricePerSeat: 350,
      driver: const TripDriver(
        id: 'd2',
        name: 'Нургуль С.',
        rating: 4.7,
        ratingCount: 41,
        car: TripCar(make: 'Honda', model: 'Fit'),
      ),
    ),
    TripCardItem(
      id: 't3',
      originCity: 'Бишкек',
      destinationCity: 'Каракол',
      departureAt: at(1, 7, 15),
      departureWindowEnd: DateTime(now.year, now.month, now.day + 1, 8, 30),
      seatsAvailable: 4,
      seatsTotal: 4,
      pricePerSeat: 800,
      wholeCabin: true,
      liked: true,
      driver: const TripDriver(
        id: 'd3',
        name: 'Тимур',
        ratingCount: 0,
        car: TripCar(make: 'Hyundai', model: 'Starex'),
      ),
    ),
    TripCardItem(
      id: 't4',
      originCity: 'Талас',
      destinationCity: 'Бишкек',
      departureAt: at(1, 14, 0),
      seatsAvailable: 0,
      seatsTotal: 3,
      pricePerSeat: 700,
      driver: const TripDriver(
        id: 'd4',
        name: 'Бек Осмонов',
        rating: 5.0,
        ratingCount: 12,
        verified: true,
        car: TripCar(make: 'Toyota', model: 'Prius'),
      ),
    ),
    TripCardItem(
      id: 't5',
      originCity: 'Бишкек',
      destinationCity: 'Нарын',
      departureAt: at(2, 8, 0),
      seatsAvailable: 2,
      seatsTotal: 4,
      pricePerSeat: 900,
      driver: const TripDriver(
        id: 'd5',
        name: 'Эркин',
        rating: 4.5,
        ratingCount: 7,
        car: TripCar(make: 'Mercedes', model: 'Sprinter'),
      ),
    ),
  ];
}
