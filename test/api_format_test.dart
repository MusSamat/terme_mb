import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/utils/api_format.dart';

void main() {
  group('apiFeedDate — feed date query param contract', () {
    test('"any" clears the filter (null → no date param sent)', () {
      expect(apiFeedDate('any'), isNull);
    });

    test('a picked day is sent as an ISO datetime with the +06:00 offset', () {
      // Regression: a bare "YYYY-MM-DD" is rejected by the API
      // (z.string().datetime({offset:true})) → VALIDATION_ERROR / empty list.
      expect(apiFeedDate('2026-08-03'), '2026-08-03T00:00:00+06:00');
    });

    test('empty means today — never a bare date, always with the offset', () {
      expect(apiFeedDate('', now: DateTime(2026, 8, 3)), '2026-08-03T00:00:00+06:00');
    });

    test('every non-null result carries the timezone offset', () {
      for (final d in ['2026-01-09', '2026-12-31', '']) {
        expect(apiFeedDate(d, now: DateTime(2026, 6, 1)), endsWith('+06:00'));
      }
    });

    test('single-digit month/day are zero-padded', () {
      expect(apiFeedDate('', now: DateTime(2026, 3, 5)), '2026-03-05T00:00:00+06:00');
    });
  });

  group('stripLeadingZeros — price can\'t start with 0', () {
    test('drops leading zeros', () => expect(stripLeadingZeros('0500'), '500'));
    test('a lone zero is kept (mid-typing)', () => expect(stripLeadingZeros('0'), '0'));
    test('normal input is untouched', () => expect(stripLeadingZeros('1200'), '1200'));
    test('empty stays empty', () => expect(stripLeadingZeros(''), ''));
  });
}
