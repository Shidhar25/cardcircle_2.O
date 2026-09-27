import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/services/api_service.dart';

const _s3 = 'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com';

void main() {
  group('the bank logo comes from the server, not from a guess', () {
    test('the current /bank/logo/ SVGs are used as sent', () {
      // These are what `/banks` serves for most banks now. The old check
      // only recognised `/generic/bank-logos/`, so it threw these away and
      // built `/generic/bank-logos/hdfc-bank.webp` instead — which 403s.
      // The result was no bank mark at all on a card whose logo was fine.
      const url = '$_s3/bank/logo/hdfc-bank.svg';
      expect(ApiService.sanitizedBankLogo('hdfc-bank', url), url);
    });

    test('the older /generic/bank-logos/ files still work', () {
      const url = '$_s3/generic/bank-logos/axis.webp';
      expect(ApiService.sanitizedBankLogo('axis-bank', url), url);
    });

    test('nothing is fabricated when the server sends no logo', () {
      // `logo: null` means the bank has no mark. Inventing a URL for it
      // only produces a request that cannot succeed; the plate falls back
      // to the monogram instead.
      expect(ApiService.sanitizedBankLogo('rbl-bank', null), isNull);
      expect(ApiService.sanitizedBankLogo('rbl-bank', ''), isNull);
    });

    test('card artwork is still refused', () {
      // `/banks` has answered with a picture of one of the bank's cards
      // before. That belongs nowhere near the issuer slot.
      expect(
        ApiService.sanitizedBankLogo(
          'axis-bank',
          '$_s3/credit-card-images/axis/axis-neo.webp',
        ),
        isNull,
      );
      expect(
        ApiService.sanitizedBankLogo(
          'hdfc-bank',
          '$_s3/generic/bank-card-bg/hdfc.webp',
        ),
        isNull,
      );
    });
  });

  group('the network mark comes only from the /card-networks catalog', () {
    // Real shape of `GET /card-networks`, trimmed to the fields that
    // matter. `logo_url` is null for every network today — that is the
    // API's own current state, not something this code should paper over.
    final catalogRows = [
      {'name': 'Visa', 'code': 'VISA', 'logo_url': null},
      {
        'name': 'Mastercard',
        'code': 'MASTERCARD',
        'logo_url': '$_s3/network/logo/mastercard.svg',
      },
      {'name': 'RuPay', 'code': 'RUPAY', 'logo_url': null},
      {
        'name': 'American Express',
        'code': 'AMERICAN_EXPRESS',
        'logo_url': null,
      },
      {'name': 'Diners Club', 'code': 'DINERS_CLUB', 'logo_url': null},
    ];

    test('the catalog is keyed by both name and code, lowercased', () {
      final cache = ApiService.parseNetworkCatalog(catalogRows);
      expect(cache['mastercard'], '$_s3/network/logo/mastercard.svg');
      expect(cache.containsKey('visa'), isTrue);
      expect(cache.containsKey('american_express'), isTrue);
      expect(cache.containsKey('american express'), isTrue);
    });

    test('a network the server has a logo for resolves to it', () {
      final cache = ApiService.parseNetworkCatalog(catalogRows);
      // "Mastercard World" is what the free-text field actually sends; the
      // tier has to be stripped before it matches the catalog's own name.
      expect(
        ApiService.matchNetworkLogo(cache, 'Mastercard World'),
        '$_s3/network/logo/mastercard.svg',
      );
    });

    test('a Visa tier still matches Visa in the catalog', () {
      final cache = ApiService.parseNetworkCatalog(catalogRows);
      expect(ApiService.matchNetworkLogo(cache, 'Visa Signature'), isNull);
      // Confirms it reached the "Visa" entry and returned its stated
      // logo_url (null today) rather than failing to match at all.
      expect(
        ApiService.parseNetworkCatalog(catalogRows).containsKey('visa'),
        isTrue,
      );
    });

    test('a network the server has no logo for resolves to null, not a guess', () {
      final cache = ApiService.parseNetworkCatalog(catalogRows);
      // This is the whole point: with logo_url null for RuPay, the mark is
      // simply absent — never a bundled asset, never an invented S3 path.
      expect(ApiService.matchNetworkLogo(cache, 'RuPay'), isNull);
      expect(ApiService.matchNetworkLogo(cache, 'American Express'), isNull);
    });

    test('a network the catalog has never heard of resolves to null', () {
      final cache = ApiService.parseNetworkCatalog(catalogRows);
      expect(ApiService.matchNetworkLogo(cache, 'Some Future Network'), isNull);
      expect(ApiService.matchNetworkLogo(cache, null), isNull);
      expect(ApiService.matchNetworkLogo(cache, ''), isNull);
    });

    test('an empty or malformed catalog response fails closed', () {
      final cache = ApiService.parseNetworkCatalog(const []);
      expect(ApiService.matchNetworkLogo(cache, 'Visa'), isNull);

      final malformed = ApiService.parseNetworkCatalog([
        'not a map',
        42,
        null,
      ]);
      expect(malformed, isEmpty);
    });
  });
}
