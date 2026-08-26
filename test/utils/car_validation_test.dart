import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/utils/car_validation.dart';

void main() {
  group('normalizePlate', () {
    test('uppercases', () => expect(CarValidation.normalizePlate('01kg123'), '01KG123'));
    test('strips spaces and symbols', () => expect(CarValidation.normalizePlate('01 KG-123 ABC'), '01KG123ABC'));
    test('clamps to 10 chars', () => expect(CarValidation.normalizePlate('012345678901234'), '0123456789'));
    test('empty stays empty', () => expect(CarValidation.normalizePlate(''), ''));
    test('cyrillic dropped', () => expect(CarValidation.normalizePlate('АВ123'), '123'));
  });

  group('plateValid', () {
    test('4 chars valid', () => expect(CarValidation.plateValid('01KG'), true));
    test('10 chars valid', () => expect(CarValidation.plateValid('01KG123ABC'), true));
    test('3 chars invalid', () => expect(CarValidation.plateValid('01K'), false));
    test('11 chars → normalized to 10 → valid', () => expect(CarValidation.plateValid('01KG123ABCD'), true));
    test('lowercase accepted (normalized)', () => expect(CarValidation.plateValid('01kg123'), true));
    test('with spaces accepted (normalized)', () => expect(CarValidation.plateValid('01 KG 123'), true));
    test('empty invalid', () => expect(CarValidation.plateValid(''), false));
    test('only-symbols invalid', () => expect(CarValidation.plateValid('---'), false));
  });

  group('yearValid', () {
    test('2000 valid (min year)', () => expect(CarValidation.yearValid('2000', maxYear: 2026), true));
    test('current year valid', () => expect(CarValidation.yearValid('2026', maxYear: 2026), true));
    test('1999 invalid (too old)', () => expect(CarValidation.yearValid('1999', maxYear: 2026), false));
    test('future invalid', () => expect(CarValidation.yearValid('2027', maxYear: 2026), false));
    test('non-numeric invalid', () => expect(CarValidation.yearValid('abcd', maxYear: 2026), false));
    test('empty invalid', () => expect(CarValidation.yearValid('', maxYear: 2026), false));
    test('whitespace trimmed', () => expect(CarValidation.yearValid('  2000  ', maxYear: 2026), true));
    test('defaults maxYear to now (a past year is valid)', () => expect(CarValidation.yearValid('2000'), true));
  });

  group('non-empty fields', () {
    test('make empty invalid', () => expect(CarValidation.makeValid('  '), false));
    test('make valid', () => expect(CarValidation.makeValid('Toyota'), true));
    test('model valid', () => expect(CarValidation.modelValid('Camry'), true));
    test('color empty invalid', () => expect(CarValidation.colorValid(''), false));
    test('color valid', () => expect(CarValidation.colorValid('белый'), true));
  });

  group('seatsValid', () {
    test('1 valid', () => expect(CarValidation.seatsValid(1), true));
    test('7 valid', () => expect(CarValidation.seatsValid(7), true));
    test('0 invalid', () => expect(CarValidation.seatsValid(0), false));
    test('8 invalid', () => expect(CarValidation.seatsValid(8), false));
  });
}
