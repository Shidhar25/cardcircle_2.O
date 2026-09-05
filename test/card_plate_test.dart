import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/card_material.dart';
import 'package:cardcircle/shared/widgets/bank_mark.dart';
import 'package:cardcircle/shared/widgets/card_plate.dart';

/// Real URLs from `GET /cards`. They 404 under flutter_test, which is the
/// point for the fallback cases — the widget must survive a dead image.
const _artwork =
    'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com/generic/'
    'bank-generic-cards/bank-of-baroda.webp';
const _bankLogo =
    'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com/generic/'
    'bank-logos/bank-of-baroda.webp';
const _networkLogo =
    'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com/generic/'
    'network-logos/mastercard.webp';

Future<void> _pump(
  WidgetTester tester, {
  String? artworkUrl = _artwork,
  bool isCardSpecific = false,
  String? bankLogoUrl = _bankLogo,
  String? networkLogoUrl = _networkLogo,
  bool compact = false,
  String network = 'Mastercard',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CardPlate(
              artworkUrl: artworkUrl,
              isCardSpecific: isCardSpecific,
              bankLogoUrl: bankLogoUrl,
              name: 'Eterna',
              networkLogoUrl: networkLogoUrl,
              network: network,
              bankId: 'bank-of-baroda',
              bankName: 'Bank of Baroda',
              material: cardMaterialFor(name: 'Eterna', cardType: 'Premium'),
              compact: compact,
              height: 200,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('everything on the face comes from a URL', () {
    testWidgets('artwork, bank logo and network logo are all network images', (
      tester,
    ) async {
      await _pump(tester);

      final urls = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as NetworkImage).url)
          .toList();

      expect(urls, contains(_artwork));
      expect(urls, contains(_bankLogo));
      expect(urls, contains(_networkLogo));
    });

    testWidgets('no bundled asset is loaded', (tester) async {
      await _pump(tester);
      final assetImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is AssetImage);
      expect(assetImages, isEmpty);
    });
  });

  group('generic artwork is zoomed past its baked-in margin', () {
    // The templated art is a 1000x630 canvas holding an 880x554 card,
    // centred: ~12% of every edge is transparent margin plus a drop
    // shadow. Drawn as-is that reads as a card inside a card.
    double zoomOf(WidgetTester tester) {
      final t = tester.widget<Transform>(
        find
            .ancestor(of: find.byType(Image), matching: find.byType(Transform))
            .first,
      );
      return t.transform.getMaxScaleOnAxis();
    }

    testWidgets('art is enlarged past the widest inset measured', (
      tester,
    ) async {
      await _pump(tester);
      expect(zoomOf(tester), closeTo(1.193 * 1.01, 0.001));
      // Covers all three artwork families, the tightest of which needs
      // 1000/838 = 1.193.
      expect(zoomOf(tester), greaterThanOrEqualTo(1000 / 838));
      expect(zoomOf(tester), greaterThanOrEqualTo(630 / 554));
    });

    testWidgets('card-specific art is zoomed too', (tester) async {
      // It is the same padded 1000x630 template as the generic art, not a
      // photograph someone framed.
      await _pump(tester, isCardSpecific: true);
      expect(zoomOf(tester), closeTo(1.193 * 1.01, 0.001));
    });
  });

  group('corners', () {
    Radius radiusOf(WidgetTester tester) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CardPlate),
              matching: find.byType(Container),
            )
            .first,
      );
      final d = box.decoration as BoxDecoration;
      return (d.borderRadius as BorderRadius).topLeft;
    }

    testWidgets('an artwork plate is rounded to match the artwork', (
      tester,
    ) async {
      // The art's own corners are ~4.3% of the card width, rounder than the
      // plate's house 9u. Clipping tighter than the art leaves a dark
      // sliver in every corner.
      await _pump(tester);
      const u = 200 / 150;
      expect(radiusOf(tester).x, closeTo(10.3 * u, 0.01));
    });

    testWidgets('a plate with no artwork keeps the house radius', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null);
      const u = 200 / 150;
      expect(radiusOf(tester).x, closeTo(9 * u, 0.01));
    });
  });

  group('mark placement', () {
    testWidgets('bank logo sits top left, network logo bottom right', (
      tester,
    ) async {
      await _pump(tester);

      final plate = tester.getRect(find.byType(CardPlate));
      final badges = tester.widgetList<LogoBadge>(find.byType(LogoBadge));

      final bank = badges.firstWhere((b) => b.url == _bankLogo);
      final network = badges.firstWhere((b) => b.url == _networkLogo);

      final bankRect = tester.getRect(find.byWidget(bank));
      final networkRect = tester.getRect(find.byWidget(network));

      // Top half vs bottom half.
      expect(bankRect.center.dy, lessThan(plate.center.dy));
      expect(networkRect.center.dy, greaterThan(plate.center.dy));

      // Left half vs right half.
      expect(bankRect.center.dx, lessThan(plate.center.dx));
      expect(networkRect.center.dx, greaterThan(plate.center.dx));
    });

    testWidgets('the network type is printed with the logo', (tester) async {
      await _pump(tester);
      expect(find.text('MASTERCARD'), findsOneWidget);
    });

    testWidgets('the name sits to the left of the network mark', (
      tester,
    ) async {
      await _pump(tester);
      final name = tester.getRect(find.text('Eterna'));
      final network = tester.getRect(
        find.byWidget(
          tester
              .widgetList<LogoBadge>(find.byType(LogoBadge))
              .firstWhere((b) => b.url == _networkLogo),
        ),
      );
      expect(name.right, lessThanOrEqualTo(network.left));
    });
  });

  group('degrading', () {
    testWidgets('no artwork still renders the marks over the gradient', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null);
      expect(tester.takeException(), isNull);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });

    testWidgets('no bank logo falls back to the issuer monogram', (
      tester,
    ) async {
      await _pump(tester, bankLogoUrl: null);
      expect(find.text('OB'), findsOneWidget);
    });

    testWidgets('no network logo still names the network', (tester) async {
      // The RuPay case: no artwork exists, so the type label is the only
      // thing identifying the network.
      await _pump(tester, networkLogoUrl: null, network: 'RuPay');
      expect(tester.takeException(), isNull);
      expect(find.byType(LogoBadge), findsOneWidget); // bank logo only
      expect(find.text('RUPAY'), findsOneWidget);
    });

    testWidgets('an unknown network shows neither logo nor label', (
      tester,
    ) async {
      await _pump(tester, networkLogoUrl: null, network: 'Something New');
      expect(find.byType(LogoBadge), findsOneWidget);
      expect(find.text('SOMETHING NEW'), findsNothing);
    });

    testWidgets('card-specific artwork carries no overlaid marks', (
      tester,
    ) async {
      // The image is a picture of that exact card: the issuer branding and
      // the network mark are already part of its design, so drawing ours
      // over it prints both twice.
      await _pump(tester, isCardSpecific: true);
      expect(find.byType(LogoBadge), findsNothing);
      expect(find.text('MASTERCARD'), findsNothing);
      expect(find.text('OB'), findsNothing);
    });

    testWidgets('generic artwork does carry the marks', (tester) async {
      // Nothing on a generic bank background identifies the card, so both
      // marks are drawn there.
      await _pump(tester);
      expect(find.byType(LogoBadge), findsNWidgets(2));
      expect(find.text('MASTERCARD'), findsOneWidget);
    });

    testWidgets('a plate with no artwork keeps its marks', (tester) async {
      // `isCardSpecific` is meaningless without an image; the gradient
      // plate must still identify itself.
      await _pump(tester, artworkUrl: null, isCardSpecific: true);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });

    testWidgets('compact mode drops the name and the network label', (
      tester,
    ) async {
      // At thumbnail size the label is a smudge; the logo still reads.
      await _pump(tester, compact: true);
      expect(find.text('Eterna'), findsNothing);
      expect(find.text('MASTERCARD'), findsNothing);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });
  });
}
