/// One page of a paginated list endpoint.
///
/// Mirrors the backend's envelope:
///
/// ```json
/// { "success": true,
///   "hacks": [ /* 7 items */ ],
///   "pagination": {"page": 1, "limit": 7, "total": 20, "has_more": true} }
/// ```
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int limit;

  /// Total across all pages, where the server reports it. Null means
  /// unknown — never render a "x of y" count from a guess.
  final int? total;

  /// Whether another page exists.
  final bool hasMore;

  const PagedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  /// Reads the `pagination` block, tolerating its absence.
  ///
  /// The endpoint gained pagination after the app shipped, so a deployment
  /// without it returns the whole list and no `pagination` at all. Falling
  /// back to "a full page probably means more follows" keeps both
  /// deployments working: an unpaginated response comes back longer than
  /// the limit, is treated as complete, and the scroll simply never asks
  /// for page 2.
  static PagedResult<Map<String, dynamic>> fromEnvelope(
    Map<String, dynamic> body, {
    required String itemsKey,
    required int requestedPage,
    required int requestedLimit,
  }) {
    final rawItems = body[itemsKey];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final meta = body['pagination'];
    if (meta is! Map) {
      return PagedResult(
        items: items,
        page: requestedPage,
        limit: requestedLimit,
        total: null,
        // Without a server signal, only a page filled to the brim suggests
        // there is more. An unpaginated response returns everything at
        // once, which is longer than the limit and so ends the scroll.
        hasMore: items.length == requestedLimit,
      );
    }

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final total = asInt(meta['total']);
    final page = asInt(meta['page']) ?? requestedPage;
    final limit = asInt(meta['limit']) ?? requestedLimit;

    // Prefer the explicit flag; derive it only if the server omitted it.
    final flag = meta['has_more'] ?? meta['hasMore'];
    final hasMore = flag is bool
        ? flag
        : (total != null && page * limit < total);

    return PagedResult(
      items: items,
      page: page,
      limit: limit,
      total: total,
      hasMore: hasMore,
    );
  }

  PagedResult<R> map<R>(R Function(T) transform) => PagedResult<R>(
    items: items.map(transform).toList(),
    page: page,
    limit: limit,
    total: total,
    hasMore: hasMore,
  );
}
