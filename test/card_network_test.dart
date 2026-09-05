import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/card_network.dart';

void main() {
  group('parsing the backend field', () {
    test('a product tier resolves to its base network', () {
      // `network` carries the tier, e.g. "Visa Signature".
      expect(CardNetwork.parse('Visa Signature')?.label, 'Visa');
      expect(CardNetwork.parse('Mastercard World')?.label, 'Mastercard');
    });

    test('a multi-network string picks the first listed', () {
      // Real value from /cards: "Visa/Mastercard/RuPay".
      expect(CardNetwork.parse('Visa/Mastercard/RuPay')?.label, 'Visa');
    });

    test('parseAll reports every network on the card', () {
      final all = CardNetwork.parseAll('Visa/Mastercard/RuPay');
      expect(all.map((n) => n.label), ['Visa', 'Mastercard', 'RuPay']);
    });

    test('matching is case and spacing tolerant', () {
      expect(CardNetwork.parse('MASTER CARD')?.label, 'Mastercard');
      expect(CardNetwork.parse('american express')?.label, 'American Express');
    });

    test('an unknown or empty network yields nothing', () {
      expect(CardNetwork.parse(null), isNull);
      expect(CardNetwork.parse(''), isNull);
      expect(CardNetwork.parse('   '), isNull);
      expect(CardNetwork.parse('Some Future Network'), isNull);
    });
  });

  group('logo URLs are only built for artwork that exists', () {
    // Probed against S3: these six return 200.
    test('networks with artwork produce a URL', () {
      for (final raw in [
        'Visa',
        'Mastercard',
        'Amex',
        'Diners Club',
        'Discover',
        'Maestro',
      ]) {
        final n = CardNetwork.parse(raw);
        expect(n, isNotNull, reason: raw);
        expect(n!.logoUrl, isNotNull, reason: raw);
        expect(n.logoUrl, contains('/generic/network-logos/'));
        expect(n.logoUrl, endsWith('.webp'));
      }
    });

    test('RuPay is labelled but has no logo URL', () {
      // Every spelling of rupay.webp returns 403 — requesting one just
      // guarantees a failed image, so no URL is generated and the plate
      // identifies the card by its label instead.
      final n = CardNetwork.parse('RuPay');
      expect(n, isNotNull);
      expect(n!.label, 'RuPay');
      expect(n.logoUrl, isNull);
    });

    test('the URL uses the network slug, not the display label', () {
      // "American Express" would 403; "amex" is the file that exists.
      expect(
        CardNetwork.parse('American Express')!.logoUrl,
        endsWith('/amex.webp'),
      );
      expect(
        CardNetwork.parse('Diners Club')!.logoUrl,
        endsWith('/diners.webp'),
      );
    });
  });
}
