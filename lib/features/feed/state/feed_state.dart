import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/paged_result.dart';

/// Which benefit list a request is for.
enum HackFeed { mine, circle }

/// One infinitely-scrolling list: the items loaded so far plus where the
/// paging has got to.
class _Feed {
  final List<Hack> items = [];

  /// The last page successfully loaded. 0 means nothing yet.
  int loadedPage = 0;

  /// Whether the server says another page exists. Starts true so the first
  /// load is allowed.
  bool hasMore = true;

  /// Ids already held, so a page that overlaps the previous one cannot
  /// insert the same benefit twice. Server-side slicing shifts items
  /// between pages whenever the underlying list changes, which is exactly
  /// how duplicate rows appear in an infinite scroll.
  final Set<String> _ids = {};

  bool isLoadingFirst = false;
  bool isLoadingMore = false;

  /// Set when a page request failed, so the list can offer a retry instead
  /// of just stopping.
  String? error;

  bool get isEmpty => items.isEmpty;

  void reset() {
    items.clear();
    _ids.clear();
    loadedPage = 0;
    hasMore = true;
    error = null;
  }

  /// Appends [incoming], skipping anything already held. Returns how many
  /// were genuinely new.
  int append(Iterable<Hack> incoming) {
    var added = 0;
    for (final hack in incoming) {
      // An item with no id cannot be de-duplicated; keep it rather than
      // dropping real content.
      if (hack.id.isEmpty || _ids.add(hack.id)) {
        items.add(hack);
        added++;
      }
    }
    return added;
  }
}

/// The benefits feed, paged Instagram-style.
///
/// Both lists are lazily paged: the screen asks for the next page as the
/// user nears the bottom, and this refuses to run two requests for the same
/// list at once. Without that guard a fast scroll fires a burst of requests
/// for the same page and the list fills with repeats.
class FeedState extends ChangeNotifier {
  final _Feed _mine = _Feed();
  final _Feed _circle = _Feed();

  FeedState() {
    loadFirstPage(HackFeed.mine);
    loadFirstPage(HackFeed.circle);
  }

  _Feed _feedFor(HackFeed which) => which == HackFeed.mine ? _mine : _circle;

  List<Hack> get myHacks => List.unmodifiable(_mine.items);
  List<Hack> get circleHacks => List.unmodifiable(_circle.items);

  List<Hack> itemsOf(HackFeed which) =>
      List.unmodifiable(_feedFor(which).items);

  bool isLoadingFirstPage(HackFeed which) => _feedFor(which).isLoadingFirst;
  bool isLoadingMore(HackFeed which) => _feedFor(which).isLoadingMore;
  bool hasMore(HackFeed which) => _feedFor(which).hasMore;
  String? errorOf(HackFeed which) => _feedFor(which).error;

  bool get isLoadingMyHacks => _mine.isLoadingFirst;
  bool get isLoadingCircleHacks => _circle.isLoadingFirst;

  /// Loads page 1, replacing whatever is held.
  ///
  /// [force] reloads even when items are already present; without it,
  /// returning to the tab keeps the scroll position and the pages already
  /// fetched.
  Future<void> loadFirstPage(HackFeed which, {bool force = false}) async {
    final feed = _feedFor(which);
    if (feed.isLoadingFirst) return;
    if (feed.items.isNotEmpty && !force) return;

    feed.isLoadingFirst = true;
    feed.error = null;
    notifyListeners();

    final page = await _request(which, 1);

    if (page == null) {
      feed.error = 'Could not load benefits. Pull to retry.';
    } else {
      // Replaced only on success, so a failed refresh does not blank a list
      // the user was already reading.
      feed.reset();
      feed.append(page.items.map(Hack.fromJson));
      feed.loadedPage = page.page;
      feed.hasMore = page.hasMore;
      LoggerService.info(
        '${which.name}: page ${page.page} -> ${feed.items.length} items, '
        'hasMore=${page.hasMore}',
      );
    }

    feed.isLoadingFirst = false;
    notifyListeners();
  }

  /// Loads the page after the last one held.
  ///
  /// Safe to call repeatedly and from a scroll listener: it returns
  /// immediately when a request is already in flight, when the list is
  /// exhausted, or while the first page is still loading.
  Future<void> loadNextPage(HackFeed which) async {
    final feed = _feedFor(which);
    if (feed.isLoadingMore || feed.isLoadingFirst || !feed.hasMore) return;

    feed.isLoadingMore = true;
    feed.error = null;
    notifyListeners();

    final next = feed.loadedPage + 1;
    final page = await _request(which, next);

    if (page == null) {
      feed.error = 'Could not load more. Tap to retry.';
    } else {
      final added = feed.append(page.items.map(Hack.fromJson));
      feed.loadedPage = page.page;
      feed.hasMore = page.hasMore;

      // A page that was entirely duplicates would leave the scroll stuck at
      // the bottom asking for the same page forever. Treat it as the end.
      if (added == 0 && page.items.isNotEmpty) {
        LoggerService.warning(
          '${which.name}: page ${page.page} was all duplicates; stopping.',
        );
        feed.hasMore = false;
      }
    }

    feed.isLoadingMore = false;
    notifyListeners();
  }

  /// Discards everything and reloads page 1 — the pull-to-refresh path.
  Future<void> refresh(HackFeed which) async {
    _feedFor(which).reset();
    await loadFirstPage(which, force: true);
  }

  Future<void> refreshAll() =>
      Future.wait([refresh(HackFeed.mine), refresh(HackFeed.circle)]);

  Future<PagedResult<Map<String, dynamic>>?> _request(
    HackFeed which,
    int page,
  ) {
    return which == HackFeed.mine
        ? ApiService.getMyHacks(page: page)
        : ApiService.getCircleHacks(page: page);
  }

  /// Swaps a benefit for an updated copy, keeping both lists in step.
  ///
  /// Rating a benefit on the detail screen returns fresh aggregates; without
  /// this the list behind it would still show the old score after going
  /// back.
  void replaceHack(Hack updated) {
    var changed = false;
    for (final list in [_mine.items, _circle.items]) {
      final i = list.indexWhere((h) => h.id == updated.id);
      if (i != -1) {
        list[i] = updated;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void likeHack(String id) {
    LoggerService.debug('Toggling like for hack ID: $id');
    for (final list in [_mine.items, _circle.items]) {
      for (final h in list) {
        if (h.id == id) {
          h.liked = !h.liked;
          h.likes += h.liked ? 1 : -1;
          break;
        }
      }
    }
    notifyListeners();
  }
}
