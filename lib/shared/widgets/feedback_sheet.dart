import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../models/feedback_question.dart';
import 'app_snackbar.dart';
import 'primitives.dart';
import 'rating_stars.dart';

/// A one-time feedback prompt, built from questions the server sends.
///
/// The questions live in the database, so this renders whatever arrives
/// rather than hardcoding the two seeded ones — adding or reordering a
/// question is a server change with no release.
///
/// Answers are submitted together, never one at a time. The API rejects a
/// second answer to the same question, so a partial submission would
/// permanently cost the user the chance to answer the rest.
class FeedbackSheet extends StatefulWidget {
  final String context;
  final List<FeedbackQuestion> questions;

  /// The benefit being rated, sent alongside the answers.
  final String? hackId;

  const FeedbackSheet({
    super.key,
    required this.context,
    required this.questions,
    this.hackId,
  });

  /// Shows the sheet, returning true when answers were submitted.
  ///
  /// Dismissible on purpose: feedback interrupts something the user chose
  /// to do, and refusing to let them out of it would be worse than never
  /// asking. The server still reports `should_prompt: true` next time.
  static Future<bool> show(
    BuildContext context, {
    required String feedbackContext,
    required List<FeedbackQuestion> questions,
    String? hackId,
  }) async {
    final answered = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FeedbackSheet(
        context: feedbackContext,
        questions: questions,
        hackId: hackId,
      ),
    );
    return answered ?? false;
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  /// question id -> answer string, in the form the API expects.
  final Map<String, String> _answers = {};
  bool _submitting = false;

  /// Only questions this build can render an answer control for.
  late final List<FeedbackQuestion> _questions = widget.questions
      .where((q) => q.isRenderable)
      .toList();

  bool get _complete => _answers.length == _questions.length;

  Future<void> _submit() async {
    if (!_complete || _submitting) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    final result = await ApiService.submitFeedback(
      context: widget.context,
      answers: _answers,
      hackId: widget.hackId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.ok) {
      messenger.showError(result.display('Could not send your feedback.'));
      return;
    }

    navigator.pop(true);
    messenger.showSuccess(result.display('Thanks — that helps.'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const MonoLabel(
            'QUICK QUESTION',
            size: 10,
            letterSpacing: 2,
            color: AppColors.textDim,
          ),
          const SizedBox(height: AppSpacing.lg),

          for (final q in _questions) ...[
            Text(
              q.text,
              style: AppText.sans(
                14,
                weight: FontWeight.w500,
                color: AppColors.text,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AnswerControl(
              question: q,
              value: _answers[q.id],
              enabled: !_submitting,
              onAnswer: (value) => setState(() => _answers[q.id] = value),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text(
                    'Not now',
                    style: AppText.sans(13, color: AppColors.textDim),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GoldButton(
                  label: 'Send',
                  height: 46,
                  // Every question must be answered: the API refuses a
                  // second answer to the same question, so submitting a
                  // partial set would lock the rest out for good.
                  enabled: _complete,
                  loading: _submitting,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The control for one question, chosen by its type.
class _AnswerControl extends StatelessWidget {
  final FeedbackQuestion question;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onAnswer;

  const _AnswerControl({
    required this.question,
    required this.value,
    required this.enabled,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case FeedbackAnswerType.yesNo:
        return Row(
          children: [
            for (final option in const ['yes', 'no'])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _Choice(
                  label: option == 'yes' ? 'Yes' : 'No',
                  selected: value == option,
                  enabled: enabled,
                  onTap: () => onAnswer(option),
                ),
              ),
          ],
        );

      case FeedbackAnswerType.rating:
        return RatingPicker(
          value: int.tryParse(value ?? ''),
          busy: !enabled,
          onRate: (stars) => onAnswer('$stars'),
        );

      case FeedbackAnswerType.unknown:
        // Filtered out before rendering; this keeps the switch exhaustive.
        return const SizedBox.shrink();
    }
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: selected
              ? AppColors.gold.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.sans(
            13,
            weight: FontWeight.w500,
            color: selected ? AppColors.gold : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}
