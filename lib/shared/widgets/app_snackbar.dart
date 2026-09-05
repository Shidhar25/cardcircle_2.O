import 'package:flutter/material.dart';

import '../../core/services/api_result.dart';
import '../../core/theme/app_theme.dart';

/// One place to show the backend talking back.
///
/// Screens used to invent their own sentence for every outcome — "Please try
/// again", "Something went wrong" — so the server's actual explanation
/// ("You already follow this user", "Card already in your wallet") never
/// reached the person who needed it. These helpers prefer the server's
/// wording and fall back to app copy only when the response carried none.
///
/// The [ScaffoldMessengerState] extension is the preferred entry point:
/// captured *before* an `await`, it sidesteps the whole class of
/// use-after-dispose bugs that come from holding a `BuildContext` across an
/// async gap.
extension ApiFeedback on ScaffoldMessengerState {
  void _show(String message, {required Color background}) {
    if (message.trim().isEmpty) return;
    // Stacked snackbars queue and outlive the action that caused them, so
    // replace rather than append.
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppText.sans(13, color: AppColors.background),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showSuccess(String message) =>
      _show(message, background: AppColors.teal);

  void showError(String message) =>
      _show(message, background: AppColors.destructive);

  /// Reports an [ApiResult], showing the server's message when there is one.
  ///
  /// [onSuccess] and [onFailure] are this action's own wording, used only
  /// when the server said nothing — so the user still learns what happened
  /// rather than seeing a blank or a generic apology.
  void showResult(
    ApiResult<dynamic> result, {
    required String onSuccess,
    required String onFailure,
  }) {
    if (result.ok) {
      _show(result.display(onSuccess), background: AppColors.teal);
    } else {
      _show(
        result.display(
          result.isUnauthorised
              ? 'Your session expired. Please log in again.'
              : onFailure,
        ),
        background: AppColors.destructive,
      );
    }
  }
}

/// Context-based equivalents, for call sites with no async gap to worry
/// about.
class AppSnackbar {
  const AppSnackbar._();

  static void success(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSuccess(message);

  static void error(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showError(message);

  static void result(
    BuildContext context,
    ApiResult<dynamic> result, {
    required String onSuccess,
    required String onFailure,
  }) => ScaffoldMessenger.of(
    context,
  ).showResult(result, onSuccess: onSuccess, onFailure: onFailure);
}
