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

  group('this class states no logo', () {
    // A network mark is never bundled with the app or guessed from a
    // naming convention any more — only ever taken from what the API
    // states (`network_logo.url` per card, or `/card-networks`' `logo_url`
    // via ApiService.networkLogoFor / cachedNetworkLogo). CardNetwork's job
    // ends at recognising and labelling the network.
    test('label is the only thing a parsed network carries', () {
      final visa = CardNetwork.parse('Visa Signature')!;
      expect(visa.label, 'Visa');
    });
  });
}
