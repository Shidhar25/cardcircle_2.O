/// The invite token an unauthenticated visitor arrived with, held across
/// the login -> OTP -> create-profile flow.
///
/// A tapped invite link is handled by [InvitePreviewScreen] before the
/// person has an account, so the token cannot be redeemed there — redeeming
/// requires auth (see [ApiService.redeemInvite]). It has to survive three
/// screens of onboarding to be redeemed the moment a session exists, and
/// named-route arguments do not thread through screens that do not ask for
/// them, so it lives here instead — the same reasoning as [OtpSession].
///
/// Deliberately in memory only, like [OtpSession]: an invite token is
/// meant to be used within one sitting, and persisting it across launches
/// risks silently redeeming a stale invite on a later, unrelated login.
class PendingInvite {
  const PendingInvite._();

  static String? _token;

  /// Records [token] as the invite to redeem once the visitor has a
  /// session, replacing whatever was pending before — only the most
  /// recently tapped link should win.
  static void remember(String token) {
    _token = token;
  }

  /// True while a token is waiting to be redeemed.
  static bool get hasPending => _token != null;

  /// Hands back the pending token and clears it.
  ///
  /// One-shot by design: whoever calls this is about to attempt the
  /// redeem, successful or not, and either way this token should not be
  /// tried again on a later, unrelated login.
  static String? consume() {
    final token = _token;
    _token = null;
    return token;
  }
}
