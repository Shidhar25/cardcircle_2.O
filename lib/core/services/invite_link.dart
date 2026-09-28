import 'api_result.dart';

/// Recognises an invite deep link and pulls the token out of it, whichever
/// of the shapes the backend or a share sheet hands back actually arrives.
///
/// Two schemes have to work, since the domain is not live yet:
///
///   * `cardcircle://invite/<token>` or `cardcircle://invite?token=<token>`
///     — the app's own custom scheme, registered in AndroidManifest.xml and
///     Info.plist. Opens the app directly on any device with it installed,
///     with no server-side verification and no domain required, which is
///     what makes it usable for local testing today.
///   * `https://cardcircle.com/invite/<token>` or
///     `.../invite?token=<token>` — the real link the backend's
///     `invite_url` builds from `config.publicBaseUrl`. It parses
///     identically; it just cannot yet open the app itself on a device,
///     since that needs `https://cardcircle.com/.well-known/
///     assetlinks.json` (Android) / `apple-app-site-association` (iOS) to
///     be hosted once the domain is live, and iOS additionally needs a
///     paid Apple Developer account to enable Associated Domains.
///
/// A pure function, deliberately: [Uri] is a plain value type, so this can
/// be tested against every link shape without a running app or a platform
/// channel.
class InviteLink {
  const InviteLink._();

  static const String _customScheme = 'cardcircle';
  static const String _webHost = 'cardcircle.com';

  /// Whether [uri] is one of the invite link shapes this app understands.
  static bool matches(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    if (scheme == _customScheme) return host == 'invite';
    if (scheme == 'https' || scheme == 'http') {
      if (host != _webHost) return false;
      final segments = _segments(uri);
      return segments.isNotEmpty && segments.first == 'invite';
    }
    return false;
  }

  /// The invite token carried by [uri], or null if [uri] isn't a
  /// recognised invite link or carries no token.
  static String? tokenFrom(Uri uri) {
    if (!matches(uri)) return null;

    final fromQuery = uri.queryParameters['token'];
    if (fromQuery != null && fromQuery.trim().isNotEmpty) {
      return fromQuery.trim();
    }

    final segments = _segments(uri);
    if (uri.scheme.toLowerCase() == _customScheme) {
      // cardcircle://invite/<token> -> path segments are just [<token>].
      return segments.isNotEmpty ? segments.first : null;
    }
    // https://cardcircle.com/invite/<token> -> [invite, <token>].
    final index = segments.indexOf('invite');
    if (index == -1 || index + 1 >= segments.length) return null;
    return segments[index + 1];
  }

  static List<String> _segments(Uri uri) =>
      uri.pathSegments.where((s) => s.isNotEmpty).toList();

  /// The message to show for a failed `POST /invites/{token}/redeem`.
  ///
  /// A targeted invite (flow (a), contact-synced) now carries the invited
  /// phone number, and the server answers a redeem from any other number
  /// with 403 — deliberately, so a forwarded link cannot be used by
  /// whoever it lands with instead of the person it was addressed to. A
  /// generic 403 elsewhere in this app means "your session was rejected",
  /// via [ApiResult.isUnauthorised], but that reading is wrong here: the
  /// caller of a redeem is authenticated by definition, so its 403 always
  /// means the phone-number mismatch, never an expired session. This is
  /// called instead of [ApiResult.isUnauthorised]-based copy specifically
  /// to avoid telling someone "please sign in again" when the real answer
  /// is "this invite wasn't for you".
  static String redeemFailureMessage(ApiResult<dynamic> result) {
    if (result.statusCode == 403) {
      return result.display(
        "This invite was sent to a different phone number, so it can't be "
        'redeemed with this account.',
      );
    }
    // Covers the documented re-redeem case too — the server answers an
    // already-`CONSUMED` token with a 400 "already been used", shown
    // as-is: tapping an old invite link a second time is expected and
    // harmless, not an error to alarm anyone over.
    return result.display('Could not use this invite link.');
  }
}
