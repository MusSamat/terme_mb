import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/models/feed_filters.dart';

void main() {
  group('FeedFilters defaults', () {
    const f = FeedFilters();
    test('from empty', () => expect(f.from, ''));
    test('to empty', () => expect(f.to, ''));
    test('date empty (today)', () => expect(f.date, ''));
    test('sort time', () => expect(f.sort, 'time'));
    test('onlyVerified false', () => expect(f.onlyVerified, false));
    test('luggage empty', () => expect(f.luggage, ''));
    test('minRating 0', () => expect(f.minRating, 0));
    test('minPrice null', () => expect(f.minPrice, isNull));
    test('maxPrice null', () => expect(f.maxPrice, isNull));
    test('womenOnly false', () => expect(f.womenOnly, false));
    test('noSmoking false', () => expect(f.noSmoking, false));
    test('pets false', () => expect(f.pets, false));
    test('activeCount 0 by default', () => expect(f.activeCount, 0));
  });

  group('FeedFilters.copyWith — each field', () {
    const base = FeedFilters();
    test('from', () => expect(base.copyWith(from: 'Бишкек').from, 'Бишкек'));
    test('to', () => expect(base.copyWith(to: 'Ош').to, 'Ош'));
    test('date', () => expect(base.copyWith(date: '2026-08-05').date, '2026-08-05'));
    test('sort', () => expect(base.copyWith(sort: 'price_asc').sort, 'price_asc'));
    test('onlyVerified', () => expect(base.copyWith(onlyVerified: true).onlyVerified, true));
    test('luggage', () => expect(base.copyWith(luggage: 'yes').luggage, 'yes'));
    test('minRating', () => expect(base.copyWith(minRating: 4.5).minRating, 4.5));
    test('minPrice', () => expect(base.copyWith(minPrice: 100).minPrice, 100));
    test('maxPrice', () => expect(base.copyWith(maxPrice: 2000).maxPrice, 2000));
    test('womenOnly', () => expect(base.copyWith(womenOnly: true).womenOnly, true));
    test('noSmoking', () => expect(base.copyWith(noSmoking: true).noSmoking, true));
    test('pets', () => expect(base.copyWith(pets: true).pets, true));
  });

  group('FeedFilters.copyWith — preserves untouched fields', () {
    const base = FeedFilters(from: 'A', to: 'B', sort: 'rating_desc', onlyVerified: true, minPrice: 50);
    final next = base.copyWith(to: 'C');
    test('changed field updates', () => expect(next.to, 'C'));
    test('from preserved', () => expect(next.from, 'A'));
    test('sort preserved', () => expect(next.sort, 'rating_desc'));
    test('onlyVerified preserved', () => expect(next.onlyVerified, true));
    test('minPrice preserved', () => expect(next.minPrice, 50));
  });

  group('FeedFilters.copyWith — clear flags', () {
    const base = FeedFilters(minPrice: 100, maxPrice: 2000);
    test('clearMinPrice nulls minPrice', () {
      expect(base.copyWith(clearMinPrice: true).minPrice, isNull);
    });
    test('clearMinPrice keeps maxPrice', () {
      expect(base.copyWith(clearMinPrice: true).maxPrice, 2000);
    });
    test('clearMaxPrice nulls maxPrice', () {
      expect(base.copyWith(clearMaxPrice: true).maxPrice, isNull);
    });
    test('clearMaxPrice keeps minPrice', () {
      expect(base.copyWith(clearMaxPrice: true).minPrice, 100);
    });
    test('clear beats a passed value (clearMinPrice wins)', () {
      expect(base.copyWith(minPrice: 999, clearMinPrice: true).minPrice, isNull);
    });
    test('both clears null both', () {
      final c = base.copyWith(clearMinPrice: true, clearMaxPrice: true);
      expect(c.minPrice, isNull);
      expect(c.maxPrice, isNull);
    });
  });

  group('FeedFilters.activeCount — each contributor adds 1', () {
    const base = FeedFilters();
    test('onlyVerified', () => expect(base.copyWith(onlyVerified: true).activeCount, 1));
    test('luggage', () => expect(base.copyWith(luggage: 'small').activeCount, 1));
    test('minRating > 0', () => expect(base.copyWith(minRating: 3).activeCount, 1));
    test('minRating 0 does NOT count', () => expect(base.copyWith(minRating: 0).activeCount, 0));
    test('minPrice only', () => expect(base.copyWith(minPrice: 100).activeCount, 1));
    test('maxPrice only', () => expect(base.copyWith(maxPrice: 100).activeCount, 1));
    test('both price bounds count once', () {
      expect(base.copyWith(minPrice: 100, maxPrice: 2000).activeCount, 1);
    });
    test('womenOnly', () => expect(base.copyWith(womenOnly: true).activeCount, 1));
    test('noSmoking', () => expect(base.copyWith(noSmoking: true).activeCount, 1));
    test('pets', () => expect(base.copyWith(pets: true).activeCount, 1));
    test('sort != time counts', () => expect(base.copyWith(sort: 'price_asc').activeCount, 1));
    test('sort == time does NOT count', () => expect(base.copyWith(sort: 'time').activeCount, 0));
    test('from/to do NOT count toward activeCount', () {
      expect(base.copyWith(from: 'A', to: 'B').activeCount, 0);
    });
    test('date does NOT count toward activeCount', () {
      expect(base.copyWith(date: '2026-08-05').activeCount, 0);
    });
  });

  group('FeedFilters.activeCount — combinations', () {
    test('all filters on → 8', () {
      const f = FeedFilters(
        onlyVerified: true,
        luggage: 'yes',
        minRating: 4,
        minPrice: 100,
        maxPrice: 2000,
        womenOnly: true,
        noSmoking: true,
        pets: true,
        sort: 'price_asc',
      );
      expect(f.activeCount, 8);
    });
    test('three filters → 3', () {
      const f = FeedFilters(onlyVerified: true, womenOnly: true, pets: true);
      expect(f.activeCount, 3);
    });
  });
}
