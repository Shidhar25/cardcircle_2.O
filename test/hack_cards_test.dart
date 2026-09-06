import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/credit_card.dart';
import 'package:cardcircle/shared/models/hack.dart';
import 'package:cardcircle/shared/models/hack_rating.dart';

CreditCard _card({
  required String userCardId,
  required String catalogId,
  required String name,
}) => CreditCard(
  id: userCardId,
  catalogCardId: catalogId,
  name: name,
  bank: 'AU Small Finance Bank',
  lastFour: '4471',
  gradientColors: const [Colors.black, Colors.white],
  type: 'credit',
  category: 'Credit Card',
);

/// Field names and values taken from a live `GET /hacks/getmyhacks` row.
Map<String, dynamic> _json({
  Object? cardIds = const ['6a91ca31099699e73d237b4c'],
  Object? rating,
  String idKey = 'card_ids',
}) => {
  'id': 'h1',
  'name': 'Swipe abroad, skip the markup',
  'heading': 'Zero forex markup.',
  'steps': [
    {'name': 'Step 1', 'heading': 'Carry it', 'icon': '🌍', 'description': 'x'},
    {'name': 'Step 2', 'heading': 'Pay local', 'description': 'y'},
  ],
  idKey: cardIds,
  'savings': '3.5%',
  'category': 'Forex / International',
  'rating': rating,
  'things_to_note': const <String>[],
};

void main() {
  group('the cards a benefit applies to', () {
    test('reads card_ids, which is the field the API actually sends', () {
      // The model read `cards`, which the API never sends, so this list was
      // always empty and every benefit claimed "All Credit Cards".
      final hack = Hack.fromJson(_json());
      expect(hack.cardIds, ['6a91ca31099699e73d237b4c']);
      expect(hack.isCardSpecific, isTrue);
    });

    test('older payloads using `cards` still parse', () {
      final hack = Hack.fromJson(_json(idKey: 'cards'));
      expect(hack.cardIds, ['6a91ca31099699e73d237b4c']);
    });

    test('names only the cards the user actually holds', () {
      final hack = Hack.fromJson(_json(cardIds: const ['cat-a', 'cat-c']));
      final mine = [
        _card(userCardId: 'uc-1', catalogId: 'cat-a', name: 'ixigo AU'),
        _card(userCardId: 'uc-2', catalogId: 'cat-b', name: 'Amex Gold'),
      ];
      // cat-c is in the benefit but not in the wallet, so it is not named.
      expect(hack.myCardNames(mine), ['ixigo AU']);
    });

    test('matches on catalog id, not the saved-card id', () {
      // CreditCard.id is a user_card_id; benefits list catalog ids. Matching
      // the wrong one silently returns nothing for every benefit.
      final hack = Hack.fromJson(_json(cardIds: const ['uc-1']));
      final mine = [
        _card(userCardId: 'uc-1', catalogId: 'cat-a', name: 'ixigo AU'),
      ];
      expect(hack.myCardNames(mine), isEmpty);
    });

    test('no overlap yields nothing to say', () {
      final hack = Hack.fromJson(_json(cardIds: const ['cat-z']));
      final mine = [
        _card(userCardId: 'uc-1', catalogId: 'cat-a', name: 'ixigo AU'),
      ];
      expect(hack.myCardNames(mine), isEmpty);
    });

    test('a benefit naming no cards names none of yours', () {
      final hack = Hack.fromJson(_json(cardIds: const <String>[]));
      expect(hack.isCardSpecific, isFalse);
      expect(
        hack.myCardNames([
          _card(userCardId: 'uc-1', catalogId: 'cat-a', name: 'ixigo AU'),
        ]),
        isEmpty,
      );
    });

    test('a malformed card_ids value does not throw', () {
      expect(Hack.fromJson(_json(cardIds: 'nope')).cardIds, isEmpty);
      expect(Hack.fromJson(_json(cardIds: null)).cardIds, isEmpty);
    });
  });

  group('ratings', () {
    Map<String, dynamic> withRatings({
      Object? platform,
      Object? circle,
      Object? mine,
    }) => {
      ..._json(),
      'platform_rating': platform,
      'circle_rating': circle,
      'my_rating': mine,
    };

    test("reads both aggregates and the user's own score", () {
      final h = Hack.fromJson(
        withRatings(
          platform: {'average': 3, 'count': 3},
          circle: {'average': 4.5, 'count': 1},
          mine: 5,
        ),
      );
      expect(h.platformRating.average, 3);
      expect(h.platformRating.count, 3);
      expect(h.circleRating.average, 4.5);
      expect(h.myRating, 5);
    });

    test('an unrated benefit reports no ratings, not a zero score', () {
      // Rendering an absent aggregate as "0.0" reads as a damning score.
      final h = Hack.fromJson(withRatings());
      expect(h.platformRating.hasRatings, isFalse);
      expect(h.circleRating.hasRatings, isFalse);
      expect(h.myRating, isNull);
    });

    test('a zero count is treated as unrated whatever the average says', () {
      final h = Hack.fromJson(
        withRatings(platform: {'average': 4.9, 'count': 0}),
      );
      expect(h.platformRating.hasRatings, isFalse);
    });

    test('the circle leads when anyone in it has rated', () {
      // The circle's opinion is the signal the app exists to surface, so it
      // wins over a global average rather than being blended into one.
      final h = Hack.fromJson(
        withRatings(
          platform: {'average': 2, 'count': 900},
          circle: {'average': 5, 'count': 1},
        ),
      );
      expect(h.headlineIsCircle, isTrue);
      expect(h.headlineRating.average, 5);
    });

    test('the platform average stands in when the circle is silent', () {
      final h = Hack.fromJson(
        withRatings(platform: {'average': 4, 'count': 12}),
      );
      expect(h.headlineIsCircle, isFalse);
      expect(h.headlineRating.count, 12);
    });

    test('malformed rating blocks degrade rather than throwing', () {
      for (final bad in ['nope', 42, <String>[], null]) {
        final h = Hack.fromJson(withRatings(platform: bad, circle: bad));
        expect(h.platformRating, HackRating.none, reason: '$bad');
        expect(h.circleRating, HackRating.none, reason: '$bad');
      }
    });

    test('stringified numbers are read', () {
      final h = Hack.fromJson(
        withRatings(platform: {'average': '3.5', 'count': '4'}, mine: '2'),
      );
      expect(h.platformRating.average, 3.5);
      expect(h.platformRating.count, 4);
      expect(h.myRating, 2);
    });

    test('whole numbers display with one decimal, like the rest', () {
      expect(const HackRating(average: 3, count: 3).display, '3.0');
    });

    test('withRatings swaps the scores and keeps everything else', () {
      final before = Hack.fromJson(_json());
      final after = before.withRatings(
        platform: const HackRating(average: 4, count: 10),
        circle: const HackRating(average: 5, count: 2),
        mine: 5,
      );
      expect(after.myRating, 5);
      expect(after.platformRating.count, 10);
      expect(after.id, before.id);
      expect(after.cardIds, before.cardIds);
      expect(after.steps.length, before.steps.length);
    });
  });

  group('step icons', () {
    test('the icon ships with each step', () {
      final hack = Hack.fromJson(_json());
      expect(hack.steps.first.icon, '🌍');
    });

    test('a step with no icon falls back rather than rendering blank', () {
      final hack = Hack.fromJson(_json());
      expect(hack.steps[1].icon, isNotEmpty);
    });
  });
}
