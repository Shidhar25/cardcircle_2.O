/// How a feedback question is answered.
enum FeedbackAnswerType {
  /// Two choices, submitted as `"yes"` / `"no"`.
  yesNo,

  /// One to five, submitted as `"1"`..`"5"`.
  rating,

  /// Something the app does not know how to render.
  unknown;

  static FeedbackAnswerType parse(String? raw) {
    switch (raw?.toUpperCase().replaceAll(RegExp(r'[_\s-]'), '')) {
      case 'YESNO':
      case 'BOOLEAN':
      case 'BOOL':
        return FeedbackAnswerType.yesNo;
      case 'RATING':
      case 'SCALE':
      case 'STARS':
        return FeedbackAnswerType.rating;
      default:
        return FeedbackAnswerType.unknown;
    }
  }
}

/// One question from `GET /feedback/{context}/prompt`.
///
/// The questions live in the database and are editable without a deploy, so
/// this parses defensively: a question whose type the app cannot render is
/// kept as [FeedbackAnswerType.unknown] and skipped rather than crashing
/// the sheet, which means adding a new type server-side degrades to
/// "that question is not asked yet" instead of breaking feedback entirely.
class FeedbackQuestion {
  final String id;
  final String text;
  final FeedbackAnswerType type;
  final int order;

  const FeedbackQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.order,
  });

  /// Whether the app can render an answer control for this question.
  bool get isRenderable => type != FeedbackAnswerType.unknown;

  /// Reads one row.
  ///
  /// Field names are accepted in both the prefixed (`question_id`) and bare
  /// (`id`) spellings: the table columns are `text`/`type`/`order` while the
  /// submit payload uses `question_id`, and the prompt response was not
  /// visible to check which it serialises. Accepting both costs nothing and
  /// removes a guess.
  static FeedbackQuestion? tryParse(Map<String, dynamic> json) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return null;
    }

    final id = pick(['question_id', 'id', 'questionId']);
    final text = pick(['question_text', 'text', 'questionText', 'question']);
    // Without an id the answer cannot be submitted, and without text there
    // is nothing to ask.
    if (id == null || text == null) return null;

    final rawOrder = json['display_order'] ?? json['order'] ?? json['sort'];
    final order = rawOrder is num
        ? rawOrder.toInt()
        : int.tryParse(rawOrder?.toString() ?? '') ?? 0;

    return FeedbackQuestion(
      id: id,
      text: text,
      type: FeedbackAnswerType.parse(
        pick(['question_type', 'type', 'questionType']),
      ),
      order: order,
    );
  }
}

/// The answer to `GET /feedback/{context}/prompt`.
class FeedbackPrompt {
  final bool shouldPrompt;
  final List<FeedbackQuestion> questions;

  const FeedbackPrompt({required this.shouldPrompt, required this.questions});

  static const FeedbackPrompt none = FeedbackPrompt(
    shouldPrompt: false,
    questions: [],
  );

  /// Whether there is actually something to show.
  ///
  /// `should_prompt` alone is not enough: the server can say yes while
  /// every question is of a type this build cannot render, and showing an
  /// empty sheet would be worse than showing none.
  bool get hasSomethingToAsk =>
      shouldPrompt && questions.any((q) => q.isRenderable);

  static FeedbackPrompt parse(Map<String, dynamic>? data) {
    if (data == null) return none;

    final raw = data['questions'];
    final questions = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(FeedbackQuestion.tryParse)
              .nonNulls
              .toList()
        : <FeedbackQuestion>[];
    questions.sort((a, b) => a.order.compareTo(b.order));

    final flag = data['should_prompt'] ?? data['shouldPrompt'];
    return FeedbackPrompt(
      shouldPrompt: flag is bool ? flag : flag?.toString() == 'true',
      questions: questions,
    );
  }
}
