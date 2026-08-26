import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/utils/api_format.dart';

void main() {
  group('apiFeedDate', () {
    test('"any" → null (explicit no-filter)', () => expect(apiFeedDate('any'), isNull));
    test('explicit date keeps its day + gets offset', () {
      expect(apiFeedDate('2026-08-03'), '2026-08-03T00:00:00+06:00');
    });
    test('empty → today with offset', () {
      expect(apiFeedDate('', now: DateTime(2026, 8, 3)), '2026-08-03T00:00:00+06:00');
    });
    test('always +06:00 for non-null', () {
      for (final d in ['2026-01-09', '2026-12-31', '']) {
        expect(apiFeedDate(d, now: DateTime(2026, 6, 1)), endsWith('+06:00'));
      }
    });
    test('never a bare YYYY-MM-DD (always has T)', () {
      expect(apiFeedDate('2026-05-05'), contains('T00:00:00'));
    });
    test('single-digit month/day zero-padded for today', () {
      expect(apiFeedDate('', now: DateTime(2026, 3, 5)), '2026-03-05T00:00:00+06:00');
    });
  });

  group('ymdOf', () {
    test('zero-pads month and day', () {
      expect(ymdOf(DateTime(2026, 1, 2)), '2026-01-02');
    });
    test('double-digit unchanged', () {
      expect(ymdOf(DateTime(2026, 11, 25)), '2026-11-25');
    });
    test('pads year to 4 digits', () {
      expect(ymdOf(DateTime(7, 6, 5)), '0007-06-05');
    });
    test('last day of year', () {
      expect(ymdOf(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('stripLeadingZeros', () {
    test('drops multiple leading zeros', () => expect(stripLeadingZeros('00500'), '500'));
    test('drops single leading zero', () => expect(stripLeadingZeros('0500'), '500'));
    test('lone zero kept (mid-typing)', () => expect(stripLeadingZeros('0'), '0'));
    test('normal untouched', () => expect(stripLeadingZeros('1200'), '1200'));
    test('empty stays empty', () => expect(stripLeadingZeros(''), ''));
    test('all zeros collapse to empty then... "000" → ""', () {
      // "000" starts with 0 and length>1 → replaceFirst ^0+ removes all → ''
      expect(stripLeadingZeros('000'), '');
    });
    test('no leading zero returns same instance value', () {
      expect(stripLeadingZeros('9'), '9');
    });
  });
}
