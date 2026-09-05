/// The OTP request currently outstanding, shared between the login screen
/// and the verify screen.
///
/// The backend throttles repeat sends and returns `requestId: null` when it
/// refuses, so a second `POST /otp/send` for the same number cannot recover
/// the id of the request already in flight. Whoever created that id has to
/// hold onto it. Keeping it here rather than on one screen means the two
/// screens cannot disagree:
///
///   * login remembers the id it created, and reuses it instead of asking
///     for a code the server will only decline — this is what lets someone
///     back out of the verify screen and press Continue again;
///   * verify replaces it after a successful resend, which issues a *new*
///     id and would otherwise leave login holding a stale one;
///   * verify clears it once the code has been used.
///
/// Deliberately in memory only. A code lives about five minutes, and
/// persisting one across launches would mean restoring a request that has
/// almost certainly expired — and writing a live credential handle to disk
/// for no benefit.
class OtpSession {
  const OtpSession._();

  static String? _requestId;
  static String? _phone;
  static DateTime? _expiresAt;

  /// Records the request [requestId] just created for [phone].
  ///
  /// [expiresInSeconds] is the server's `expiresIn`; when absent the
  /// documented default of five minutes is assumed.
  static void remember({
    required String phone,
    required String requestId,
    int? expiresInSeconds,
  }) {
    _phone = phone;
    _requestId = requestId;
    _expiresAt = DateTime.now().add(
      Duration(seconds: expiresInSeconds ?? defaultLifetimeSeconds),
    );
  }

  /// The documented `expiresIn` for a code, used when the server omits it.
  static const int defaultLifetimeSeconds = 300;

  /// The still-valid request id for [phone], or null.
  ///
  /// An expired entry is dropped rather than returned, so a stale id is
  /// never carried into a verify that is certain to fail.
  static String? idFor(String phone) {
    if (_requestId == null || _phone != phone) return null;
    final expiry = _expiresAt;
    if (expiry != null && !DateTime.now().isBefore(expiry)) {
      clear();
      return null;
    }
    return _requestId;
  }

  static void clear() {
    _requestId = null;
    _phone = null;
    _expiresAt = null;
  }

  /// Test seam: lets a test wind the clock forward without sleeping.
  static void rememberForTest({
    required String phone,
    required String requestId,
    required DateTime expiresAt,
  }) {
    _phone = phone;
    _requestId = requestId;
    _expiresAt = expiresAt;
  }
}
