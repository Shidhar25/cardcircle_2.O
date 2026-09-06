import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/credit_card.dart';
import 'package:cardcircle/shared/models/hack.dart';

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

  group('rating', () {
    test('an unrated benefit has no rating, rather than a made-up 4.8', () {
      // Every unrated benefit used to display a confident score nobody gave
      // it. `rating` is null across the live catalog today.
      expect(Hack.fromJson(_json()).rating, isNull);
    });

    test('a real rating is kept', () {
      expect(Hack.fromJson(_json(rating: 4.2)).rating, 4.2);
      expect(Hack.fromJson(_json(rating: 5)).rating, 5.0);
    });

    test('a stringified rating is read', () {
      expect(Hack.fromJson(_json(rating: '3.7')).rating, 3.7);
    });

    test('a junk rating degrades to none, not to a default', () {
      expect(Hack.fromJson(_json(rating: 'excellent')).rating, isNull);
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
