import 'package:flutter_test/flutter_test.dart';
import 'package:tappjet_mb/models/review.dart';

void main() {
  group('Review.fromJson — full', () {
    final r = Review.fromJson({
      'id': 'rev1',
      'score': 5,
      'tags': ['punctual', 'friendly'],
      'comment': 'Отличный водитель',
      'createdAt': '2026-07-01T12:00:00Z',
      'rater': {'name': 'Мария', 'avatarUrl': 'https://x/m.png'},
    });

    test('id', () => expect(r.id, 'rev1'));
    test('score', () => expect(r.score, 5));
    test('tags', () => expect(r.tags, ['punctual', 'friendly']));
    test('comment', () => expect(r.comment, 'Отличный водитель'));
    test('raterName from nested rater', () => expect(r.raterName, 'Мария'));
    test('avatarUrl from nested rater', () => expect(r.avatarUrl, 'https://x/m.png'));
    test('createdAt parsed (UTC preserved)', () => expect(r.createdAt, DateTime.utc(2026, 7, 1, 12)));
  });

  group('Review.fromJson — defaults', () {
    final r = Review.fromJson({'id': 'rev2'});
    test('score defaults 0', () => expect(r.score, 0));
    test('tags empty', () => expect(r.tags, isEmpty));
    test('comment null', () => expect(r.comment, isNull));
    test('raterName empty when no rater', () => expect(r.raterName, ''));
    test('avatarUrl null', () => expect(r.avatarUrl, isNull));
    test('createdAt null', () => expect(r.createdAt, isNull));
  });

  group('Review.fromJson — edge', () {
    test('empty rater map → blank name', () {
      final r = Review.fromJson({'id': 'x', 'rater': {}});
      expect(r.raterName, '');
    });
    test('malformed createdAt → null (tryParse)', () {
      final r = Review.fromJson({'id': 'x', 'createdAt': 'not-a-date'});
      expect(r.createdAt, isNull);
    });
    test('tags of wrong type default to empty', () {
      final r = Review.fromJson({'id': 'x'});
      expect(r.tags, isEmpty);
    });
  });

  group('Review constructor', () {
    const r = Review(id: 'c', raterName: 'N', score: 4);
    test('tags default const empty', () => expect(r.tags, isEmpty));
    test('comment null', () => expect(r.comment, isNull));
  });
}
