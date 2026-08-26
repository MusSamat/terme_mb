import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/api/paged_result.dart';

class _Item {
  _Item(this.id);
  final String id;
  static _Item fromJson(Map<String, dynamic> j) => _Item(j['id'] as String);
}

void main() {
  group('PagedResult.fromJson', () {
    test('parses data list', () {
      final p = PagedResult.fromJson({
        'data': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      }, _Item.fromJson);
      expect(p.data.map((e) => e.id), ['a', 'b']);
    });

    test('nextCursor parsed', () {
      final p = PagedResult.fromJson({'data': [], 'nextCursor': 'cur123'}, _Item.fromJson);
      expect(p.nextCursor, 'cur123');
    });

    test('nextCursor null when absent', () {
      final p = PagedResult.fromJson({'data': []}, _Item.fromJson);
      expect(p.nextCursor, isNull);
    });

    test('nearby true when flagged', () {
      final p = PagedResult.fromJson({'data': [], 'nearby': true}, _Item.fromJson);
      expect(p.nearby, true);
    });

    test('nearby false when absent', () {
      final p = PagedResult.fromJson({'data': []}, _Item.fromJson);
      expect(p.nearby, false);
    });

    test('nearby false when value is not literally true', () {
      final p = PagedResult.fromJson({'data': [], 'nearby': 'yes'}, _Item.fromJson);
      expect(p.nearby, false);
    });

    test('data missing → empty list', () {
      final p = PagedResult.fromJson({}, _Item.fromJson);
      expect(p.data, isEmpty);
    });

    test('data null → empty list', () {
      final p = PagedResult.fromJson({'data': null}, _Item.fromJson);
      expect(p.data, isEmpty);
    });
  });

  group('PagedResult.hasMore', () {
    test('true when nextCursor present', () {
      const p = PagedResult<_Item>(data: [], nextCursor: 'x');
      expect(p.hasMore, true);
    });
    test('false when nextCursor null', () {
      const p = PagedResult<_Item>(data: []);
      expect(p.hasMore, false);
    });
  });

  group('PagedResult constructor', () {
    test('nearby defaults false', () {
      const p = PagedResult<_Item>(data: []);
      expect(p.nearby, false);
    });
  });
}
