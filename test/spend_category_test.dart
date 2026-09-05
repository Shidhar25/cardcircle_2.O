import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/spend_category.dart';

/// Rows below are copied from a live `GET /category/list` response.
const _foodDining = {
  'categoryId': 'f70ac04d-a746-4bf4-bf29-97896994f17f',
  'name': 'food_dining',
  'displayName': 'Food & Dining',
  'description': 'Restaurants, cafes, food delivery',
  'icon': 'utensils',
  'color': '#FF6B6B',
};

void main() {
  group('parsing', () {
    test('reads a live category row', () {
      final c = SpendCategory.tryParse(_foodDining)!;
      expect(c.id, 'f70ac04d-a746-4bf4-bf29-97896994f17f');
      expect(c.name, 'food_dining');
      expect(c.displayName, 'Food & Dining');
      expect(c.icon, Icons.restaurant_rounded);
      expect(c.color(Colors.black), const Color(0xFFFF6B6B));
    });

    test('a row with no id is dropped, since it could not be tagged', () {
      expect(SpendCategory.tryParse(const {'name': 'x'}), isNull);
      expect(SpendCategory.tryParse(const {'categoryId': ''}), isNull);
    });

    test('a missing display name falls back to the machine name', () {
      final c = SpendCategory.tryParse(const {
        'categoryId': 'id-1',
        'name': 'personal_care',
      })!;
      expect(c.displayName, 'Personal Care');
    });

    test('an unknown icon key still renders something', () {
      final c = SpendCategory.tryParse(const {
        'categoryId': 'id-1',
        'name': 'x',
        'icon': 'not-a-real-icon',
      })!;
      expect(c.icon, isNotNull);
    });

    test('a malformed colour falls back rather than throwing', () {
      // int.parse on 'nope' used to throw and take the grid down.
      for (final bad in ['nope', '#12', '', '#GGGGGG']) {
        final c = SpendCategory.tryParse({
          'categoryId': 'id-1',
          'name': 'x',
          'color': bad,
        })!;
        expect(c.color(Colors.teal), Colors.teal, reason: 'colour was "$bad"');
      }
    });

    test('a colour without the leading hash is still read', () {
      final c = SpendCategory.tryParse(const {
        'categoryId': 'id-1',
        'name': 'x',
        'color': '4ECDC4',
      })!;
      expect(c.color(Colors.black), const Color(0xFF4ECDC4));
    });
  });

  group('matching a benefit to a category', () {
    // The hardcoded pill said "Dining"; the backend calls it "food_dining" /
    // "Food & Dining". A plain string comparison matched neither spelling,
    // so selecting a category emptied the list.
    final c = SpendCategory.tryParse(_foodDining)!;

    test('matches the machine name', () {
      expect(c.matches('food_dining'), isTrue);
      expect(c.matches('FOOD_DINING'), isTrue);
    });

    test('matches the display name', () {
      expect(c.matches('Food & Dining'), isTrue);
      expect(c.matches('  food & dining  '), isTrue);
    });

    test('matches the id', () {
      expect(c.matches('f70ac04d-a746-4bf4-bf29-97896994f17f'), isTrue);
    });

    test('does not match an unrelated category or empty text', () {
      expect(c.matches('travel'), isFalse);
      expect(c.matches(''), isFalse);
      expect(c.matches(null), isFalse);
    });

    test('the old hardcoded label no longer silently matches nothing', () {
      // "Dining" is not this category by any of its real names — which is
      // exactly why the old pill returned an empty feed.
      expect(c.matches('Dining'), isFalse);
    });
  });
}
