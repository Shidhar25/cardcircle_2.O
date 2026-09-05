/// The outcome of asking the backend to send or resend an OTP.
///
/// This exists because "failed" and "unusable" are not the same thing. A
/// throttled send means a valid code is already in the user's inbox:
///
/// ```json
/// {"success": false,
///  "message": "Please wait 56 seconds before requesting a new OTP",
///  "data": {"requestId": null, "expiresIn": null, "retryAfter": 56}}
/// ```
///
/// Note the `requestId` is **null** on a throttled send — the server will
/// not re-issue the id of the outstanding request. So a throttled response
/// alone cannot carry the flow forward; the caller has to remember the id
/// from its own earlier successful send. [LoginScreen] does exactly that,
/// which is what lets someone leave the OTP screen and come back without
/// dead-ending on "OTP already sent".
class OtpSendResult {
  /// The request to verify against. Present both on a fresh send and on a
  /// rate-limited one, and the only thing that decides whether the flow can
  /// continue.
  final String? requestId;

  /// Seconds until a *new* code may be requested. Drives the resend
  /// countdown, so it reflects the server's real cooldown rather than a
  /// guess made on the client.
  final int? retryAfter;

  /// Seconds until the current code stops being accepted.
  final int? expiresIn;

  /// True only for a freshly sent code. False means the server declined to
  /// send another one.
  final bool sentNow;

  /// The server's explanation when it declined.
  final String? message;

  const OtpSendResult({
    this.requestId,
    this.retryAfter,
    this.expiresIn,
    this.sentNow = false,
    this.message,
  });

  /// A total failure — no request to verify against, so the flow cannot
  /// continue. Network errors and malformed responses land here.
  const OtpSendResult.failed(this.message)
    : requestId = null,
      retryAfter = null,
      expiresIn = null,
      sentNow = false;

  /// Whether the caller can proceed to the verify screen.
  ///
  /// Deliberately keyed on having a `requestId` rather than on `success`:
  /// a rate-limited response is still usable.
  bool get canProceed => requestId != null && requestId!.isNotEmpty;

  /// Whether the server refused to send a new code but the existing one
  /// still stands.
  bool get isThrottled => canProceed && !sentNow;

  factory OtpSendResult.fromResponse(
    Map<String, dynamic> body, {
    required bool httpOk,
  }) {
    final success = httpOk && body['success'] == true;
    final data = body['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final requestId = map['requestId'];
    return OtpSendResult(
      requestId: requestId is String && requestId.isNotEmpty ? requestId : null,
      retryAfter: asInt(map['retryAfter']),
      expiresIn: asInt(map['expiresIn']),
      sentNow: success,
      message: body['message'] as String?,
    );
  }
}
