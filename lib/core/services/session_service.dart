import 'logger_service.dart';

/// The bridge between "the tokens are gone" and "show the login screen".
///
/// [ApiService] discovers an expired session deep inside a request, where
/// there is no BuildContext and no navigator. It calls [expire]; the app
/// root registers [onSessionExpired] once at startup and does the visible
/// part — clearing AuthState and routing to /login.
///
/// Expiry is announced at most once per session. A screen that fires three
/// requests in parallel gets three 401s and one failed refresh, and the user
/// should see one "please sign in again", not three.
class SessionService {
  const SessionService._();

  /// Set once by the app root. Null before the first frame, and in tests.
  static void Function()? onSessionExpired;

  static bool _announced = false;

  /// True once this run has given up on the session — used to stop retrying
  /// a refresh that is known to be dead.
  static bool get isExpired => _announced;

  /// Announces that the refresh token is no longer usable.
  ///
  /// Tokens are cleared by the caller ([ApiService]) before this runs, so a
  /// listener can assume the session is already gone.
  static void expire() {
    if (_announced) return;
    _announced = true;
    LoggerService.warning('Session expired — sending the user back to login.');
    onSessionExpired?.call();
  }

  /// Re-arms the announcement after a successful sign-in.
  static void reset() => _announced = false;
}
