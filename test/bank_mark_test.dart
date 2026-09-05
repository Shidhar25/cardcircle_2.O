import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/bank_brand.dart';
import 'package:cardcircle/shared/widgets/bank_mark.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('renders the issuer monogram', (tester) async {
    // Logos come from the catalog now; this is the fallback that runs when
    // a card has no logo URL, so it must always produce something.
    await pump(
      tester,
      const BankMark(bankId: 'hdfc-bank', bankName: 'HDFC Bank'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('HD'), findsOneWidget);
  });

  testWidgets('unmapped bank still renders a monogram', (tester) async {
    await pump(
      tester,
      const BankMark(bankId: 'some-new-bank', bankName: 'Some New Bank'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SN'), findsOneWidget);
  });

  test('initials skip the word "bank"', () {
    expect(bankInitials('bank-of-baroda'), 'OB');
    expect(bankInitials('axis-bank'), 'AX');
    expect(bankInitials('Some New Bank'), 'SN');
  });
}
