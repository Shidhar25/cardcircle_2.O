import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/feedback_question.dart';
import 'package:cardcircle/shared/models/hack.dart';

/// The two seeded questions for `hack_benefits_first_view`.
Map<String, dynamic> _prompt({
  bool shouldPrompt = true,
  List<Map<String, dynamic>>? questions,
}) => {
  'should_prompt': shouldPrompt,
  'questions':
      questions ??
      [
        {
          'question_id': 'q1',
          'question_text': 'Did this hack work for you?',
          'question_type': 'YES_NO',
          'display_order': 1,
        },
        {
          'question_id': 'q2',
          'question_text': 'How helpful was this hack?',
          'question_type': 'RATING',
          'display_order': 2,
        },
      ],
};

void main() {
  group('reading the prompt', () {
    test('parses the seeded questions in order', () {
      final p = FeedbackPrompt.parse(_prompt());
      expect(p.shouldPrompt, isTrue);
      expect(p.questions.map((q) => q.id), ['q1', 'q2']);
      expect(p.questions.first.type, FeedbackAnswerType.yesNo);
      expect(p.questions.last.type, FeedbackAnswerType.rating);
    });

    test('display_order decides the order, not array position', () {
      final p = FeedbackPrompt.parse(
        _prompt(
          questions: [
            {
              'question_id': 'second',
              'question_text': 'B',
              'question_type': 'RATING',
              'display_order': 9,
            },
            {
              'question_id': 'first',
              'question_text': 'A',
              'question_type': 'YES_NO',
              'display_order': 1,
            },
          ],
        ),
      );
      expect(p.questions.map((q) => q.id), ['first', 'second']);
    });

    test('an already-answered context asks nothing', () {
      final p = FeedbackPrompt.parse(
        _prompt(shouldPrompt: false, questions: const []),
      );
      expect(p.hasSomethingToAsk, isFalse);
    });

    test('a null payload is not an error, just nothing to ask', () {
      expect(FeedbackPrompt.parse(null).hasSomethingToAsk, isFalse);
    });
  });

  group('field-name tolerance', () {
    // The table columns are text/type/order while the submit payload uses
    // question_id, and the prompt response was not visible to check which
    // spelling it serialises. Both are accepted rather than guessed.
    test('bare column names parse too', () {
      final p = FeedbackPrompt.parse({
        'should_prompt': true,
        'questions': [
          {'id': 'q1', 'text': 'Did it work?', 'type': 'YES_NO', 'order': 1},
        ],
      });
      expect(p.questions.single.id, 'q1');
      expect(p.questions.single.text, 'Did it work?');
      expect(p.questions.single.type, FeedbackAnswerType.yesNo);
    });

    test('camelCase parses too', () {
      final p = FeedbackPrompt.parse({
        'shouldPrompt': true,
        'questions': [
          {'questionId': 'q1', 'questionText': 'X', 'questionType': 'RATING'},
        ],
      });
      expect(p.shouldPrompt, isTrue);
      expect(p.questions.single.type, FeedbackAnswerType.rating);
    });

    test('type matching ignores case and separators', () {
      for (final raw in ['YES_NO', 'yes_no', 'YesNo', 'YES NO']) {
        expect(
          FeedbackAnswerType.parse(raw),
          FeedbackAnswerType.yesNo,
          reason: raw,
        );
      }
    });
  });

  group('degrading rather than breaking', () {
    test('a question with no id is dropped — it could not be submitted', () {
      final p = FeedbackPrompt.parse(
        _prompt(
          questions: [
            {'question_text': 'orphan', 'question_type': 'YES_NO'},
          ],
        ),
      );
      expect(p.questions, isEmpty);
      expect(p.hasSomethingToAsk, isFalse);
    });

    test('a question with no text is dropped', () {
      final p = FeedbackPrompt.parse(
        _prompt(
          questions: [
            {'question_id': 'q1', 'question_type': 'YES_NO'},
          ],
        ),
      );
      expect(p.questions, isEmpty);
    });

    test('an unknown type is kept but not rendered', () {
      // A new question type added server-side must not break feedback for
      // builds that predate it.
      final p = FeedbackPrompt.parse(
        _prompt(
          questions: [
            {
              'question_id': 'q1',
              'question_text': 'Tell us more',
              'question_type': 'FREE_TEXT',
            },
          ],
        ),
      );
      expect(p.questions.single.type, FeedbackAnswerType.unknown);
      expect(p.questions.single.isRenderable, isFalse);
      // should_prompt is true, but there is nothing this build can ask.
      expect(p.hasSomethingToAsk, isFalse);
    });

    test('a renderable question alongside an unknown one still asks', () {
      final p = FeedbackPrompt.parse(
        _prompt(
          questions: [
            {'question_id': 'a', 'question_text': 'A', 'question_type': 'X'},
            {
              'question_id': 'b',
              'question_text': 'B',
              'question_type': 'RATING',
            },
          ],
        ),
      );
      expect(p.hasSomethingToAsk, isTrue);
    });

    test('a malformed questions field yields none', () {
      for (final bad in ['nope', 42, null, <String, dynamic>{}]) {
        final p = FeedbackPrompt.parse({
          'should_prompt': true,
          'questions': bad,
        });
        expect(p.questions, isEmpty, reason: '$bad');
      }
    });

    test('a missing display_order sorts stably rather than throwing', () {
      final p = FeedbackPrompt.parse(
        _prompt(
          questions: [
            {'question_id': 'a', 'question_text': 'A', 'question_type': 'X'},
            {'question_id': 'b', 'question_text': 'B', 'question_type': 'X'},
          ],
        ),
      );
      expect(p.questions.map((q) => q.id), ['a', 'b']);
    });
  });

  group('the prompt embedded on a hack', () {
    Map<String, dynamic> hackJson({Object? prompt, bool includeKey = true}) => {
      'id': 'h1',
      'name': 'A benefit',
      'heading': 'Does a thing',
      'steps': <dynamic>[],
      'card_ids': <String>[],
      if (includeKey) 'feedback_prompt': prompt,
    };

    test('an embedded prompt is read off the list payload', () {
      final h = Hack.fromJson(
        hackJson(
          prompt: {
            'should_prompt': true,
            'questions': [
              {
                'question_id': 'q1',
                'question_text': 'A',
                'question_type': 'YES_NO',
              },
            ],
          },
        ),
      );
      expect(h.feedbackPrompt, isNotNull);
      expect(h.feedbackPrompt!.hasSomethingToAsk, isTrue);
    });

    test('an embedded "already answered" is authoritative, not absent', () {
      // This is the distinction the fix turns on: the server said no, so
      // the app must not fall back to asking the standalone endpoint.
      final h = Hack.fromJson(
        hackJson(prompt: {'should_prompt': false, 'questions': <dynamic>[]}),
      );
      expect(h.feedbackPrompt, isNotNull);
      expect(h.feedbackPrompt!.hasSomethingToAsk, isFalse);
    });

    test('a payload with no feedback_prompt key leaves it null', () {
      // A benefit reached outside a list, or an older backend. Null is the
      // only case where the standalone endpoint still needs calling —
      // collapsing it to "nothing to ask" would stop ever asking there.
      final h = Hack.fromJson(hackJson(includeKey: false));
      expect(h.feedbackPrompt, isNull);
    });

    test('a null feedback_prompt value is still an answer, not a gap', () {
      final h = Hack.fromJson(hackJson(prompt: null));
      expect(h.feedbackPrompt, isNotNull);
      expect(h.feedbackPrompt!.hasSomethingToAsk, isFalse);
    });

    test('answering spends the prompt without touching anything else', () {
      final before = Hack.fromJson(
        hackJson(
          prompt: {
            'should_prompt': true,
            'questions': [
              {
                'question_id': 'q1',
                'question_text': 'A',
                'question_type': 'YES_NO',
              },
            ],
          },
        ),
      );
      final after = before.withFeedbackAnswered();

      expect(after.feedbackPrompt!.hasSomethingToAsk, isFalse);
      expect(after.id, before.id);
      expect(after.name, before.name);
      expect(after.platformRating, before.platformRating);
      expect(after.myRating, before.myRating);
    });
  });
}
