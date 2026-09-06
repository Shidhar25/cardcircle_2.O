import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:cardcircle/features/auth/state/auth_state.dart';
import 'package:cardcircle/features/feed/presentation/hack_detail_screen.dart';
import 'package:cardcircle/shared/models/hack.dart';

Hack _hack({int stepCount = 3}) => Hack(
  id: 'h1',
  name: 'Swipe abroad, skip the markup',
  heading:
      'Use your ixigo AU card for international transactions and pay zero '
      'forex markup, on a card that costs nothing to hold.',
  steps: List.generate(
    stepCount,
    (i) => HackStep(
      name: 'Step ${i + 1}',
      heading: 'Do the thing number ${i + 1}',
      icon: '💳',
      description:
          'A reasonably long description of step ${i + 1} so the row has '
          'real height, the way the live payload does.',
    ),
  ),
  // Catalog card ids, matched against CreditCard.catalogCardId.
  cardIds: const ['cat-1'],
  // A URL is required for the hero to render an Image at all. The request
  // fails under flutter_test, which is the realistic case anyway: the
  // errorBuilder runs and the placeholder shows through.
  image: 'https://example.invalid/hero.webp',
  savings: '3.5% saved on every international transaction, with no cap',
  category: 'Forex / International',
  rating: 4.8,
  availedby: '',
  thingsToNote: const ['Decline dynamic currency conversion at the terminal.'],
);

/// Pumps the screen at a given viewport with a given status-bar inset.
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  double topInset = 47, // a notched phone
  int stepCount = 3,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    // The screen names which of the reader's own cards a benefit works
    // with, so it reads AuthState.
    ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(top: topInset)),
          child: child!,
        ),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const HackDetailScreen(),
          settings: RouteSettings(arguments: _hack(stepCount: stepCount)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the back button clears the status bar', () {
    // It sits on a hero that deliberately paints under the status bar, so a
    // constant `top` put it under the notch.
    for (final inset in <double>[0, 24, 47, 59]) {
      testWidgets('inset ${inset}px', (tester) async {
        await _pump(tester, size: const Size(390, 844), topInset: inset);

        final back = find.byIcon(PhosphorIconsRegular.arrowLeft);
        expect(back, findsOneWidget);

        final top = tester.getTopLeft(back).dy;
        expect(
          top,
          greaterThanOrEqualTo(inset),
          reason: 'back button overlaps the status bar',
        );
      });
    }
  });

  group('the hero is shaped by the artwork, not the screen', () {
    // Benefit images are wide — 2720x1360 (2:1) across most of the
    // catalog. A hero shaped to the phone (~1.28:1) cropped roughly a
    // third off each image, which is what "going off the screen" was.
    Size heroSize(WidgetTester tester) =>
        tester.getSize(find.byType(Image).first);

    testWidgets('the hero is close to the 2:1 artwork ratio', (tester) async {
      await _pump(tester, size: const Size(390, 844));
      final s = heroSize(tester);
      expect(s.width / s.height, closeTo(1.9, 0.05));
    });

    testWidgets('height follows width, not viewport height', (tester) async {
      // Same width, very different heights: the hero must not change.
      await _pump(tester, size: const Size(390, 844));
      final tallScreen = heroSize(tester).height;

      await _pump(tester, size: const Size(390, 640));
      final shortScreen = heroSize(tester).height;

      expect(shortScreen, closeTo(tallScreen, 0.5));
    });

    testWidgets('a wider screen does get a taller hero', (tester) async {
      await _pump(tester, size: const Size(390, 844));
      final narrow = heroSize(tester).height;

      await _pump(tester, size: const Size(600, 844));
      final wide = heroSize(tester).height;

      expect(wide, greaterThan(narrow));
    });

    testWidgets('it stays within its clamp on an extreme viewport', (
      tester,
    ) async {
      await _pump(tester, size: const Size(1400, 900));
      expect(heroSize(tester).height, lessThanOrEqualTo(300));

      await _pump(tester, size: const Size(280, 640));
      expect(heroSize(tester).height, greaterThanOrEqualTo(180));
    });

    testWidgets('the artwork is contained, never cropped', (tester) async {
      await _pump(tester, size: const Size(390, 844));

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      // Two: a blurred cover backdrop, then the whole image on top.
      expect(images.length, 2);
      expect(images.first.fit, BoxFit.cover, reason: 'backdrop fills');
      expect(
        images.last.fit,
        BoxFit.contain,
        reason: 'the image the user reads must not be cropped',
      );
    });
  });

  group('only the steps section scrolls', () {
    testWidgets('a long step list is capped and scrollable', (tester) async {
      const viewport = Size(390, 844);
      await _pump(tester, size: viewport, stepCount: 12);

      final list = find.byType(ListView);
      expect(list, findsOneWidget, reason: 'the steps list is the only one');

      // 0.42 of an 844pt viewport, clamped to 420.
      final height = tester.getSize(list).height;
      expect(height, lessThanOrEqualTo(420));

      // It really scrolls, rather than just being clipped.
      final position = tester.widget<ListView>(list).controller!.position;
      expect(position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('a short step list shrinks to fit instead of padding out', (
      tester,
    ) async {
      await _pump(tester, size: const Size(390, 844), stepCount: 1);

      final list = find.byType(ListView);
      final position = tester.widget<ListView>(list).controller!.position;
      expect(
        position.maxScrollExtent,
        0,
        reason: 'one step should not create a scrollable region',
      );
    });

    testWidgets('the page itself still scrolls independently', (tester) async {
      await _pump(tester, size: const Size(390, 844), stepCount: 12);

      final page = find.byType(SingleChildScrollView);
      expect(page, findsOneWidget);

      final before = tester.getTopLeft(find.byType(ListView)).dy;
      await tester.drag(page, const Offset(0, -200));
      await tester.pump();
      final after = tester.getTopLeft(find.byType(ListView)).dy;

      expect(after, lessThan(before), reason: 'the page did not scroll');
    });
  });

  testWidgets('the title renders below the hero, not over it', (tester) async {
    await _pump(tester, size: const Size(390, 844));

    final image = tester.getRect(find.byType(Image).first);
    final title = tester.getTopLeft(find.text('Swipe abroad, skip the markup'));

    expect(title.dy, greaterThanOrEqualTo(image.bottom - 56));
  });
}
