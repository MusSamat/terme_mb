/// Engagement counters for a listing — non-null ONLY when the viewer is the
/// listing's creator (backend returns null otherwise). Mirrors the web
/// EngagementFields.metrics { views, likes, contacts }.
class Metrics {
  const Metrics({required this.views, required this.likes, required this.contacts});
  final int views;
  final int likes;
  final int contacts;

  static Metrics? fromJson(dynamic j) {
    if (j is! Map) return null;
    final m = j.cast<String, dynamic>();
    return Metrics(
      views: (m['views'] ?? 0) as int,
      likes: (m['likes'] ?? 0) as int,
      contacts: (m['contacts'] ?? 0) as int,
    );
  }
}
