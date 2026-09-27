import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/credit_card.dart';

/// The id shapes the two stores use. The catalog is Mongo, so its ids are
/// 24-char ObjectIds; saved cards live in Postgres, so theirs are uuids.
const _catalogId = '6a91bd69099699e73d237adb';
const _savedId = '3f7c1b02-9a4e-4f11-8f0a-5c2d9e7b1234';

CreditCard _card(String id) => CreditCard(
  id: id,
  catalogCardId: _catalogId,
  name: 'HDFC Millennia',
  bank: 'HDFC Bank',
  lastFour: '4471',
  gradientColors: const [Colors.black, Colors.white],
  type: 'credit',
  category: 'Credit Card',
);

void main() {
  group('finding the saved-card id in a /user/cards row', () {
    test('reads user_card_id', () {
      expect(
        CreditCard.savedIdFrom({
          'user_card_id': _savedId,
          'card_id': _catalogId,
        }),
        _savedId,
      );
    });

    test('accepts the other spellings the field turns up under', () {
      for (final key in ['userCardId', 'user_card', 'id', '_id']) {
        expect(
          CreditCard.savedIdFrom({key: _savedId, 'card_id': _catalogId}),
          _savedId,
          reason: 'should have read $key',
        );
      }
    });

    test('prefers user_card_id over a bare id', () {
      expect(
        CreditCard.savedIdFrom({
          'id': 'something-else',
          'user_card_id': _savedId,
        }),
        _savedId,
      );
    });

    test('never falls back to the catalog id', () {
      // This is the whole bug. Returning card_id here is what sent a Mongo
      // ObjectId to an endpoint that casts it to a uuid, so editing which
      // cards a friend can see failed with
      // `invalid input syntax for type uuid: "6a91bd69..."`.
      expect(CreditCard.savedIdFrom({'card_id': _catalogId}), isEmpty);
    });

    test('ignores blank and non-string values', () {
      expect(CreditCard.savedIdFrom({'user_card_id': '   '}), isEmpty);
      expect(CreditCard.savedIdFrom({'user_card_id': 42}), isEmpty);
      expect(CreditCard.savedIdFrom({'user_card_id': null}), isEmpty);
      expect(CreditCard.savedIdFrom(const {}), isEmpty);
    });

    test('trims what it finds', () {
      expect(CreditCard.savedIdFrom({'user_card_id': ' $_savedId '}), _savedId);
    });
  });

  group('a card the server cannot address', () {
    test('is not offered for sharing or deletion', () {
      expect(_card('').isAddressable, isFalse);
      expect(_card('   ').isAddressable, isFalse);
    });

    test('a real saved card is', () {
      expect(_card(_savedId).isAddressable, isTrue);
    });
  });
}
