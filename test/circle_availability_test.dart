import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/circle_availability.dart';
import 'package:cardcircle/shared/widgets/circle_availability_view.dart';

CircleHolder _holder(String name) =>
    CircleHolder(userId: name, displayName: name, cards: ['HDFC Regalia Gold']);

const _four = CircleAvailability(
  count: 4,
  users: [
    CircleHolder(userId: 'u1', displayName: 'rahul_k'),
    CircleHolder(userId: 'u2', displayName: 'priya'),
    CircleHolder(userId: 'u3', displayName: 'aman'),
    CircleHolder(userId: 'u4', displayName: 'sneha'),
  ],
);

/// The strip as the feed builds it: inside a card whose own tap opens the
/// benefit, which is the gesture the strip has to win.
Widget _feedRow(CircleAvailability availability, {VoidCallback? onOpen}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: InkWell(
              onTap: onOpen,
              child: CircleAvailabilityStrip(availability: availability),
            ),
          ),
        ),
      ),
    );

void main() {
  group('the strip states the count', () {
    testWidgets('names nobody, so the line stays one line', (tester) async {
      await tester.pumpWidget(_feedRow(_four));

      expect(find.text('4 people in your circle can avail this'), findsOne);
      expect(find.textContaining('rahul_k'), findsNothing);
    });

    testWidgets('a single holder is a person, not people', (tester) async {
      await tester.pumpWidget(
        _feedRow(CircleAvailability(count: 1, users: [_holder('rahul_k')])),
      );

      expect(find.text('1 person in your circle can avail this'), findsOne);
    });
  });

  group('tapping the count names the people', () {
    testWidgets('the sheet lists every friend and their cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feedRow(
          CircleAvailability(
            count: 2,
            users: [_holder('rahul_k'), _holder('priya')],
          ),
        ),
      );

      await tester.tap(find.text('2 people in your circle can avail this'));
      await tester.pumpAndSettle();

      expect(find.text('Who can avail this'), findsOne);
      expect(find.text('rahul_k'), findsOne);
      expect(find.text('priya'), findsOne);
      expect(find.text('HDFC Regalia Gold'), findsNWidgets(2));
    });

    testWidgets('the benefit underneath does not open too', (tester) async {
      var opened = false;
      await tester.pumpWidget(_feedRow(_four, onOpen: () => opened = true));

      await tester.tap(find.text('4 people in your circle can avail this'));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
    });

    testWidgets('a count with no names opens the benefit instead', (
      tester,
    ) async {
      // Permissions can hide the list while the number still stands. There
      // is nothing to name, so the card's own tap must still work.
      var opened = false;
      await tester.pumpWidget(
        _feedRow(
          const CircleAvailability(count: 3, users: []),
          onOpen: () => opened = true,
        ),
      );

      await tester.tap(find.text('3 people in your circle can avail this'));
      await tester.pumpAndSettle();

      expect(find.text('Who can avail this'), findsNothing);
      expect(opened, isTrue);
    });
  });
}
