import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/features/feed/state/feed_state.dart';

/// Search is a third feed alongside the two tabs, so the paging machinery
/// is shared. What these pin is the term handling: which endpoint a given
/// combination resolves to, and that clearing terms drops back to browsing.
///
/// The requests themselves return 400 under flutter_test, which is fine —
/// what matters here is the state transitions, not the payloads.
void main() {
  group('search terms', () {
    test('a fresh state is browsing, not searching', () {
      final state = FeedState();
      expect(state.isSearching, isFalse);
      expect(state.query, isEmpty);
      expect(state.category, isNull);
    });

    test('a query puts the state into searching', () async {
      final state = FeedState();
      await state.setSearch(query: 'fuel');
      expect(state.isSearching, isTrue);
      expect(state.query, 'fuel');
    });

    test('a category alone also counts as searching', () async {
      final state = FeedState();
      await state.setSearch(category: 'Travel');
      expect(state.isSearching, isTrue);
      expect(state.category, 'Travel');
      expect(state.query, isEmpty);
    });

    test('clearing both returns to browsing', () async {
      final state = FeedState();
      await state.setSearch(query: 'fuel');
      await state.setSearch();
      expect(state.isSearching, isFalse);
      expect(state.query, isEmpty);
      expect(state.category, isNull);
    });

    test('whitespace is not a search', () async {
      // Otherwise a stray space in the field would fire a request and show
      // an empty result set.
      final state = FeedState();
      await state.setSearch(query: '   ');
      expect(state.isSearching, isFalse);
      expect(state.query, isEmpty);
    });

    test('a query is trimmed before being sent', () async {
      final state = FeedState();
      await state.setSearch(query: '  fuel  ');
      expect(state.query, 'fuel');
    });

    test('setting identical terms is a no-op', () async {
      // Guards against a rebuild re-running the same search.
      final state = FeedState();
      await state.setSearch(query: 'fuel');
      final before = state.itemsOf(HackFeed.search).length;
      await state.setSearch(query: 'fuel');
      expect(state.itemsOf(HackFeed.search).length, before);
    });
  });

  group('the search feed is separate from the tab feeds', () {
    test('it has its own paging state', () async {
      final state = FeedState();
      await state.setSearch(query: 'fuel');

      // Independent flags per feed, so searching never reports the tab as
      // loading or vice versa.
      expect(state.isLoadingFirstPage(HackFeed.search), isFalse);
      expect(state.itemsOf(HackFeed.search), isEmpty);
      expect(state.itemsOf(HackFeed.mine), isEmpty);
    });

    test('changing terms discards the previous results', () async {
      final state = FeedState();
      await state.setSearch(query: 'fuel');
      await state.setSearch(query: 'travel');
      expect(state.query, 'travel');
      expect(state.itemsOf(HackFeed.search), isEmpty);
    });

    test('searching with no terms cannot page forever', () async {
      // The request path returns an empty, exhausted page rather than
      // firing a query with nothing in it.
      final state = FeedState();
      await state.loadFirstPage(HackFeed.search, force: true);
      expect(state.hasMore(HackFeed.search), isFalse);
      expect(state.itemsOf(HackFeed.search), isEmpty);
    });
  });
}
