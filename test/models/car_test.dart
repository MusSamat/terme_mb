import 'package:flutter_test/flutter_test.dart';
import 'package:tappjet_mb/models/car.dart';

void main() {
  group('Car.fromJson', () {
    final c = Car.fromJson({
      'id': 'c1',
      'make': 'Toyota',
      'model': 'Camry',
      'plate': '01KG777',
      'color': 'белый',
      'seatsCount': 3,
    });

    test('id', () => expect(c.id, 'c1'));
    test('make', () => expect(c.make, 'Toyota'));
    test('model', () => expect(c.model, 'Camry'));
    test('plate', () => expect(c.plate, '01KG777'));
    test('color', () => expect(c.color, 'белый'));
    test('seatsCount', () => expect(c.seatsCount, 3));
    test('title = make + model', () => expect(c.title, 'Toyota Camry'));
  });

  group('Car.fromJson — defaults', () {
    final c = Car.fromJson({'id': 'c2'});
    test('make empty', () => expect(c.make, ''));
    test('model empty', () => expect(c.model, ''));
    test('plate empty', () => expect(c.plate, ''));
    test('color null', () => expect(c.color, isNull));
    test('seatsCount defaults to 4', () => expect(c.seatsCount, 4));
    test('title with empty parts is a lone space', () => expect(c.title, ' '));
  });

  group('Car constructor', () {
    const c = Car(id: 'c3', make: 'Kia', model: 'Rio', plate: 'X');
    test('default seats 4', () => expect(c.seatsCount, 4));
    test('color null by default', () => expect(c.color, isNull));
    test('title', () => expect(c.title, 'Kia Rio'));
  });
}
