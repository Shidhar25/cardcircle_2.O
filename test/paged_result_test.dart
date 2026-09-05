import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/paged_result.dart';

Map<String, dynamic> _envelope({
  required int count,
  required int page,
  int limit = 7,
  int total = 20,
  bool? hasMore,
  bool withPagination = true,
}) => {
  'success': true,
  'hacks': List.generate(count, (i) => {'id': 'p${page}_i$i'}),
  if (withPagination)
    'pagination': {
      'page': page,
      'limit': limit,
      'total': total,
      'has_more': ?hasMore,
    },
};

PagedResult<Map<String, dynamic>> _parse(
  Map<String, dynamic> body, {
  int page = 1,
  int limit = 7,
}) => PagedResult.fromEnvelope(
  body,
  itemsKey: 'hacks',
  requestedPage: page,
  requestedLimit: limit,
);

void main() {
  group('the documented envelope', () {
    test('page 1 of 20 at 7 per page reports more to come', () {
      final r = _parse(_envelope(count: 7, page: 1, hasMore: true));
      expect(r.items.length, 7);
      expect(r.page, 1);
      expect(r.limit, 7);
      expect(r.total, 20);
      expect(r.hasMore, isTrue);
    });

    test('the last page exhausts cleanly', () {
      // 20 items at 7 per page: page 3 holds the remaining 6.
      final r = _parse(_envelope(count: 6, page: 3, hasMore: false), page: 3);
      expect(r.items.length, 6);
      expect(r.hasMore, isFalse);
    });

    test('has_more is trusted even when the arithmetic disagrees', () {
      // A full page that the server says is the last one. Deriving from
      // count alone would keep asking for page 4 forever.
      final r = _parse(
        _envelope(count: 7, page: 3, total: 21, hasMore: false),
        page: 3,
      );
      expect(r.hasMore, isFalse);
    });
  });

  group('a server that omits has_more', () {
    test('it is derived from page, limit and total', () {
      expect(_parse(_envelope(count: 7, page: 1)).hasMore, isTrue);
      expect(_parse(_envelope(count: 6, page: 3), page: 3).hasMore, isFalse);
    });

    test('the exact final page is not treated as having more', () {
      // 21 items at 7 per page: page 3 is full but complete.
      final r = _parse(_envelope(count: 7, page: 3, total: 21), page: 3);
      expect(r.hasMore, isFalse);
    });
  });

  group('a deployment with no pagination at all', () {
    test('a full-length response ends the scroll instead of looping', () {
      // The old contract returns everything at once. Treating that as
      // "page 1 of many" would request page 2 forever.
      final r = _parse(_envelope(count: 20, page: 1, withPagination: false));
      expect(r.items.length, 20);
      expect(r.hasMore, isFalse);
      expect(r.total, isNull);
    });

    test('a short response is likewise complete', () {
      final r = _parse(_envelope(count: 3, page: 1, withPagination: false));
      expect(r.hasMore, isFalse);
    });

    test('a response exactly one page long may have more', () {
      final r = _parse(_envelope(count: 7, page: 1, withPagination: false));
      expect(r.hasMore, isTrue);
    });
  });

  group('malformed responses do not throw', () {
    test('a missing items key yields an empty page', () {
      final r = _parse(const {'success': true});
      expect(r.items, isEmpty);
      expect(r.hasMore, isFalse);
    });

    test('a non-list items value yields an empty page', () {
      final r = _parse(const {'success': true, 'hacks': 'nope'});
      expect(r.items, isEmpty);
    });

    test('non-map entries are dropped rather than crashing the parse', () {
      final r = _parse(const {
        'success': true,
        'hacks': [
          {'id': 'a'},
          'junk',
          null,
          {'id': 'b'},
        ],
      });
      expect(r.items.length, 2);
    });

    test('stringified numbers in pagination are read', () {
      final r = _parse(const {
        'success': true,
        'hacks': [],
        'pagination': {'page': '2', 'limit': '7', 'total': '20'},
      }, page: 2);
      expect(r.page, 2);
      expect(r.total, 20);
      expect(r.hasMore, isTrue);
    });

    test('a non-map pagination block falls back to the count heuristic', () {
      final r = _parse(const {
        'success': true,
        'hacks': [],
        'pagination': 'nope',
      });
      expect(r.hasMore, isFalse);
    });
  });
}
