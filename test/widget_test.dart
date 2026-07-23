import 'package:cardcircle/features/auth/state/auth_state.dart';
import 'package:cardcircle/features/circle/state/circle_state.dart';
import 'package:cardcircle/features/feed/state/feed_state.dart';
import 'package:cardcircle/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthState()),
          ChangeNotifierProvider(create: (_) => FeedState()),
          ChangeNotifierProvider(create: (_) => CircleState()),
        ],
        child: const CardCircleApp(),
      ),
    );
    expect(find.byType(CardCircleApp), findsOneWidget);
  });
}
