import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/credit_card.dart';

/// Real ids from this account. The two stores disagree on shape, which is
/// the whole point: the catalog is Mongo (24-char ObjectId), saved cards and
/// permissions live in Postgres (uuid).
const _zenithCatalogId = '6a91bd69099699e73d237adb';
const _zenithSavedId = '0e564368-383b-4502-9eea-06660a3b0702';
const _dinersCatalogId = '6a83706e7d3d9b6b52400909';
const _dinersSavedId = '6485397c-0996-4fbb-9885-a2cf362916e0';

/// Transcribed from `GET /follow/permissions/{followId}`.
String _permissionsBody() => jsonEncode({
  'success': true,
  'data': {
    'followId': '8d086ab6-4dc4-4ca9-bd8f-f13074f170b9',
    'permissions': [
      {
        'permission_id': '9768e72a-98c5-42c3-8ea8-fd13f7a9cb52',
        'card_id': _zenithCatalogId,
        'is_allowed': true,
        'card': {'card_name': 'Zenith+', 'bank_id': 'au-small-finance-bank'},
      },
      {
        'permission_id': 'aaaa1111-1979-4daf-a422-ef35733b1d9a',
        'card_id': _dinersCatalogId,
        'is_allowed': false,
        'card': {'card_name': 'Diners Club Black Metal'},
      },
    ],
  },
});

CreditCard _card({required String savedId, required String catalogId}) =>
    CreditCard(
      id: savedId,
      catalogCardId: catalogId,
      name: 'A card',
      bank: 'A bank',
      lastFour: '4471',
      gradientColors: const [Colors.black, Colors.white],
      type: 'credit',
      category: 'Credit Card',
    );

/// The translation the Circle screen performs before seeding the access
/// sheet or sending a save. Mirrors `_allowedSavedCardIds`.
List<String> asSavedCardIds(List<String> ids, List<CreditCard> cards) {
  final out = <String>[];
  for (final id in ids) {
    for (final card in cards) {
      final matches = card.catalogCardId == id || card.id == id;
      if (matches && card.isAddressable && !out.contains(card.id)) {
        out.add(card.id);
        break;
      }
    }
  }
  return out;
}

void main() {
  group('reading who can see what', () {
    test('keeps only the allowed rows, as the server spells them', () async {
      // Transcribed shape: `data.permissions[]`, each with is_allowed.
      final parsed = jsonDecode(_permissionsBody());
      final perms = (parsed['data'] as Map)['permissions'] as List;
      final allowed = perms
          .where((p) => p['is_allowed'] == true)
          .map((p) => p['card_id'] as String)
          .toList();

      expect(allowed, [_zenithCatalogId]);
    });

    test('the ids it answers with are catalog ids, not saved-card ids', () {
      // Documents the mismatch this test file exists for: what comes back
      // here cannot be sent to the PUT.
      expect(_zenithCatalogId, hasLength(24));
      expect(_zenithCatalogId, isNot(contains('-')));
      expect(_zenithSavedId, contains('-'));
    });
  });

  group('translating them for the access sheet', () {
    final cards = [
      _card(savedId: _zenithSavedId, catalogId: _zenithCatalogId),
      _card(savedId: _dinersSavedId, catalogId: _dinersCatalogId),
    ];

    test('a catalog id resolves to the saved card', () {
      // Without this the sheet opened with nothing ticked even though the
      // follower could see Zenith+, and saving sent the catalog id to a
      // uuid column: `invalid input syntax for type uuid`.
      expect(asSavedCardIds([_zenithCatalogId], cards), [_zenithSavedId]);
    });

    test('a saved-card id passes straight through', () {
      // A successful save writes back the ids it just sent, so this map
      // holds either vocabulary depending on how it was last filled.
      expect(asSavedCardIds([_zenithSavedId], cards), [_zenithSavedId]);
    });

    test('every translated id is a uuid the PUT will accept', () {
      final out = asSavedCardIds([_zenithCatalogId, _dinersCatalogId], cards);
      expect(out, [_zenithSavedId, _dinersSavedId]);
      for (final id in out) {
        expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-').hasMatch(id),
          isTrue,
          reason: '$id is not a uuid and would 500 the save',
        );
      }
    });

    test('a card the user no longer holds is dropped', () {
      expect(asSavedCardIds(['6a00000000000000deadbeef'], cards), isEmpty);
    });

    test('an unaddressable card is never offered', () {
      final orphan = [_card(savedId: '', catalogId: _zenithCatalogId)];
      expect(asSavedCardIds([_zenithCatalogId], orphan), isEmpty);
    });

    test('no duplicates when the same card is listed twice', () {
      expect(asSavedCardIds([
        _zenithCatalogId,
        _zenithSavedId,
      ], cards), [_zenithSavedId]);
    });

    test('cards not loaded yet yields nothing rather than raw ids', () {
      expect(asSavedCardIds([_zenithCatalogId], const []), isEmpty);
    });
  });

  group('the saved-card row', () {
    test('user_card_id is present and is what addresses the card', () {
      // Transcribed from GET /user/cards.
      final row = {
        'user_card_id': _zenithSavedId,
        'card_id': _zenithCatalogId,
        'card_name': 'Zenith+',
      };
      expect(CreditCard.savedIdFrom(row), _zenithSavedId);
      expect(CreditCard.savedIdFrom(row), isNot(_zenithCatalogId));
    });
  });
}
