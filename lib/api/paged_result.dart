/// Cursor-paginated list response — `{ data: [...], nextCursor, nearby? }`.
/// Every list endpoint in the backend returns this shape (ТЗ §5.3).
class PagedResult<T> {
  const PagedResult({required this.data, this.nextCursor, this.nearby});

  final List<T> data;
  final String? nextCursor;
  final List<T>? nearby;

  bool get hasMore => nextCursor != null;

  static PagedResult<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    List<T> parse(Object? raw) =>
        (raw as List? ?? const []).map((e) => itemFromJson(e as Map<String, dynamic>)).toList();
    return PagedResult<T>(
      data: parse(json['data']),
      nextCursor: json['nextCursor'] as String?,
      nearby: json['nearby'] != null ? parse(json['nearby']) : null,
    );
  }
}
