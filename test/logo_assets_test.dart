import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/logo_assets.dart';

void main() {
  group('picking a bank mark', () {
    test('Axis uses the bundled logo', () {
      expect(LogoAssets.bank('axis-bank'), LogoAssets.axis);
    });

    test('an unbundled bank resolves to nothing, so the API stands', () {
      expect(LogoAssets.bank('hdfc-bank'), isNull);
      expect(LogoAssets.bank(null), isNull);
    });

    test('AU Small Finance is not mapped to the Axis mark', () {
      // `/banks` has answered this slug with the Axis logo URL before. That
      // is a server bug; mirroring it here would make it permanent.
      expect(LogoAssets.bank('au-small-finance-bank'), isNull);
    });
  });

  group('bundled marks are recognisable as bundled', () {
    test('so the badge knows to drop its white chip', () {
      expect(LogoAssets.isBundled(LogoAssets.axis), isTrue);
      expect(
        LogoAssets.isBundled('https://example.com/bank-logos/hdfc.webp'),
        isFalse,
      );
      expect(LogoAssets.isBundled(null), isFalse);
    });
  });
}
