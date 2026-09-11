import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger_service.dart';

/// Why a renewal attempt ended — the difference between "sign in again" and
/// "try again later", which is the difference between logging the user out
/// and leaving them alone.
enum RefreshResult {
  /// A new access token is in hand; the request can be replayed.
  renewed,

  /// There is no refresh token, or the server refused it. The session is
  /// over.
  rejected,

  /// The refresh never got an answer — offline, timeout, a 5xx. The tokens
  /// are untouched.
  unreachable,
}

/// An HTTP client that renews an expired access token and replays the
/// request, so no caller has to know about token lifetimes.
///
/// Only requests that actually carry an `Authorization` header are eligible:
/// the login, OTP and refresh calls pass through untouched, which is what
/// keeps the refresh itself from recursing.
///
/// One refresh at a time. A screen that fires several requests at once gets
/// several 401s at once; without the shared future they would each spend the
/// refresh token, and every attempt after the first would fail against a
/// server that rotates it.
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;

  /// Attempts a token renewal.
  final Future<RefreshResult> Function() refresh;

  /// The Authorization header value to replay with, read *after* a
  /// successful refresh so the retry carries the new token.
  final String? Function() authHeader;

  /// Called when renewal fails and the user has to sign in again.
  final void Function() onSessionExpired;

  AuthHttpClient({
    required this.refresh,
    required this.authHeader,
    required this.onSessionExpired,
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  static Future<RefreshResult>? _inFlight;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Buffer the body before the first send: a streamed request cannot be
    // replayed, and a retry with an empty body is worse than no retry.
    final replayable = request is http.Request ? request : null;
    final bodyBytes = replayable?.bodyBytes;

    final response = await _inner.send(request);
    if (response.statusCode != 401 ||
        replayable == null ||
        !request.headers.containsKey('Authorization')) {
      return response;
    }

    // Drain the 401 so the connection is not left half-read.
    await response.stream.drain<void>();
    LoggerService.info('401 on ${request.url.path} — refreshing the token.');

    final outcome = await (_inFlight ??= _refreshOnce());
    if (outcome == RefreshResult.rejected) {
      onSessionExpired();
      // A synthetic failure rather than a throw: every caller already
      // treats a non-200 as "this failed", and the user is being routed to
      // login anyway.
      return _failed(request, 'Your session expired. Please sign in again.');
    }
    if (outcome == RefreshResult.unreachable) {
      // The token may well still be good — the network is what failed. The
      // request fails for now and the session is left intact, so stepping
      // back into signal is enough to recover.
      return _failed(request, 'Could not reach the server.');
    }

    final retry = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    if (bodyBytes != null) retry.bodyBytes = bodyBytes;
    final header = authHeader();
    if (header != null) retry.headers['Authorization'] = header;

    return _inner.send(retry);
  }

  Future<RefreshResult> _refreshOnce() async {
    try {
      return await refresh();
    } finally {
      // Cleared only after the awaiting requests have read it, so the next
      // 401 starts a fresh attempt instead of reusing a settled result.
      scheduleMicrotask(() => _inFlight = null);
    }
  }

  /// A synthetic 401 carrying the envelope every caller already parses —
  /// an empty body would make `jsonDecode` throw on the way out and turn a
  /// clean "signed out" into a logged crash.
  static http.StreamedResponse _failed(
    http.BaseRequest request,
    String message,
  ) {
    final body = utf8.encode(
      jsonEncode({'success': false, 'message': message}),
    );
    return http.StreamedResponse(
      Stream.value(body),
      401,
      contentLength: body.length,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      reasonPhrase: 'Unauthorized',
    );
  }

  @override
  void close() => _inner.close();
}
