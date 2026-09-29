import '../../main.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'api_service.dart';
import 'invite_link.dart';
import 'logger_service.dart';

/// The invite token (and inviter name) an unauthenticated visitor arrived
/// with, held across the login -> OTP -> create-profile flow.
///
/// A tapped invite link is handled by `InvitePreviewScreen` before the
/// person has an account, so the token cannot be redeemed there — redeeming
/// requires auth (see [ApiService.redeemInvite]). It has to survive up to
/// three screens of onboarding to be redeemed the moment a session exists,
/// and named-route arguments do not thread through screens that do not ask
/// for them, so it lives here instead — the same reasoning as `OtpSession`.
///
/// Deliberately in memory only, like `OtpSession`: an invite token is meant
/// to be used within one sitting, and persisting it across launches risks
/// silently redeeming a stale invite on a later, unrelated login.
class PendingInvite {
  const PendingInvite._();

  static String? _token;
  static String? _inviterName;

  /// Records [token] as the invite to redeem once the visitor has a
  /// session, replacing whatever was pending before — only the most
  /// recently tapped link should win. [inviterName], when known, is shown
  /// on the Login screen's "Invited by ..." checkbox — purely a courtesy;
  /// redemption itself never depends on having a name.
  static void remember(String token, {String? inviterName}) {
    _token = token;
    _inviterName = inviterName;
  }

  /// True while a token is waiting to be redeemed.
  static bool get hasPending => _token != null;

  /// The inviter's name, for display only — null before [remember] is
  /// called, after [consume] or [clear], or when the invite preview never
  /// got a name back from the server.
  static String? get inviterName => _inviterName;

  /// The token without consuming it, for a screen (Login) that needs to
  /// react to a pending invite's presence without deciding whether it will
  /// actually be redeemed.
  static String? peekToken() => _token;

  /// Hands back the pending token and clears it.
  ///
  /// One-shot by design: whoever calls this is about to attempt the
  /// redeem, successful or not, and either way this token should not be
  /// tried again on a later, unrelated login.
  static String? consume() {
    final token = _token;
    _token = null;
    _inviterName = null;
    return token;
  }

  /// Drops the pending invite without redeeming it.
  ///
  /// Used when the person unchecks Login's "Invited by ..." box — they are
  /// explicitly declining the follow-back this invite would otherwise
  /// create, so it must not be silently redeemed later just because a
  /// token was still sitting here.
  static void clear() {
    _token = null;
    _inviterName = null;
  }

  /// Completes the "onboard (or log in), then follow the inviter" flow
  /// from an invite link tapped before this session existed.
  ///
  /// Called once a session exists — right after `CreateProfileScreen`
  /// saves a brand-new profile, or right after an existing user's OTP
  /// verifies — since redeeming requires auth and neither of those flows
  /// has one before this point. A missing token (nothing was pending, or
  /// the person unchecked the invite box) is a silent no-op; any other
  /// outcome is reported through the app-wide messenger rather than a
  /// screen's own, since by the time the response lands the screen that
  /// triggered this has usually already navigated away.
  static Future<void> redeemIfAny() async {
    final token = consume();
    if (token == null) return;

    final result = await ApiService.redeemInvite(token);
    LoggerService.info(
      'Post-login invite redeem for token $token: '
      '${result.ok ? 'ok' : 'failed (${result.message})'}',
    );

    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    if (result.ok) {
      messenger.showSuccess(
        result.display('Follow request sent to whoever invited you.'),
      );
    } else {
      // Not `showResult` — its generic 403-means-"session expired" reading
      // is wrong for this endpoint. See [InviteLink.redeemFailureMessage].
      // A targeted invite link carries the invited phone number, and this
      // account may not be it (the link was forwarded, or typed in on a
      // different number than intended) — a real, expected outcome here,
      // not a reason to suggest anything is wrong with the account itself.
      messenger.showError(
        '${InviteLink.redeemFailureMessage(result)} Your account is set up '
        'either way.',
      );
    }
  }
}
