import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/widgets/meta_chip.dart';

/// Real values from `GET /hacks/getmyhacks`. `savings` is documented as a
/// figure but arrives as a full sentence, which is what overflowed the card.
const _longSavings =
    '3.5% saved on every international transaction, with no cap';
const _longCards = 'ixigo AU Credit Card, HDFC Regalia Gold, Axis Magnus';

/// Builds the chip inside the layout it actually lives in: two flexible
/// chips sharing the row with a fixed-width like button.
Widget _row({required double width, required String savings}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: MetaChip(
                      icon: Icons.trending_up,
                      iconColor: Colors.teal,
                      background: Colors.black12,
                      label: savings,
                      labelColor: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: MetaChip(
                      icon: Icons.credit_card,
                      iconColor: Colors.amber,
                      background: Colors.black12,
                      label: _longCards,
                      labelColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Stands in for the like button, which is never allowed to
            // shrink.
            Container(width: 56, height: 28, color: Colors.black12),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('the chip row survives real backend text', () {
    // A RenderFlex overflow is reported as an exception during layout, so
    // takeException() being null is a genuine assertion that the yellow
    // stripes are gone — not a proxy for it.
    for (final width in <double>[360, 320, 300, 280]) {
      testWidgets('no overflow at ${width}px wide', (tester) async {
        await tester.pumpWidget(_row(width: width, savings: _longSavings));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a pathologically long label still fits', (tester) async {
      await tester.pumpWidget(_row(width: 320, savings: 'x' * 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short label is fine too', (tester) async {
      await tester.pumpWidget(_row(width: 360, savings: '5%'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty label does not break layout', (tester) async {
      await tester.pumpWidget(_row(width: 360, savings: ''));
      expect(tester.takeException(), isNull);
    });
  });

  group('truncation', () {
    testWidgets('the label is capped to one ellipsised line', (tester) async {
      await tester.pumpWidget(_row(width: 320, savings: _longSavings));

      final text = tester.widget<Text>(find.text(_longSavings));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.softWrap, isFalse);
    });

    testWidgets('the chip never exceeds the space it is given', (tester) async {
      const width = 300.0;
      await tester.pumpWidget(_row(width: width, savings: _longSavings));

      for (final size
          in tester
              .widgetList<MetaChip>(find.byType(MetaChip))
              .map((w) => tester.getSize(find.byWidget(w)))) {
        expect(size.width, lessThanOrEqualTo(width));
      }
    });
  });
}
