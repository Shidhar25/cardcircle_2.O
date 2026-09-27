import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  String? bankLogoUrl = _bankLogo,
  String? networkLogoUrl = _networkLogo,
  bool compact = false,
  String network = 'Mastercard',
  double width = 320,
  double height = 200,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CardPlate(
              artworkUrl: artworkUrl,
              bankLogoUrl: bankLogoUrl,
              name: 'Eterna',
              networkLogoUrl: networkLogoUrl,
              network: network,
              bankId: 'bank-of-baroda',
              bankName: 'Bank of Baroda',
              material: cardMaterialFor(name: 'Eterna', cardType: 'Premium'),
              compact: compact,
              height: height,
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
    testWidgets('artwork is a network image when provided', (
      tester,
    ) async {
      await _pump(tester);

      final urls = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as NetworkImage).url)
          .toList();

      expect(urls, contains(_artwork));
    });

    testWidgets('no bundled asset is loaded', (tester) async {
      await _pump(tester);
      final assetImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is AssetImage);
      expect(assetImages, isEmpty);
    });
  });

  group('artwork is drawn at its own size', () {
    // The catalog used to serve a 1000x630 canvas holding an ~880x554 card,
    // so ~12% of every edge was transparent margin and a baked-in shadow.
    // The plate enlarged the image 1.205x to crop that away.
    //
    // The art is now exported full bleed — measured 2574x1632, content box
    // flush to all four edges, no alpha. That zoom then had nothing to crop
    // but the card itself: the top of the artwork lost its bank logo and the
    // bottom lost the network mark.
    /// The two transforms wrapping the artwork, innermost first.
    List<Transform> artTransforms(WidgetTester tester) => tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byType(Image),
            matching: find.byType(Transform),
          ),
        )
        .toList();

    Transform uniform(WidgetTester tester) => artTransforms(
      tester,
    ).firstWhere((t) => t.alignment != Alignment.topCenter);

    Transform bottom(WidgetTester tester) => artTransforms(
      tester,
    ).firstWhere((t) => t.alignment == Alignment.topCenter);

    double sx(Transform t) => t.transform.getRow(0)[0];
    double sy(Transform t) => t.transform.getRow(1)[1];

    testWidgets('the old crop that ate the artwork is gone', (tester) async {
      // 1.205x was sized to crop a margin the art no longer has, so it took
      // the bank logo off the top and the network mark off the bottom.
      await _pump(tester);
      expect(sx(uniform(tester)), lessThan(1.05));
    });

    testWidgets('6px of uniform bleed clears every edge', (tester) async {
      // The plate is 320 wide here, so 6px a side is 1 + 12/320.
      await _pump(tester);

      final t = uniform(tester);
      expect(sx(t), closeTo(1 + 12 / 320, 0.0005));
      expect(sy(t), closeTo(1 + 12 / 320, 0.0005));
      expect(320 * (sx(t) - 1) / 2, closeTo(6.0, 0.01));
    });

    testWidgets('the uniform bleed is the same thickness at any width', (
      tester,
    ) async {
      await _pump(tester, width: 640);

      final t = uniform(tester);
      expect(640 * (sx(t) - 1) / 2, closeTo(6.0, 0.01));
    });

    testWidgets('the bottom gets 2px more, and only the bottom', (
      tester,
    ) async {
      // Vertical axis alone, anchored to the top: nothing is taken off the
      // top edge, where the bank mark sits, or off the sides.
      await _pump(tester);

      final t = bottom(tester);
      expect(sx(t), 1.0);
      expect(sy(t), closeTo(1 + 2 / 200, 0.0005));
      expect(200 * (sy(t) - 1), closeTo(2.0, 0.01));
    });

    testWidgets('the extra stays 2px at any height', (tester) async {
      await _pump(tester, height: 400);
      expect(400 * (sy(bottom(tester)) - 1), closeTo(2.0, 0.01));
    });

    testWidgets('so the bottom is bled further than the top', (tester) async {
      // The whole point of the second transform: composed, the bottom edge
      // ends up roughly 2px past what the uniform bleed alone gives it.
      await _pump(tester);

      final u = sy(uniform(tester));
      const h = 200.0;
      final topOverscan = h * (u - 1) / 2;
      final bottomOverscan = topOverscan + 2 * u;

      expect(bottomOverscan - topOverscan, closeTo(2.0, 0.1));
      expect(topOverscan, closeTo(6.0 * 200 / 320, 0.05));
    });

    testWidgets('card-specific art gets the same treatment', (tester) async {
      await _pump(tester);
      expect(sx(uniform(tester)), closeTo(1 + 12 / 320, 0.0005));
      expect(sy(bottom(tester)), closeTo(1 + 2 / 200, 0.0005));
    });

    testWidgets('it fills the plate, cropped rather than stretched', (
      tester,
    ) async {
      // The art is 1.577 and the plate 1.586, so cover trims ~0.5% off one
      // axis. `fill` would stretch the card out of proportion instead.
      await _pump(tester);

      final art = tester
          .widgetList<Image>(find.byType(Image))
          .firstWhere((i) => (i.image as NetworkImage).url == _artwork);

      expect(art.fit, BoxFit.cover);
      expect(art.alignment, Alignment.center);
    });
  });

  group('the marks sit where a real card puts them', () {
    testWidgets('issuer top left, network bottom right', (tester) async {
      await _pump(tester);

      final plate = tester.getRect(find.byType(CardPlate));
      final badges = tester
          .widgetList<LogoBadge>(find.byType(LogoBadge))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();
      final bank = badges.firstWhere((r) => r.left < plate.center.dx);
      final network = badges.firstWhere((r) => r.left > plate.center.dx);

      expect(bank.top, lessThan(plate.center.dy));
      expect(bank.left, lessThan(plate.center.dx));
      expect(network.bottom, greaterThan(plate.center.dy));
      expect(network.right, greaterThan(plate.center.dx));
    });

    testWidgets('an SVG logo url renders as SVG, not as a raster image', (
      tester,
    ) async {
      // The backend serves bank logos as .svg now. Decoding one through
      // Image.network yields nothing at all, so the badge has to pick the
      // vector decoder off the URL.
      //
      // A bundled asset rather than an https URL: flutter_svg's test-mode
      // compute shim rethrows a decode failure synchronously, and
      // flutter_test answers every request with an empty body. The branch
      // under test — `isSvg` — is the same one either way.
      await _pump(tester, bankLogoUrl: 'assets/icons/discover.svg');
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsAtLeastNWidgets(1));
    });

    testWidgets('a raster logo url still renders as an image', (tester) async {
      await _pump(tester);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });

    testWidgets('artwork does not get the monogram stand-in', (tester) async {
      // With no logo to draw, a bare letterform dropped on a designed face
      // reads as a mistake. The gradient plate still gets one.
      await _pump(tester, bankLogoUrl: null);

      expect(find.byType(BankMark), findsNothing);
    });

    testWidgets('a gradient plate still falls back to the monogram', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null, bankLogoUrl: null);

      expect(find.byType(BankMark), findsOne);
    });

    testWidgets('artwork does not get the product name printed over it', (
      tester,
    ) async {
      // The art names the card in its own type.
      await _pump(tester);
      expect(find.text('Eterna'), findsNothing);
    });

    testWidgets('a gradient plate still prints the name', (tester) async {
      await _pump(tester, artworkUrl: null);
      expect(find.text('Eterna'), findsOne);
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

    testWidgets('an artwork plate uses the house radius like any other', (
      tester,
    ) async {
      // The old art carried its own rounded corners, so the plate had to
      // clip at the artwork's rounder radius or show a dark sliver through
      // each curve. Full-bleed art has square corners, so this clip is what
      // rounds them and there is no second radius to match.
      await _pump(tester);
      const u = 200 / 150;
      expect(radiusOf(tester).x, closeTo(9 * u, 0.01));
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
    testWidgets('bank logo sits top left, network logo bottom right on gradient plates', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null);

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

    testWidgets('the network type is not printed with the logo', (tester) async {
      await _pump(tester, artworkUrl: null);
      expect(find.text('MASTERCARD'), findsNothing);
    });

    testWidgets('the name sits to the left of the network mark on gradient plates', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null);
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

  group('the white chip behind a logo', () {
    // The chip is what keeps a bank logo legible over a card of any
    // colour, but a network mark from `network_logo.url` already ships
    // transparent — often white artwork meant for a dark card — so the
    // same white chip would paint a box around it instead of showing it.
    testWidgets('bank logos keep it', (tester) async {
      await _pump(tester, artworkUrl: null);

      final bank = tester
          .widgetList<LogoBadge>(find.byType(LogoBadge))
          .firstWhere((b) => b.url == _bankLogo);
      expect(bank.background, isTrue);
    });

    testWidgets('network marks do not get it', (tester) async {
      await _pump(tester, artworkUrl: null);

      final network = tester
          .widgetList<LogoBadge>(find.byType(LogoBadge))
          .firstWhere((b) => b.url == _networkLogo);
      expect(network.background, isFalse);
    });

    testWidgets('so a network mark is drawn with no Container behind it', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null);

      final network = tester
          .widgetList<LogoBadge>(find.byType(LogoBadge))
          .firstWhere((b) => b.url == _networkLogo);

      // The chip is a Container inside LogoBadge; with background:false
      // LogoBadge renders the image directly and nothing wraps it.
      final containersInside = find.descendant(
        of: find.byWidget(network),
        matching: find.byType(Container),
      );
      expect(containersInside, findsNothing);
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

    testWidgets('no bank logo falls back to the issuer monogram on gradient plates', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null, bankLogoUrl: null);
      expect(find.text('OB'), findsOneWidget);
    });

    testWidgets('no network logo renders no text label on gradient plates', (tester) async {
      await _pump(tester, artworkUrl: null, networkLogoUrl: null, network: 'RuPay');
      expect(tester.takeException(), isNull);
      expect(find.byType(LogoBadge), findsOneWidget); // bank logo only
      expect(find.text('RUPAY'), findsNothing);
    });

    testWidgets('an unknown network shows neither logo nor label', (
      tester,
    ) async {
      await _pump(tester, artworkUrl: null, networkLogoUrl: null, network: 'Something New');
      expect(find.byType(LogoBadge), findsOneWidget);
      expect(find.text('SOMETHING NEW'), findsNothing);
    });

    testWidgets('artwork carries the marks over it', (tester) async {
      // These used to be hidden whenever artwork was present, gated on the
      // catalog's `is_card_specific` flag. That flag is inferred from a URL
      // path, so a card whose artwork is just a background got no marks at
      // all — the card became unidentifiable.
      await _pump(tester);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });

    testWidgets('a plate with no artwork keeps its marks', (tester) async {
      await _pump(tester, artworkUrl: null);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });

    testWidgets('compact mode drops the name and the network label on gradient plates', (
      tester,
    ) async {
      // At thumbnail size the label is a smudge; the logo still reads.
      await _pump(tester, artworkUrl: null, compact: true);
      expect(find.text('Eterna'), findsNothing);
      expect(find.text('MASTERCARD'), findsNothing);
      expect(find.byType(LogoBadge), findsNWidgets(2));
    });
  });
}
