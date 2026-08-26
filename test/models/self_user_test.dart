import 'package:flutter_test/flutter_test.dart';
import 'package:tappjet_mb/models/self_user.dart';

void main() {
  group('SelfUser.fromJson — full', () {
    final u = SelfUser.fromJson({
      'id': 'u1',
      'name': 'Азамат',
      'surname': 'Асанов',
      'roles': ['passenger', 'driver'],
      'phone': '+996700111222',
      'phoneVerified': true,
      'telegramLinked': true,
      'language': 'kg',
      'bio': 'Водитель со стажем',
      'avatarUrl': 'https://x/a.png',
      'rating': 4.85,
      'ratingCount': 40,
      'loyaltyTier': 'gold',
      'loyaltyPoints': 320,
      'notificationsEnabled': false,
      'createdAt': '2024-03-15T10:00:00Z',
    });

    test('id', () => expect(u.id, 'u1'));
    test('name', () => expect(u.name, 'Азамат'));
    test('surname', () => expect(u.surname, 'Асанов'));
    test('roles', () => expect(u.roles, ['passenger', 'driver']));
    test('phone', () => expect(u.phone, '+996700111222'));
    test('phoneVerified', () => expect(u.phoneVerified, true));
    test('telegramLinked', () => expect(u.telegramLinked, true));
    test('language', () => expect(u.language, 'kg'));
    test('bio', () => expect(u.bio, 'Водитель со стажем'));
    test('avatarUrl', () => expect(u.avatarUrl, 'https://x/a.png'));
    test('rating', () => expect(u.rating, 4.85));
    test('ratingCount', () => expect(u.ratingCount, 40));
    test('loyaltyTier', () => expect(u.loyaltyTier, 'gold'));
    test('loyaltyPoints', () => expect(u.loyaltyPoints, 320));
    test('notificationsEnabled', () => expect(u.notificationsEnabled, false));
    test('createdAt parsed', () => expect(u.createdAt, isNotNull));
    test('joinYear from createdAt', () => expect(u.joinYear, 2024));
  });

  group('SelfUser derived roles', () {
    test('isDriver true when driver in roles', () {
      final u = SelfUser.fromJson({'id': 'u', 'roles': ['driver']});
      expect(u.isDriver, true);
    });
    test('isDriver false without driver role', () {
      final u = SelfUser.fromJson({'id': 'u', 'roles': ['passenger']});
      expect(u.isDriver, false);
    });
    test('isPassenger true when passenger in roles', () {
      final u = SelfUser.fromJson({'id': 'u', 'roles': ['passenger']});
      expect(u.isPassenger, true);
    });
    test('isPassenger false without passenger role', () {
      final u = SelfUser.fromJson({'id': 'u', 'roles': ['driver']});
      expect(u.isPassenger, false);
    });
    test('both roles → driver and passenger', () {
      final u = SelfUser.fromJson({'id': 'u', 'roles': ['passenger', 'driver']});
      expect(u.isDriver && u.isPassenger, true);
    });
  });

  group('SelfUser.fromJson — defaults', () {
    final u = SelfUser.fromJson({'id': 'u2'});
    test('name empty', () => expect(u.name, ''));
    test('surname null', () => expect(u.surname, isNull));
    test('roles empty', () => expect(u.roles, isEmpty));
    test('phone empty', () => expect(u.phone, ''));
    test('phoneVerified false', () => expect(u.phoneVerified, false));
    test('telegramLinked false', () => expect(u.telegramLinked, false));
    test('language defaults ru', () => expect(u.language, 'ru'));
    test('bio null', () => expect(u.bio, isNull));
    test('rating null', () => expect(u.rating, isNull));
    test('ratingCount 0', () => expect(u.ratingCount, 0));
    test('loyaltyTier novice', () => expect(u.loyaltyTier, 'novice'));
    test('loyaltyPoints 0', () => expect(u.loyaltyPoints, 0));
    test('notificationsEnabled true', () => expect(u.notificationsEnabled, true));
    test('createdAt null', () => expect(u.createdAt, isNull));
    test('joinYear null when no createdAt', () => expect(u.joinYear, isNull));
    test('isDriver false', () => expect(u.isDriver, false));
    test('isPassenger false', () => expect(u.isPassenger, false));
  });

  group('SelfUser — numeric coercion', () {
    test('rating from int', () {
      final u = SelfUser.fromJson({'id': 'u', 'rating': 5});
      expect(u.rating, 5.0);
    });
    test('malformed createdAt → null', () {
      final u = SelfUser.fromJson({'id': 'u', 'createdAt': 'nope'});
      expect(u.createdAt, isNull);
    });
  });
}
