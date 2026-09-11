import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/services/api_service.dart';
import 'package:cardcircle/shared/models/card_variant.dart';
import 'package:cardcircle/shared/widgets/card_variant_picker_sheet.dart';

/// Transcribed from `GET /cards?banks=hdfc-bank`: one product, three
/// networks, only one of which the bank splits into a tier.
const _millennia = {
  'group_key': 'hdfc bank::millennia',
  'name': 'Millennia',
  'issuer': 'HDFC Bank',
  'bank_id': 'hdfc-bank',
  'card_type': 'Premium',
  'image': 'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com'
      '/credit-card-images/hdfc/hdfc-millennia.webp',
  'variants': [
    {
      'card_id': '6a834de57d3d9b6b524008bd',
      'bank_id': 'hdfc-bank',
      'network': 'Visa',
      'network_variant': 'Signature',
      'card_variant': 'Millennia',
      'card_type': 'Premium',
      'label': 'Visa: Signature',
      'value': 'visa:signature',
    },
    {
      'card_id': '6a907d0c6ecb9b56ae3e1968',
      'bank_id': 'hdfc-bank',
      'network': 'Mastercard',
      'network_variant': null,
      'card_variant': null,
      'card_type': 'Entry-level Credit Card',
      'label': 'Mastercard',
      'value': 'mastercard',
    },
    {
      'card_id': '6a907d2a6ecb9b56ae3e196a',
      'bank_id': 'hdfc-bank',
      'network': 'Diners Club',
      'network_variant': null,
      'card_variant': null,
      'card_type': 'Entry-level Credit Card',
      'label': 'Diners Club',
      'value': 'diners club',
    },
  ],
  'networks': ['Visa', 'Mastercard', 'Diners Club'],
  'network_variants': ['Signature'],
  'variant_count': 3,
  'has_multiple_variants': true,
  'default_variant_id': '6a834de57d3d9b6b524008bd',
};

/// A one-variant group, on the bank's generic artwork rather than its own.
const _bizBlack = {
  'group_key': 'hdfc bank::bizblack',
  'name': 'BizBlack',
  'issuer': 'HDFC Bank',
  'bank_id': 'hdfc-bank',
  'card_type': 'Super Premium Business Credit Card',
  'image': 'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com'
      '/generic/bank-card-bg/hdfc.webp',
  'variants': [
    {
      'card_id': '6a832bb77d3d9b6b52400896',
      'bank_id': 'hdfc-bank',
      'network': 'Diners Club',
      'network_variant': null,
      'card_variant': null,
      'card_type': 'Super Premium Business Credit Card',
      'label': 'Diners Club',
      'value': 'diners club',
    },
  ],
  'networks': ['Diners Club'],
  'variant_count': 1,
  'has_multiple_variants': false,
  'default_variant_id': '6a832bb77d3d9b6b52400896',
};

void main() {
  group('the grouped catalog row normalises', () {
    test('the product name comes off the top level, not card.name', () {
      final row = ApiService.normalizeCatalogCard(
        Map<String, dynamic>.from(_millennia),
      );

      expect(row['card']['name'], 'Millennia');
      expect(row['card']['issuer'], 'HDFC Bank');
      expect(row['group_key'], 'hdfc bank::millennia');
    });

    test('the variants ride along so the picker can offer them', () {
      final row = ApiService.normalizeCatalogCard(
        Map<String, dynamic>.from(_millennia),
      );
      final variants = CardVariantOption.listFrom(row['variants']);

      expect(variants, hasLength(3));
      expect(variants.first.cardId, '6a834de57d3d9b6b524008bd');
      expect(variants.first.label, 'Visa: Signature');
      expect(variants.first.networkVariant, 'Signature');
      // A JSON null must not become the string "null" in the payload.
      expect(variants[1].networkVariant, isNull);
      expect(variants[1].cardVariant, isNull);
      expect(row['default_variant_id'], '6a834de57d3d9b6b524008bd');
    });

    test('the thumbnail follows the default variant, not the first', () {
      final shuffled = Map<String, dynamic>.from(_millennia);
      shuffled['default_variant_id'] = '6a907d2a6ecb9b56ae3e196a';

      final row = ApiService.normalizeCatalogCard(shuffled);

      expect(row['card']['network'], 'Diners Club');
    });

    test('a bare image URL is read as a URL', () {
      final row = ApiService.normalizeCatalogCard(
        Map<String, dynamic>.from(_millennia),
      );

      expect(row['image']['url'], endsWith('hdfc-millennia.webp'));
      expect(row['image']['is_card_specific'], isTrue);
    });

    test('the bank-wide fallback artwork is not passed off as the card', () {
      // `generic/bank-card-bg/hdfc.webp` is every HDFC card without its own
      // photo. Calling it card-specific is what makes the plate draw it as
      // if it were this product's face.
      final row = ApiService.normalizeCatalogCard(
        Map<String, dynamic>.from(_bizBlack),
      );

      expect(row['image']['is_card_specific'], isFalse);
    });

    test('the older flat shape still normalises', () {
      final row = ApiService.normalizeCatalogCard({
        'id': 'abc123',
        'bank_id': 'hdfc-bank',
        'card_name': 'Regalia',
        'issuer': 'HDFC Bank',
        'network': 'Visa',
        'image_url': 'https://example.com/regalia.webp',
      });

      expect(row['id'], 'abc123');
      expect(row['card']['name'], 'Regalia');
      expect(row['card']['network'], 'Visa');
      expect(row['variants'], isNull);
    });
  });

  group('the variant picker', () {
    Future<CardVariantOption?> open(
      WidgetTester tester,
      List<CardVariantOption> variants, {
      String? initialCardId,
    }) async {
      CardVariantOption? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CardVariantPickerSheet.show(
                    context,
                    cardName: 'Millennia',
                    variants: variants,
                    initialCardId: initialCardId,
                  );
                },
                child: const Text('add'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('offers every network the card was issued on', (tester) async {
      final variants = CardVariantOption.listFrom(_millennia['variants']);
      await open(tester, variants);

      expect(find.text('Which one do you hold?'), findsOne);
      expect(find.text('Visa: Signature'), findsOne);
      expect(find.text('Mastercard'), findsOne);
      expect(find.text('Diners Club'), findsOne);
    });

    testWidgets('resolves to the chosen variant\'s own card_id', (
      tester,
    ) async {
      final variants = CardVariantOption.listFrom(_millennia['variants']);
      CardVariantOption? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  picked = await CardVariantPickerSheet.show(
                    context,
                    cardName: 'Millennia',
                    variants: variants,
                  );
                },
                child: const Text('add'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diners Club'));
      await tester.pump();
      await tester.tap(find.text('Add card'));
      await tester.pumpAndSettle();

      expect(picked?.cardId, '6a907d2a6ecb9b56ae3e196a');
      expect(picked?.network, 'Diners Club');
      expect(picked?.networkVariant, isNull);
    });

    testWidgets('a single-variant card is never asked about', (tester) async {
      final variants = CardVariantOption.listFrom(_bizBlack['variants']);
      final result = await open(tester, variants);

      expect(find.text('Which one do you hold?'), findsNothing);
      expect(result?.cardId, '6a832bb77d3d9b6b52400896');
    });

    testWidgets('the CTA waits for an answer', (tester) async {
      final variants = CardVariantOption.listFrom(_millennia['variants']);
      await open(tester, variants);

      // Nothing pre-selected, so confirming must do nothing rather than
      // guess a network on the user's behalf.
      await tester.tap(find.text('Add card'));
      await tester.pumpAndSettle();
      expect(find.text('Which one do you hold?'), findsOne);
    });

    testWidgets('a default variant arrives pre-selected', (tester) async {
      final variants = CardVariantOption.listFrom(_millennia['variants']);
      await open(
        tester,
        variants,
        initialCardId: '6a907d0c6ecb9b56ae3e1968',
      );

      await tester.tap(find.text('Add card'));
      await tester.pumpAndSettle();
      expect(find.text('Which one do you hold?'), findsNothing);
    });
  });
}
