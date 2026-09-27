import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cardcircle/features/auth/state/auth_state.dart';
import 'package:cardcircle/features/profile/presentation/edit_profile_screen.dart';
import 'package:cardcircle/features/profile/presentation/select_tags_screen.dart';
import 'package:cardcircle/features/profile/state/category_state.dart';
import 'package:cardcircle/shared/models/spend_category.dart';
import 'package:cardcircle/shared/widgets/neo_pop_button.dart';

SpendCategory _cat(String id, String name) => SpendCategory(
  id: id,
  name: name,
  displayName: name,
  description: 'desc',
  iconKey: 'utensils',
  colorHex: '#FF6B6B',
);

/// Whether the screen's primary CTA is currently pressable.
bool _ctaEnabled(WidgetTester tester) {
  final buttons = tester.widgetList<NeoPopButton>(find.byType(NeoPopButton));
  expect(buttons, isNotEmpty, reason: 'no CTA on screen');
  return buttons.last.enabled;
}

/// Pumps the categories picker on a route carrying [arguments], which is how
/// the screen learns whether it is the registration step or Profile's editor.
Future<void> _pumpTags(
  WidgetTester tester, {
  Map<String, dynamic>? arguments,
  List<SpendCategory> mine = const [],
}) async {
  final categories = CategoryState();
  if (mine.isNotEmpty) categories.setMine(mine);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CategoryState>.value(value: categories),
        ChangeNotifierProvider(create: (_) => AuthState()),
      ],
      child: MaterialApp(
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute(
            settings: RouteSettings(
              name: '/select-tags',
              arguments: arguments,
            ),
            builder: (_) => const SelectTagsScreen(),
          ),
        ],
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('ADD CARDS SCREEN')),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('editing categories from Profile', () {
    testWidgets('opens on the categories the user already has', (tester) async {
      // Opening with nothing ticked meant the first save replaced the
      // user's whole selection with only what they tapped on that visit.
      // A pre-filled selection is what makes the CTA live immediately.
      await _pumpTags(
        tester,
        arguments: const {'fromProfile': true},
        mine: [_cat('c1', 'Food'), _cat('c2', 'Travel')],
      );

      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('the registration step starts empty', (tester) async {
      await _pumpTags(tester);

      expect(_ctaEnabled(tester), isFalse);
    });

    testWidgets('drops the registration chrome', (tester) async {
      await _pumpTags(
        tester,
        arguments: const {'fromProfile': true},
        mine: [_cat('c1', 'Food')],
      );

      // "Skip" and "Step 2 of 3" belong to a sign-up run, not to editing a
      // setting you already have.
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Step 2 of 3 — Personalize'), findsNothing);
      expect(find.text('Your categories'), findsOne);
      // NeoPopButtonText uppercases its label.
      expect(find.text('SAVE CATEGORIES'), findsOne);
      expect(find.text('NEXT STEP'), findsNothing);
    });

    testWidgets('the registration step keeps it', (tester) async {
      await _pumpTags(tester);

      expect(find.text('Skip'), findsOne);
      expect(find.text('Step 2 of 3 — Personalize'), findsOne);
      expect(find.text('NEXT STEP'), findsOne);
    });

    testWidgets('skipping an edit returns to Profile, not Add Cards', (
      tester,
    ) async {
      // The editor has no Skip, so the only way out is back — and back must
      // not land on the next registration step.
      await _pumpTags(
        tester,
        arguments: const {'fromProfile': true},
        mine: [_cat('c1', 'Food')],
      );

      expect(find.text('ADD CARDS SCREEN'), findsNothing);
    });
  });

  group('the edit profile save button', () {
    Future<void> pumpProfile(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthState(),
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('wakes up when the fields are filled in', (tester) async {
      // `isFormValid` is read in build(), and nothing rebuilt the screen on
      // a keystroke — so a profile with no email on file opened with the
      // button dead and typing one in never revived it.
      await pumpProfile(tester);
      expect(_ctaEnabled(tester), isFalse);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Shridhar Hande');
      await tester.pump();
      await tester.enterText(fields.at(1), 'shridhar@example.com');
      await tester.pump();

      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('goes back to sleep when a field is cleared', (tester) async {
      await pumpProfile(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Shridhar Hande');
      await tester.enterText(fields.at(1), 'shridhar@example.com');
      await tester.pump();
      expect(_ctaEnabled(tester), isTrue);

      await tester.enterText(fields.at(1), '');
      await tester.pump();

      expect(_ctaEnabled(tester), isFalse);
    });
  });
}
