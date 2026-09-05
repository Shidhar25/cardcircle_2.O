import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/config/remote_config.dart';
import 'package:cardcircle/shared/widgets/legal_text.dart';

/// The live config serves these under `legal`.
const _terms = 'http://cardcircle.com/terms';
const _privacy = 'http://cardcircle.com/privacy';

Future<void> _pump(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: LegalText(text: text)),
    ),
  );
  await tester.pump();
}

/// Every span in the rendered line, flattened.
List<TextSpan> _spans(WidgetTester tester) {
  final root = tester.widget<Text>(find.byType(Text)).textSpan as TextSpan;
  return (root.children ?? []).whereType<TextSpan>().toList();
}

TextSpan? _spanFor(WidgetTester tester, String phrase) {
  for (final s in _spans(tester)) {
    if (s.text == phrase) return s;
  }
  return null;
}

void main() {
  setUp(() {
    RemoteConfig.instance.applyForTest(const {
      'legal': {'termsUrl': _terms, 'privacyUrl': _privacy},
    });
  });

  group('links come from the config', () {
    testWidgets('both documents become tappable spans', (tester) async {
      await _pump(
        tester,
        'I agree to the Terms of Service and Privacy Policy.',
      );

      expect(_spanFor(tester, 'Terms of Service')?.recognizer, isNotNull);
      expect(_spanFor(tester, 'Privacy Policy')?.recognizer, isNotNull);
    });

    testWidgets('surrounding copy stays plain', (tester) async {
      await _pump(
        tester,
        'I agree to the Terms of Service and Privacy Policy.',
      );

      final plain = _spans(
        tester,
      ).where((s) => s.recognizer == null).map((s) => s.text).join();
      expect(plain, 'I agree to the  and .');
    });

    testWidgets('the longer phrase wins, so "Terms" alone is not split', (
      tester,
    ) async {
      await _pump(tester, 'Read the Terms of Service.');

      expect(_spanFor(tester, 'Terms of Service'), isNotNull);
      expect(_spanFor(tester, 'Terms'), isNull);
    });

    testWidgets('short forms are linked too', (tester) async {
      await _pump(tester, 'See Terms and Privacy.');

      expect(_spanFor(tester, 'Terms')?.recognizer, isNotNull);
      expect(_spanFor(tester, 'Privacy')?.recognizer, isNotNull);
    });
  });

  group('a blank server value falls back to the bundled URL', () {
    testWidgets('the link stays live rather than going plain', (tester) async {
      // RemoteConfig.text() treats a blank override as "not set" and uses
      // the compiled-in default. For legal links that is the behaviour we
      // want: an operator accidentally clearing the field should not strip
      // the user's route to the terms.
      RemoteConfig.instance.applyForTest(const {
        'legal': {'termsUrl': '', 'privacyUrl': '   '},
      });
      await _pump(tester, 'Terms of Service and Privacy Policy');

      expect(_spanFor(tester, 'Terms of Service')?.recognizer, isNotNull);
      expect(_spanFor(tester, 'Privacy Policy')?.recognizer, isNotNull);
    });

    testWidgets('a server value overrides the default', (tester) async {
      RemoteConfig.instance.applyForTest(const {
        'legal': {'termsUrl': _terms, 'privacyUrl': _privacy},
      });
      expect(config.text('legal.termsUrl'), _terms);
      expect(config.text('legal.privacyUrl'), _privacy);

      await _pump(tester, 'Terms of Service');
      expect(_spanFor(tester, 'Terms of Service')?.recognizer, isNotNull);
    });
  });

  group('recogniser lifetime', () {
    testWidgets('the same recogniser survives a rebuild', (tester) async {
      // Recreating them per frame means a rebuild during a press disposes
      // the recogniser mid-gesture.
      await _pump(tester, 'Terms of Service');
      final first = _spanFor(tester, 'Terms of Service')!.recognizer;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LegalText(text: 'Terms of Service')),
        ),
      );
      await tester.pump();

      expect(_spanFor(tester, 'Terms of Service')!.recognizer, same(first));
    });
  });

  testWidgets('a line with no legal phrases renders unchanged', (tester) async {
    await _pump(tester, 'Nothing to agree to here.');
    final spans = _spans(tester);
    expect(spans.length, 1);
    expect(spans.single.text, 'Nothing to agree to here.');
    expect(spans.single.recognizer, isNull);
  });
}
