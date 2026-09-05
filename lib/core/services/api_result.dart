import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger_service.dart';

/// The outcome of a write to the backend, carrying whatever the server said
/// about it.
///
/// Endpoints used to return a bare `bool`, which threw away the one thing
/// the user needed: the reason. A rejected follow, an expired session and a
/// card that was already added all collapsed into `false`, and every screen
/// papered over them with its own invented sentence — "Please try again" —
/// regardless of what actually happened. This keeps the server's own wording
/// and hands it to the UI.
class ApiResult<T> {
  final bool ok;

  /// The server's message, verbatim when it sent one. Safe to show: these
  /// endpoints return human-readable strings by design.
  final String? message;

  /// The `data` payload, when the caller needs it.
  final T? data;

  /// HTTP status, for logging and for distinguishing auth failures.
  final int? statusCode;

  /// The backend's machine-readable error code, where it sends one —
  /// `USERNAME_EXISTS`, `PHONE_EXISTS`, `MAX_ATTEMPTS`, `INVALID_TOKEN` and
  /// so on. Branch on this rather than on the message text, which is prose
  /// and may be reworded at any time.
  final String? code;

  const ApiResult({
    required this.ok,
    this.message,
    this.data,
    this.statusCode,
    this.code,
  });

  const ApiResult.success({this.message, this.data, this.statusCode})
    : ok = true,
      code = null;

  const ApiResult.failure(this.message, {this.statusCode, this.code})
    : ok = false,
      data = null;

  /// The session expired or was rejected. Worth distinguishing so callers
  /// can send the user back to login rather than showing a puzzling error.
  bool get isUnauthorised => statusCode == 401 || statusCode == 403;

  /// The message to show, falling back to [ifSilent] when the server sent
  /// nothing useful.
  ///
  /// Callers pass a fallback describing *this* action, so the user never
  /// sees a bare "Something went wrong".
  String display(String ifSilent) {
    final m = message?.trim();
    return (m == null || m.isEmpty) ? ifSilent : m;
  }

  /// Reads the backend's response envelope.
  ///
  /// The API has two error shapes. `asyncHandler` routes return
  /// `{success, status, message}` where `status` is the HTTP code; routes
  /// with hand-written try/catch return `{success, message, code, error}`.
  /// Both are read here, so callers never have to know which kind of route
  /// they hit.
  ///
  /// Tolerates an empty body (some DELETEs return 204 with nothing) and a
  /// non-JSON body (a proxy error page), neither of which should throw.
  static ApiResult<Map<String, dynamic>> fromResponse(
    http.Response response, {
    required String action,
  }) {
    final status = response.statusCode;
    final httpOk = status >= 200 && status < 300;

    if (response.body.isEmpty) {
      return ApiResult(ok: httpOk, statusCode: status);
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      LoggerService.warning('$action: non-JSON response ($status)');
      return ApiResult(
        ok: false,
        statusCode: status,
        message: httpOk ? null : 'Server error ($status).',
      );
    }

    if (body is! Map<String, dynamic>) {
      return ApiResult(ok: httpOk, statusCode: status);
    }

    // `success` is authoritative when present; some endpoints omit it and
    // rely on the status code alone.
    final ok = body.containsKey('success')
        ? (httpOk && body['success'] == true)
        : httpOk;

    final data = body['data'];

    // `code` is the machine-readable error code on try/catch routes. Some
    // routes instead nest it in `data` (OTP verify's MAX_ATTEMPTS), so look
    // in both rather than only the top level.
    final code =
        (body['code'] as String?) ??
        (data is Map<String, dynamic> ? data['code'] as String? : null);

    final result = ApiResult<Map<String, dynamic>>(
      ok: ok,
      statusCode: status,
      message: body['message'] as String?,
      code: code,
      data: data is Map<String, dynamic> ? data : null,
    );

    if (!ok) {
      LoggerService.warning(
        '$action failed ($status${code == null ? '' : '/$code'}): '
        '${result.message}',
      );
    }
    return result;
  }
}
