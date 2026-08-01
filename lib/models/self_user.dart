/// Minimal hand-written model for the skeleton. Full freezed models (mirroring
/// tappjet_ft/src/lib/api/schema.gen.ts) land in step 2 of the ТЗ.
class SelfUser {
  const SelfUser({
    required this.id,
    required this.name,
    required this.roles,
    required this.phone,
    required this.phoneVerified,
    required this.telegramLinked,
    required this.language,
    this.avatarUrl,
    this.rating,
    this.ratingCount = 0,
    this.loyaltyTier = 'novice',
    this.loyaltyPoints = 0,
    this.notificationsEnabled = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final List<String> roles;
  final String phone;
  final bool phoneVerified;
  final bool telegramLinked;
  final String language; // 'ru' | 'kg'
  final String? avatarUrl;
  final double? rating;
  final int ratingCount;
  final String loyaltyTier;
  final int loyaltyPoints;
  final bool notificationsEnabled;
  final DateTime? createdAt;

  int? get joinYear => createdAt?.year;

  bool get isDriver => roles.contains('driver');
  bool get isPassenger => roles.contains('passenger');

  factory SelfUser.fromJson(Map<String, dynamic> j) => SelfUser(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        roles: (j['roles'] as List?)?.cast<String>() ?? const [],
        phone: (j['phone'] ?? '') as String,
        phoneVerified: (j['phoneVerified'] ?? false) as bool,
        telegramLinked: (j['telegramLinked'] ?? false) as bool,
        language: (j['language'] ?? 'ru') as String,
        avatarUrl: j['avatarUrl'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['ratingCount'] ?? 0) as int,
        loyaltyTier: (j['loyaltyTier'] ?? 'novice') as String,
        loyaltyPoints: (j['loyaltyPoints'] ?? 0) as int,
        notificationsEnabled: (j['notificationsEnabled'] ?? true) as bool,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}
