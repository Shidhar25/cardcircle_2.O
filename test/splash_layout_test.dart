import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cardcircle/features/auth/state/auth_state.dart';
import 'package:cardcircle/features/onboarding/presentation/splash_screen.dart';

/// Pumps the splash and steps through its animation.
///
/// The emblem's parts are sized as fractions of a fixed box, so an overflow
/// only appears once the pieces have actually animated in — checking the
/// first frame alone would miss it.
Future<void> _run(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: const MaterialApp(home: SplashScreen()),
    ),
  );

  // Step through the 4.3s timeline, stopping short of the auto-advance so
  // the test does not follow the navigation that ends it.
  for (var ms = 0; ms <= 4100; ms += 200) {
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.takeException(),
      isNull,
      reason: 'overflow at ${size.width}x${size.height}, t=${ms}ms',
    );
  }
}

void main() {
  group('the splash lays out without overflowing', () {
    // A real device found a 1.8px overflow in the figure column that the
    // suite had no coverage for: its three parts summed to 1.05 of a fixed
    // height box. Every phone size, through the whole animation.
    for (final size in const [
      Size(320, 640), // small Android
      Size(360, 800),
      Size(390, 844), // iPhone 14
      Size(430, 932), // iPhone Pro Max
      Size(412, 915),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await _run(tester, size);
      });
    }

    testWidgets('and on a short viewport, where vertical space is tightest', (
      tester,
    ) async {
      await _run(tester, const Size(360, 592));
    });
  });
}
