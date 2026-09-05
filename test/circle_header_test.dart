import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:cardcircle/features/auth/state/auth_state.dart';
import 'package:cardcircle/features/circle/presentation/circle_screen.dart';
import 'package:cardcircle/features/circle/state/circle_state.dart';

/// The Circle header gained a second control beside the invite button. The
/// title is a long word at 25pt, so the row is the tightest piece of
/// chrome on the screen — worth pinning that it survives a small phone.
Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => CircleState()),
      ],
      child: const MaterialApp(home: CircleScreen()),
    ),
  );
  await tester.pump();

  // A never-synced account is offered the contact-sync rationale on entry.
  // That dialog is modal, so it swallows every tap until dismissed —
  // exactly what a user would see, and what a test must clear first.
  final notNow = find.text('Not now');
  if (notNow.evaluate().isNotEmpty) {
    await tester.tap(notNow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  group('the header fits alongside the invite button', () {
    for (final width in <double>[430, 390, 360, 320]) {
      testWidgets('no overflow at ${width}px', (tester) async {
        await _pump(tester, Size(width, 800));
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a sync control sits beside invite', (tester) async {
    await _pump(tester, const Size(390, 800));

    final sync = find.byIcon(PhosphorIconsRegular.arrowsClockwise);
    final invite = find.byIcon(PhosphorIconsRegular.userPlus);

    expect(sync, findsOneWidget, reason: 'sync must stay reachable');
    expect(invite, findsOneWidget);

    // Same row, sync to the left of invite.
    final s = tester.getRect(sync);
    final i = tester.getRect(invite);
    expect(s.center.dy, closeTo(i.center.dy, 1));
    expect(s.right, lessThanOrEqualTo(i.left));
  });

  testWidgets('the sync control is present regardless of sync state', (
    tester,
  ) async {
    // The automatic prompt stops once the dashboard reports
    // `iscontactsyncneeded: false`. That is exactly when the manual control
    // has to exist, or contacts added later are never picked up.
    await _pump(tester, const Size(390, 800));
    expect(find.byIcon(PhosphorIconsRegular.arrowsClockwise), findsOneWidget);
  });

  group('the network tabs', () {
    // One tab per endpoint: /follow/following, /follow/followers,
    // /follow/requests/{incoming,outgoing}, /user/contacts/directory.
    testWidgets('all four are shown', (tester) async {
      await _pump(tester, const Size(390, 800));
      for (final label in ['Following', 'Followers', 'Requests', 'Contacts']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the screen is titled Network under a circle eyebrow', (
      tester,
    ) async {
      await _pump(tester, const Size(390, 800));
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('YOUR CIRCLE'), findsOneWidget);
    });

    testWidgets('tapping a tab switches the list', (tester) async {
      await _pump(tester, const Size(390, 800));

      // Following is the default and its empty copy names the tab.
      expect(
        find.textContaining('not following anyone'),
        findsOneWidget,
        reason: 'Following should be the landing tab',
      );

      await tester.tap(find.text('Followers'));
      await tester.pump();
      expect(find.textContaining('Nobody follows you'), findsOneWidget);

      await tester.tap(find.text('Requests'));
      await tester.pump();
      expect(find.textContaining('No follow requests'), findsOneWidget);

      await tester.tap(find.text('Contacts'));
      await tester.pump();
      expect(find.textContaining('contacts'), findsWidgets);
    });

    testWidgets('tabs do not overflow on a small phone', (tester) async {
      await _pump(tester, const Size(320, 700));
      expect(tester.takeException(), isNull);
    });
  });
}
