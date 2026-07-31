import '../models/passenger_request.dart';

// Sample passenger requests for the driver-facing feed. Removed in ТЗ step 2.
List<PassengerRequestItem> mockRequests() => const [
      PassengerRequestItem(
        id: 'r1',
        originCity: 'Бишкек',
        destinationCity: 'Ош',
        seatsNeeded: 2,
        dateLabel: 'Сегодня, после 18:00',
        budget: 1200,
        passengerName: 'Айгерим',
        passengerRating: 4.9,
        passengerRatingCount: 15,
        passengerVerified: true,
        comment: 'Едем вдвоём с сестрой, немного вещей. Можно выехать вечером.',
      ),
      PassengerRequestItem(
        id: 'r2',
        originCity: 'Каракол',
        destinationCity: 'Бишкек',
        seatsNeeded: 1,
        dateLabel: 'Завтра, утром',
        budget: 800,
        passengerName: 'Данияр',
        passengerRatingCount: 0,
        responded: true,
      ),
      PassengerRequestItem(
        id: 'r3',
        originCity: 'Ош',
        destinationCity: 'Джалал-Абад',
        seatsNeeded: 3,
        dateLabel: 'Сегодня',
        budget: 350,
        passengerName: 'Гүлнара',
        passengerRating: 5.0,
        passengerRatingCount: 8,
        passengerVerified: true,
        comment: 'Семья с ребёнком, нужен просторный багажник.',
      ),
    ];

PassengerRequestItem mockRequestById(String id) {
  final list = mockRequests();
  return list.firstWhere((r) => r.id == id, orElse: () => list.first);
}
