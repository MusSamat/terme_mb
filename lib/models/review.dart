/// A public rating/review left about a user (GET /users/{id}/ratings).
class Review {
  const Review({
    required this.id,
    required this.raterName,
    required this.score,
    this.avatarUrl,
    this.tags = const [],
    this.comment,
    this.createdAt,
  });

  final String id;
  final String raterName;
  final int score;
  final String? avatarUrl;
  final List<String> tags;
  final String? comment;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) {
    final rater = (j['rater'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Review(
      id: (j['id'] ?? '') as String,
      raterName: (rater['name'] ?? '') as String,
      avatarUrl: rater['avatarUrl'] as String?,
      score: (j['score'] ?? 0) as int,
      tags: (j['tags'] as List?)?.cast<String>() ?? const [],
      comment: j['comment'] as String?,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
    );
  }
}
