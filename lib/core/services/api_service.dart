import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/otp_send_result.dart';
import 'api_result.dart';
import 'auth_http_client.dart';
import 'session_service.dart';
import '../../shared/models/feedback_question.dart';
import '../../shared/models/paged_result.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';

class ApiService {
  // One backend for everything — auth/user endpoints and the bank/card
  // catalog share a host, so card ids selected in Add Cards still resolve
  // when Your Cards fetches them back. Point both at a LAN IP (not
  // `localhost`) to test against a local server from a physical device.
  static const String baseUrl = 'http://13.205.204.182:8080/api/v1';
  static const String cardsCatalogBaseUrl = baseUrl;

  static String? _accessToken;
  static String? _refreshToken;

  /// Every request goes through this client, so an access token that
  /// expired mid-session is renewed and the request replayed without the
  /// calling screen ever seeing the 401. Requests without an Authorization
  /// header — login, OTP, the refresh call itself — pass straight through.
  static final http.Client _client = AuthHttpClient(
    refresh: refreshToken,
    authHeader: () => _accessToken == null ? null : 'Bearer $_accessToken',
    onSessionExpired: _endSession,
  );

  /// Drops the stored tokens and tells the app to ask for a sign-in.
  ///
  /// [refreshToken] already clears them when the server rejects the refresh;
  /// this also covers the case where there was no refresh token to try.
  static void _endSession() {
    logout();
    SessionService.expire();
  }

  static Future<void> init() async {
    _accessToken = LocalStorageService.getString('@auth/accessToken');
    _refreshToken = LocalStorageService.getString('@auth/refreshToken');
    if (_accessToken != null) {
      LoggerService.info('Loaded cached access token.');
    }
  }

  static String? get accessToken => _accessToken;
  static String? get refreshTokenString => _refreshToken;

  static Map<String, String> _headers({bool requireAuth = false}) {
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (requireAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // 1. Fetch bootstrap config
  static Future<Map<String, dynamic>?> getBootstrapConfig() async {
    try {
      LoggerService.info('Fetching bootstrap config from backend...');
      final response = await _client.get(
        Uri.parse('$baseUrl/bootstrap/config'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          LoggerService.debug('Bootstrap config loaded successfully.');
          return body['data'];
        }
      }
      LoggerService.warning(
        'Failed to load bootstrap config: Status ${response.statusCode}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching bootstrap config', e, stack);
    }
    return null;
  }

  // 2. Send OTP
  ///
  /// Returns a result rather than a nullable map because a refusal is not
  /// necessarily a dead end: when a code was sent moments ago the backend
  /// replies `success: false` but hands back the same `requestId`, which is
  /// still verifiable. See [OtpSendResult].
  static Future<OtpSendResult> sendOtp(
    String phoneNumber,
    String purpose,
  ) async {
    try {
      LoggerService.info('Sending OTP to $phoneNumber for $purpose...');
      final response = await _client.post(
        Uri.parse('$baseUrl/otp/send'),
        headers: _headers(),
        body: jsonEncode({'phoneNumber': phoneNumber, 'purpose': purpose}),
      );
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return const OtpSendResult.failed('Unexpected response from server.');
      }
      final result = OtpSendResult.fromResponse(
        body,
        httpOk: response.statusCode == 200,
      );
      if (result.sentNow) {
        LoggerService.info('OTP request sent successfully.');
      } else {
        LoggerService.warning('OTP send declined: ${result.message}');
      }
      return result;
    } catch (e, stack) {
      LoggerService.error('Error sending OTP', e, stack);
      return const OtpSendResult.failed(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 3. Verify OTP
  ///
  /// A wrong code is not a flat failure: the backend replies with
  /// `data.remainingAttempts`, and with `data.code = "MAX_ATTEMPTS"` once
  /// they run out. Returning a nullable map threw that away and left the
  /// screen saying "Invalid OTP code" right up until the request was locked,
  /// with no warning that it was about to be. The result carries it through.
  static Future<ApiResult<Map<String, dynamic>>> verifyOtp(
    String requestId,
    String otp,
  ) async {
    try {
      LoggerService.info('Verifying OTP for request $requestId...');
      final response = await _client.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: _headers(),
        body: jsonEncode({'requestId': requestId, 'otp': otp}),
      );
      final result = ApiResult.fromResponse(response, action: 'Verify OTP');
      if (result.ok) {
        LoggerService.info('OTP verified successfully.');
        await _storeTokens(result.data?['tokens']);
      }
      return result;
    } catch (e, stack) {
      LoggerService.error('Error verifying OTP', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Persists an auth token pair, if the payload carries one.
  ///
  /// Both OTP verify (returning user) and create-profile (new user) hand
  /// back the same `{accessToken, refreshToken}` shape, so the storage runs
  /// in one place rather than being written out twice.
  static Future<void> _storeTokens(dynamic tokens) async {
    if (tokens is! Map) return;
    final access = tokens['accessToken'];
    final refresh = tokens['refreshToken'];
    if (access is! String || access.isEmpty) return;

    _accessToken = access;
    await LocalStorageService.setString('@auth/accessToken', access);
    if (refresh is String && refresh.isNotEmpty) {
      _refreshToken = refresh;
      await LocalStorageService.setString('@auth/refreshToken', refresh);
    }
    // There is a live session again, so a future expiry is worth announcing.
    SessionService.reset();
  }

  /// Whether the stored session can still be used, renewing it if needed.
  ///
  /// Called from the splash before routing to Home. Without it a user whose
  /// access token expired while the app was closed lands on Home and watches
  /// every panel fail at once before the first 401 bounces them out.
  ///
  /// Returns false only when there is nothing to sign in with. An
  /// unreachable server leaves the existing tokens alone and answers true,
  /// so a cold start offline still opens the app.
  static Future<bool> ensureSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return _accessToken != null && _accessToken!.isNotEmpty;
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      // Left to the interceptor: if this token has expired, the first real
      // request refreshes it, which costs nothing on the happy path.
      return true;
    }
    // Only a hard rejection sends the user to login; an unreachable server
    // is not proof the session is over.
    return await refreshToken() != RefreshResult.rejected;
  }

  // 4. Resend OTP
  ///
  /// Same contract as [sendOtp]: a throttled resend still carries a usable
  /// `requestId` and a `retryAfter` the screen can count down from.
  static Future<OtpSendResult> resendOtp(String requestId) async {
    try {
      LoggerService.info('Resending OTP for request $requestId...');
      final response = await _client.post(
        Uri.parse('$baseUrl/otp/resend'),
        headers: _headers(),
        body: jsonEncode({'requestId': requestId}),
      );
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return const OtpSendResult.failed('Unexpected response from server.');
      }
      final result = OtpSendResult.fromResponse(
        body,
        httpOk: response.statusCode == 200,
      );
      if (result.sentNow) {
        LoggerService.info('OTP resent successfully.');
      } else {
        LoggerService.warning('OTP resend declined: ${result.message}');
      }
      return result;
    } catch (e, stack) {
      LoggerService.error('Error resending OTP', e, stack);
      return const OtpSendResult.failed(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 5. Refresh token
  ///
  /// Called on demand by [AuthHttpClient] when a request comes back 401,
  /// and by [ensureSession] at startup.
  ///
  /// [RefreshResult.rejected] — no refresh token, or the server refused it —
  /// is the "sign in again" case, and the stored tokens are dropped so
  /// nothing retries with credentials known to be dead. A network failure is
  /// deliberately *not* that: it answers [RefreshResult.unreachable] and
  /// leaves the tokens alone, so a user who walked into a tunnel keeps their
  /// session.
  static Future<RefreshResult> refreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return RefreshResult.rejected;
    }
    try {
      LoggerService.info('Refreshing access token...');
      // Intentionally the bare client: this request carries no
      // Authorization header, so routing it through the interceptor could
      // only ever recurse.
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: _headers(),
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        // Stored through the same path as sign-in, so a server that rotates
        // the refresh token on use keeps working — writing only the access
        // token would leave the next refresh holding a spent one.
        await _storeTokens(body['data']);
        if (_accessToken == null || _accessToken!.isEmpty) {
          return RefreshResult.rejected;
        }
        LoggerService.info('Access token refreshed successfully.');
        return RefreshResult.renewed;
      }
      LoggerService.warning(
        'Refresh token failed: ${body is Map ? body['message'] : response.body}',
      );
      // A 5xx is the server having a bad minute, not a verdict on this
      // token — retryable, so the session survives it.
      if (response.statusCode >= 500) return RefreshResult.unreachable;

      // Anything else means the refresh token is spent or revoked; drop it
      // rather than retrying with it forever.
      await logout();
      return RefreshResult.rejected;
    } catch (e, stack) {
      LoggerService.error('Error refreshing token', e, stack);
      return RefreshResult.unreachable;
    }
  }

  // 6. Verify token
  static Future<bool> verifyToken(String token) async {
    try {
      LoggerService.info('Verifying access token...');
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/verify-token'),
        headers: _headers(),
        body: jsonEncode({'accessToken': token}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        return data['valid'] == true;
      }
    } catch (e, stack) {
      LoggerService.error('Error verifying token', e, stack);
    }
    return false;
  }

  // 7. Check if username is unique
  static Future<bool> checkUsername(String username) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/user/check-username'),
        headers: _headers(),
        body: jsonEncode({'username': username}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']['isUnique'] == true;
      }
    } catch (e, stack) {
      LoggerService.error('Error checking username', e, stack);
    }
    return false;
  }

  // 8. Create user profile
  /// Creates the profile and signs the new user in.
  ///
  /// Returns the full result so the form can show the backend's specific
  /// complaint — `USERNAME_EXISTS`, `PHONE_EXISTS`, `EMAIL_EXISTS` — instead
  /// of a blanket "Failed to create profile" that gives the user nothing to
  /// act on. The created user is at `data.user`.
  static Future<ApiResult<Map<String, dynamic>>> createProfile({
    required String username,
    required String name,
    required String email,
    required String phoneNumber,
    required String dateOfBirth,
  }) async {
    try {
      LoggerService.info('Creating profile for $username...');
      final response = await _client.post(
        Uri.parse('$baseUrl/user/create-profile'),
        headers: _headers(),
        body: jsonEncode({
          'username': username,
          'name': name,
          'email': email,
          'phoneNumber': phoneNumber,
          'dateOfBirth': dateOfBirth,
        }),
      );
      final result = ApiResult.fromResponse(response, action: 'Create profile');
      if (result.ok) await _storeTokens(result.data?['tokens']);
      return result;
    } catch (e, stack) {
      LoggerService.error('Error creating profile', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 9. Get current user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      LoggerService.info('Fetching user profile...');
      final response = await _client.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
      LoggerService.warning(
        'Get user profile failed: ${body['message'] ?? response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error getting user profile', e, stack);
    }
    return null;
  }

  // 10. Update current user profile
  static Future<Map<String, dynamic>?> updateUserProfile({
    required String name,
    required String email,
    required String dateOfBirth,
    required String profilePictureUrl,
  }) async {
    try {
      LoggerService.info('Updating user profile...');
      final response = await _client.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          'name': name,
          'email': email,
          'dateOfBirth': dateOfBirth,
          'profilePictureUrl': profilePictureUrl,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
      LoggerService.warning(
        'Update user profile failed: ${body['message'] ?? response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error updating user profile', e, stack);
    }
    return null;
  }

  // 11. Get all categories
  static Future<List<Map<String, dynamic>>?> getCategories() =>
      _fetchCategories('$baseUrl/category/list', auth: false);

  /// The categories this user has tagged (`GET /category/user`).
  ///
  /// Same envelope as the full list, plus `isFavorite` and `taggedAt` per
  /// row, so it reads through the same parser.
  static Future<List<Map<String, dynamic>>?> getUserCategories() =>
      _fetchCategories('$baseUrl/category/user', auth: true);

  static Future<List<Map<String, dynamic>>?> _fetchCategories(
    String url, {
    required bool auth,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: _headers(requireAuth: auth),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          body is Map<String, dynamic> &&
          body['success'] == true) {
        // Indexing `body['data']['categories']` directly threw whenever the
        // response was shaped even slightly differently — a 200 with no
        // data, or a bare list — and took the screen down with it.
        final data = body['data'];
        final list = data is Map ? data['categories'] : data;
        if (list is! List) {
          LoggerService.warning('Categories response had no list: $url');
          return null;
        }
        return list.whereType<Map<String, dynamic>>().toList();
      }
      LoggerService.warning(
        'Fetch categories failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching categories from $url', e, stack);
    }
    return null;
  }

  // 12. Tag categories to user profile
  static Future<ApiResult<Map<String, dynamic>>> tagCategories(
    List<String> categoryIds,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/category/tag'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'categoryIds': categoryIds}),
      );
      return ApiResult.fromResponse(response, action: 'Tag categories');
    } catch (e, stack) {
      LoggerService.error('Error tagging categories', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  static const String _assetBase =
      'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com';

  /// Genuine bank logos live under this prefix. Anything else — notably
  /// `/credit-card-images/` and `/generic/bank-generic-cards/` — is card
  /// artwork, not a logo.
  static const String _bankLogoPrefix = '/generic/bank-logos/';

  /// bank id -> logo URL. Null means "no genuine logo for this bank".
  static Map<String, String?>? _bankLogoCache;

  /// Guards against the `/banks` endpoint returning **card artwork** in its
  /// `logo` field, which it currently does for most banks:
  ///
  ///     axis-bank → /credit-card-images/axis/axis-neo.webp
  ///     hdfc-bank → /credit-card-images/hdfc/marriott-bonvoy-hdfc.webp
  ///
  /// Rendering those puts a picture of a credit card where the bank's mark
  /// should be. Anything outside the bank-logo path is therefore rejected and
  /// the conventional logo URL is used instead — that resolves for the banks
  /// which do have a mark, and 404s harmlessly for the ones that don't, since
  /// `LogoBadge` hides itself when the image fails.
  ///
  /// Once `/banks` returns real logo URLs (or null) this can collapse back to
  /// simply trusting the field.
  static String? sanitizedBankLogo(String? bankId, String? raw) {
    if (raw != null && raw.contains(_bankLogoPrefix)) return raw;
    if (bankId == null || bankId.isEmpty) return null;
    return '$_assetBase$_bankLogoPrefix$bankId.webp';
  }

  // 13. Get all banks (catalog)
  static Future<List<Map<String, dynamic>>?> getBanks() async {
    try {
      final response = await _client.get(
        Uri.parse('$cardsCatalogBaseUrl/banks'),
        headers: _headers(),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        final banks = list.map(_normalizeBank).nonNulls.toList();
        _bankLogoCache = {
          for (final b in banks)
            (b['id'] ?? '') as String: sanitizedBankLogo(
              b['id'] as String?,
              b['logo'] as String?,
            ),
        };
        return banks;
      }
      LoggerService.warning(
        'Fetch banks failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching banks', e, stack);
    }
    return null;
  }

  /// Normalises one `/banks` row.
  ///
  /// This endpoint has shipped two contracts: the older deployment returns
  /// a plain array of bank names, the newer microservice returns objects
  /// with `id`/`name`/`logo`. Casting every row to a Map threw on the older
  /// shape and left Add Cards with no banks at all, so both are accepted
  /// and a bare name is given a slug id derived from it.
  static Map<String, dynamic>? _normalizeBank(dynamic item) {
    if (item is Map<String, dynamic>) {
      final name = (item['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      final id = (item['id'] as String?)?.trim();
      return {
        'id': (id == null || id.isEmpty) ? slugifyBankName(name) : id,
        'name': name,
        'logo': item['logo'],
        'card_count': item['card_count'],
      };
    }
    if (item is String && item.trim().isNotEmpty) {
      final name = item.trim();
      return {'id': slugifyBankName(name), 'name': name, 'logo': null};
    }
    return null;
  }

  /// Derives the id the object contract would have used for a bank name,
  /// so the two shapes produce interchangeable ids.
  static String slugifyBankName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Bank logo for a bank id, sanitized so card artwork can never leak in.
  static Future<String?> bankLogoFor(String bankId) async {
    if (bankId.isEmpty) return null;
    if (_bankLogoCache == null) await getBanks();
    return _bankLogoCache?[bankId] ?? sanitizedBankLogo(bankId, null);
  }

  // 14. Browse a bank's cards that the user has NOT already added.
  //
  // Uses the authenticated `/user/cards/browse` endpoint rather than the
  // public catalog: because it knows who the caller is, it excludes cards
  // already in their wallet, so Add Cards never offers a duplicate.
  static Future<List<Map<String, dynamic>>?> getCardsByBank(
    String bankName,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/user/cards/browse?banks=${Uri.encodeComponent(bankName)}&limit=200',
        ),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final raw = body['data'];
        final List<dynamic> list = raw is Map
            ? (raw['cards'] ?? raw['items'] ?? const [])
            : (raw is List ? raw : const []);
        return list
            .map((item) => normalizeCatalogCard(item as Map<String, dynamic>))
            .toList();
      }
      LoggerService.warning(
        'Browse cards failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error browsing cards for $bankName', e, stack);
    }
    return null;
  }

  /// Maps a browse/catalog row onto the single shape the Add Cards screen
  /// reads, so the UI doesn't have to care whether the backend returned the
  /// grouped catalog layout (one row per product, `variants[]` inside), the
  /// nested layout (`card.name`, `image.url`) or the flat saved-card layout
  /// (`card_name`, `image_url`).
  ///
  /// The grouped shape is the current one: `/cards` returns "Millennia" once
  /// with the three networks it was issued on, rather than three rows that
  /// look like three different cards. The variants ride along untouched so
  /// the picker can offer them and save the chosen one's `card_id`.
  @visibleForTesting
  static Map<String, dynamic> normalizeCatalogCard(Map<String, dynamic> item) {
    final nested = (item['card'] as Map?)?.cast<String, dynamic>();
    final variants = (item['variants'] as List?)?.whereType<Map>().toList();

    // What the row should look like before the user has chosen: the variant
    // the server calls default, falling back to the first listed.
    Map<String, dynamic>? defaultVariant;
    if (variants != null && variants.isNotEmpty) {
      final defaultId = item['default_variant_id']?.toString();
      defaultVariant = variants
          .cast<Map>()
          .map((v) => v.cast<String, dynamic>())
          .firstWhere(
            (v) => v['card_id']?.toString() == defaultId,
            orElse: () => variants.first.cast<String, dynamic>(),
          );
    }

    // The grouped shape puts the product's own fields at the top level
    // (`name`), where the older shapes nested them (`card.name`) or prefixed
    // them (`card_name`).
    String? pick(String flatKey, String nestedKey) {
      final v = item[flatKey] ?? nested?[nestedKey] ?? item[nestedKey];
      return (v is String && v.isNotEmpty) ? v : null;
    }

    String? urlOf(dynamic value, String flatKey) {
      // `image` is a plain URL string in the grouped shape and an object in
      // the older ones.
      if (value is String && value.isNotEmpty) return value;
      if (value is Map) {
        final u = value['url'];
        if (u is String && u.isNotEmpty) return u;
      }
      final flat = item[flatKey];
      return (flat is String && flat.isNotEmpty) ? flat : null;
    }

    final imageObj = item['image'];
    final imageUrl = urlOf(imageObj, 'image_url');
    // Only the object form states this outright. For a bare URL it has to be
    // read off the path: the bank-wide fallbacks live under `generic/`, and
    // dressing one up as this card's own artwork is what the card plate then
    // gets wrong.
    final bool isSpecific = imageObj is Map
        ? imageObj['is_card_specific'] == true
        : (imageUrl != null &&
              !imageUrl.contains('bank-generic-cards') &&
              !imageUrl.contains('/generic/'));

    // A group has no id of its own worth saving — the variant does. The
    // default is used only so the row has a stable identity before the user
    // has answered which one they hold.
    final id =
        item['id'] ??
        item['card_id'] ??
        item['default_variant_id'] ??
        item['group_key'] ??
        '';

    return {
      'id': id,
      'group_key': item['group_key'] ?? id,
      'bank_id': item['bank_id'] ?? item['bank_name'] ?? '',
      'variants': ?variants,
      'default_variant_id': ?item['default_variant_id'],
      'card': {
        'name': pick('card_name', 'name') ?? '',
        'issuer': pick('issuer', 'issuer') ?? '',
        // The group states its networks as a list; the thumbnail wants one
        // string, and the default variant's is the one it should draw.
        'network':
            pick('network', 'network') ??
            (defaultVariant?['network'] as String?) ??
            ((item['networks'] as List?)?.whereType<String>().join(' / ') ??
                ''),
        'card_type': pick('card_type', 'card_type') ?? '',
        'variant': pick('variant', 'variant') ?? '',
      },
      if (imageUrl != null)
        'image': {'url': imageUrl, 'is_card_specific': isSpecific},
      // Sanitized for the same reason as `/banks` — this field can also carry
      // card artwork rather than the bank's mark.
      if (sanitizedBankLogo(
            item['bank_id'] as String?,
            urlOf(item['bank_logo'], 'bank_logo_url'),
          ) !=
          null)
        'bank_logo': {
          'url': sanitizedBankLogo(
            item['bank_id'] as String?,
            urlOf(item['bank_logo'], 'bank_logo_url'),
          ),
        },
      if (urlOf(item['network_logo'], 'network_logo_url') != null)
        'network_logo': {
          'url': urlOf(item['network_logo'], 'network_logo_url'),
        },
    };
  }

  // 15. Add user cards
  static Future<ApiResult<Map<String, dynamic>>> addUserCards(
    List<Map<String, dynamic>> cards,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/user/cards'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'cards': cards}),
      );
      return ApiResult.fromResponse(response, action: 'Add cards');
    } catch (e, stack) {
      LoggerService.error('Error saving user cards', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }


  // 16. Get user saved cards
  static Future<List<Map<String, dynamic>>?> getUserCards() async {
    try {
      LoggerService.info('Fetching saved user cards...');
      final response = await _client.get(
        Uri.parse('$baseUrl/user/cards'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching user cards', e, stack);
    }
    return null;
  }

  // 17. Get Dashboard
  static Future<Map<String, dynamic>?> getDashboard() async {
    try {
      LoggerService.info('Fetching dashboard details...');
      final response = await _client.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching dashboard', e, stack);
    }
    return null;
  }

  // 18. Sync contacts
  static Future<Map<String, dynamic>?> syncContacts(
    Map<String, dynamic> payload,
  ) async {
    try {
      LoggerService.info('Syncing contacts...');
      final response = await _client.post(
        Uri.parse('$baseUrl/user/contacts/sync'),
        headers: _headers(requireAuth: true),
        body: jsonEncode(payload),
      );
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body;
      }
    } catch (e, stack) {
      LoggerService.error('Error syncing contacts', e, stack);
    }
    return null;
  }

  // 19. Get contacts directory
  static Future<List<Map<String, dynamic>>?> getContactDirectory() async {
    try {
      LoggerService.info('Fetching matched contacts directory...');
      final response = await _client.get(
        Uri.parse('$baseUrl/user/contacts/directory'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching contacts directory', e, stack);
    }
    return null;
  }

  // 20. Delete user cards
  static Future<ApiResult<Map<String, dynamic>>> deleteUserCards(
    List<String> userCardIds,
  ) async {
    try {
      LoggerService.info('Deleting user cards: $userCardIds');
      final response = await _client.delete(
        Uri.parse('$baseUrl/user/cards'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'userCardIds': userCardIds}),
      );
      return ApiResult.fromResponse(response, action: 'Delete cards');
    } catch (e, stack) {
      LoggerService.error('Error deleting user cards', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 21. Follow user
  /// Sends a follow *request*.
  ///
  /// The endpoint creates a pending request rather than an immediate follow,
  /// so the resulting relationship is normally `request_sent`. The response
  /// `data` may carry a `status`, which the caller should prefer over that
  /// assumption — an account that auto-approves goes straight to
  /// `following`.
  static Future<ApiResult<Map<String, dynamic>>> followUser(
    String recipientId,
  ) async {
    try {
      LoggerService.info('Following user $recipientId...');
      final response = await _client.post(
        Uri.parse('$baseUrl/follow/requests/recipients/$recipientId'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({"message": "Hi, I would like to follow you"}),
      );
      return ApiResult.fromResponse(response, action: 'Follow user');
    } catch (e, stack) {
      LoggerService.error('Error following user', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 22. Unfollow user
  static Future<ApiResult<Map<String, dynamic>>> unfollowUser(
    String recipientId,
  ) async {
    try {
      LoggerService.info('Unfollowing user $recipientId...');
      final response = await _client.delete(
        Uri.parse('$baseUrl/follow/requests/recipients/$recipientId'),
        headers: _headers(requireAuth: true),
      );
      return ApiResult.fromResponse(response, action: 'Unfollow user');
    } catch (e, stack) {
      LoggerService.error('Error unfollowing user', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 23. Get incoming follow requests
  static Future<List<Map<String, dynamic>>?> getIncomingFollowRequests() async {
    try {
      LoggerService.info('Fetching incoming follow requests...');
      final response = await _client.get(
        Uri.parse('$baseUrl/follow/requests/incoming'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching incoming follow requests', e, stack);
    }
    return null;
  }

  // 24. Get outgoing follow requests
  static Future<List<Map<String, dynamic>>?> getOutgoingFollowRequests() async {
    try {
      LoggerService.info('Fetching outgoing follow requests...');
      final response = await _client.get(
        Uri.parse('$baseUrl/follow/requests/outgoing'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching outgoing follow requests', e, stack);
    }
    return null;
  }

  // 25. Approve follow request
  static Future<ApiResult<Map<String, dynamic>>> approveFollowRequest(
    String followId,
    List<String> allowedCardIds,
  ) async {
    try {
      LoggerService.info('Approving follow request $followId...');
      final response = await _client.post(
        Uri.parse('$baseUrl/follow/requests/$followId/approve'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({"allowed_card_ids": allowedCardIds}),
      );
      return ApiResult.fromResponse(response, action: 'Approve request');
    } catch (e, stack) {
      LoggerService.error('Error approving follow request', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 26. Reject follow request
  static Future<ApiResult<Map<String, dynamic>>> rejectFollowRequest(
    String followId,
  ) async {
    try {
      LoggerService.info('Rejecting follow request $followId...');
      final response = await _client.post(
        Uri.parse('$baseUrl/follow/requests/$followId/reject'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({}),
      );
      return ApiResult.fromResponse(response, action: 'Reject request');
    } catch (e, stack) {
      LoggerService.error('Error rejecting follow request', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Asks whether this user should be prompted for feedback in [context]
  /// (`GET /feedback/{context}/prompt`).
  ///
  /// The server owns "once per user per context", so the app never has to
  /// track whether it has asked before — it just asks at the triggering
  /// moment and shows nothing when told not to.
  /// [hackId] scopes the question to one benefit: feedback is tracked per
  /// user *and* hack, so answering for one benefit must not silence the
  /// prompt on every other.
  ///
  /// Prefer the `feedback_prompt` embedded on a [Hack] by the list
  /// endpoints — this is the fallback for benefits reached without a list
  /// fetch, such as a deep link.
  static Future<FeedbackPrompt> getFeedbackPrompt(
    String context, {
    String? hackId,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/feedback/$context/prompt').replace(
          queryParameters: {
            if (hackId != null && hackId.isNotEmpty) 'hack_id': hackId,
          },
        ),
        headers: _headers(requireAuth: true),
      );
      final result = ApiResult.fromResponse(
        response,
        action: 'Feedback prompt',
      );
      if (!result.ok) return FeedbackPrompt.none;
      return FeedbackPrompt.parse(result.data);
    } catch (e, stack) {
      // Feedback is never worth interrupting the screen for: on any failure
      // the prompt simply does not appear.
      LoggerService.error('Error fetching feedback prompt', e, stack);
      return FeedbackPrompt.none;
    }
  }

  /// Submits answers for [context] (`POST /feedback/{context}/responses`).
  ///
  /// [answers] maps question id to the answer string the API expects:
  /// `"yes"`/`"no"` for a yes/no question, `"1"`..`"5"` for a rating.
  ///
  /// Send every question at once. A question can only be answered once —
  /// a second attempt is rejected — so a partial submission permanently
  /// loses the chance to answer the rest.
  static Future<ApiResult<Map<String, dynamic>>> submitFeedback({
    required String context,
    required Map<String, String> answers,
    String? hackId,
  }) async {
    try {
      LoggerService.info('Submitting ${answers.length} feedback answers.');
      final response = await _client.post(
        Uri.parse('$baseUrl/feedback/$context/responses'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          if (hackId != null && hackId.isNotEmpty) 'hack_id': hackId,
          'answers': [
            for (final e in answers.entries)
              {'question_id': e.key, 'answer': e.value},
          ],
        }),
      );
      return ApiResult.fromResponse(response, action: 'Submit feedback');
    } catch (e, stack) {
      LoggerService.error('Error submitting feedback', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Submits or updates this user's 1-5 rating for a benefit
  /// (`POST /hacks/{hackId}/rate`).
  ///
  /// The response carries both refreshed aggregates plus the user's own
  /// score, so the caller can update the row without re-fetching the list.
  static Future<ApiResult<Map<String, dynamic>>> rateHack(
    String hackId,
    int rating,
  ) async {
    try {
      LoggerService.info('Rating hack $hackId: $rating');
      final response = await _client.post(
        Uri.parse('$baseUrl/hacks/$hackId/rate'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'rating': rating}),
      );
      return ApiResult.fromResponse(response, action: 'Rate benefit');
    } catch (e, stack) {
      LoggerService.error('Error rating hack $hackId', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Creates a shareable, one-time invite link (`POST /invites`).
  ///
  /// Unlike the per-contact invite this addresses nobody: the response's
  /// `whatsapp_url` has no recipient number, so the user picks who to send
  /// it to. That is the point — it is the route in for someone whose
  /// contacts are not synced, or who has nobody matched to invite.
  ///
  /// The link carries the creator's identity, so redeeming it opens a
  /// follow request back to them. It expires in 24 hours and is consumed on
  /// first redemption, so a fresh one is created per share rather than
  /// cached.
  static Future<ApiResult<Map<String, dynamic>>> createInviteLink() async {
    try {
      LoggerService.info('Creating invite link...');
      final response = await _client.post(
        Uri.parse('$baseUrl/invites'),
        headers: _headers(requireAuth: true),
      );
      return ApiResult.fromResponse(response, action: 'Create invite link');
    } catch (e, stack) {
      LoggerService.error('Error creating invite link', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Invites an address-book contact who is not on CardCircle yet
  /// (`POST /user/contacts/{contactId}/invite`).
  ///
  /// The server does not send anything: it returns a `wa.me` deep link with
  /// a prefilled message for the user to send themselves. It also enforces
  /// a 24-hour cooldown per contact (429) and refuses contacts who already
  /// have an account (400), so the caller should show the server's message
  /// rather than assume success.
  static Future<ApiResult<Map<String, dynamic>>> inviteContact(
    String contactId,
  ) async {
    try {
      LoggerService.info('Inviting contact $contactId...');
      final response = await _client.post(
        Uri.parse('$baseUrl/user/contacts/$contactId/invite'),
        headers: _headers(requireAuth: true),
      );
      return ApiResult.fromResponse(response, action: 'Invite contact');
    } catch (e, stack) {
      LoggerService.error('Error inviting contact $contactId', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// The cards a person you follow has shared with you
  /// (`GET /follow/following/{followId}/cards`).
  static Future<List<Map<String, dynamic>>?> getSharedCards(
    String followId,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/follow/following/$followId/cards'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final raw = body['data'];
        return raw is List
            ? raw.whereType<Map<String, dynamic>>().toList()
            : [];
      }
      LoggerService.warning(
        'Shared cards failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching shared cards', e, stack);
    }
    return null;
  }

  /// Which of *your* cards a follower may see
  /// (`GET /follow/permissions/{followId}`).
  ///
  /// Returns the allowed card ids; the response nests them under
  /// `data.permissions` with an `is_allowed` flag per row.
  static Future<List<String>?> getFollowPermissions(String followId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/follow/permissions/$followId'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final perms = (body['data'] as Map?)?['permissions'];
        if (perms is! List) return const [];
        return perms
            .whereType<Map<String, dynamic>>()
            .where((p) => p['is_allowed'] == true)
            .map((p) => p['card_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
      LoggerService.warning(
        'Get permissions failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching follow permissions', e, stack);
    }
    return null;
  }

  /// Replaces which cards a follower may see
  /// (`PUT /follow/permissions/{followId}`).
  static Future<ApiResult<Map<String, dynamic>>> updateFollowPermissions(
    String followId,
    List<String> allowedCardIds,
  ) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/follow/permissions/$followId'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({'allowed_card_ids': allowedCardIds}),
      );
      return ApiResult.fromResponse(response, action: 'Update permissions');
    } catch (e, stack) {
      LoggerService.error('Error updating follow permissions', e, stack);
      return const ApiResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // 27. Get followers list
  static Future<List<Map<String, dynamic>>?> getFollowers() async {
    try {
      LoggerService.info('Fetching followers list...');
      final response = await _client.get(
        Uri.parse('$baseUrl/follow/followers'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching followers list', e, stack);
    }
    return null;
  }

  // 28. Get following list
  static Future<List<Map<String, dynamic>>?> getFollowing() async {
    try {
      LoggerService.info('Fetching following list...');
      final response = await _client.get(
        Uri.parse('$baseUrl/follow/following'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e, stack) {
      LoggerService.error('Error fetching following list', e, stack);
    }
    return null;
  }

  // 29. Get My Hacks
  /// One page of the user's benefits.
  ///
  /// `page` is 1-based and `limit` defaults to the backend's own page size,
  /// so the two stay in step without the client restating it.
  static Future<PagedResult<Map<String, dynamic>>?> getMyHacks({
    int page = 1,
    int limit = defaultPageSize,
  }) => _fetchHackPage('getmyhacks', page: page, limit: limit);

  /// Free-text search across the benefit catalog
  /// (`GET /hacks/search?q=`).
  ///
  /// The matching is fuzzy server-side, so typos still find the benefit.
  /// Same page envelope as the other lists, so the infinite scroll works
  /// unchanged.
  static Future<PagedResult<Map<String, dynamic>>?> searchHacks(
    String query, {
    int page = 1,
    int limit = defaultPageSize,
  }) => _fetchHackPage(
    'search',
    page: page,
    limit: limit,
    extraQuery: {'q': query},
  );

  /// Benefits in one category (`GET /hacks/search/category?category=`).
  ///
  /// Exact and case-insensitive, unlike [searchHacks] — a category pill is
  /// a precise choice, so fuzzy matching there would surface benefits the
  /// reader did not ask for.
  static Future<PagedResult<Map<String, dynamic>>?> searchHacksByCategory(
    String category, {
    int page = 1,
    int limit = defaultPageSize,
  }) => _fetchHackPage(
    'search/category',
    page: page,
    limit: limit,
    extraQuery: {'category': category},
  );

  /// One page of benefits shared by people you follow.
  static Future<PagedResult<Map<String, dynamic>>?> getCircleHacks({
    int page = 1,
    int limit = defaultPageSize,
  }) => _fetchHackPage('getcirclehacks', page: page, limit: limit);

  /// The backend's page size. Matches its own default so the first request
  /// asks for exactly what it would have returned anyway.
  static const int defaultPageSize = 7;

  static Future<PagedResult<Map<String, dynamic>>?> _fetchHackPage(
    String path, {
    required int page,
    required int limit,
    Map<String, String> extraQuery = const {},
  }) async {
    try {
      LoggerService.info('Fetching $path page $page...');
      final query = <String, String>{
        'page': '$page',
        'limit': '$limit',
        ...extraQuery,
      };
      final response = await _client.get(
        Uri.parse('$baseUrl/hacks/$path').replace(queryParameters: query),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          body is Map<String, dynamic> &&
          body['success'] == true) {
        return PagedResult.fromEnvelope(
          body,
          itemsKey: 'hacks',
          requestedPage: page,
          requestedLimit: limit,
        );
      }
      LoggerService.warning(
        '$path failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching $path page $page', e, stack);
    }
    return null;
  }

  // 32. Register Push Token
  static Future<bool> registerPushToken({
    required String token,
    String deviceType = 'ANDROID',
    String deviceName = 'Test Device',
  }) async {
    try {
      LoggerService.info('Registering push token...');
      final response = await _client.post(
        Uri.parse('$baseUrl/push/tokens/register'),
        headers: _headers(requireAuth: true),
        body: jsonEncode({
          'token': token,
          'device_type': deviceType,
          'device_name': deviceName,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        LoggerService.info('Push token registered successfully.');
        return true;
      }
      LoggerService.warning(
        'Push token registration failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error registering push token', e, stack);
    }
    return false;
  }

  // 33. Get Push Notifications
  /// Marks one notification read (`POST /push/notifications/{id}/read`).
  ///
  /// Fire-and-forget: the row is already dimmed locally by the time this
  /// returns, and a failure here is not worth interrupting the reader over.
  static Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/push/notifications/$notificationId/read'),
        headers: _headers(requireAuth: true),
      );
    } catch (e, stack) {
      LoggerService.error('Error marking notification read', e, stack);
    }
  }

  static Future<List<Map<String, dynamic>>?> getNotifications() async {
    try {
      LoggerService.info('Fetching push notifications...');
      final response = await _client.get(
        Uri.parse('$baseUrl/push/notifications'),
        headers: _headers(requireAuth: true),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] ?? body['notifications'] ?? [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
      LoggerService.warning(
        'getNotifications failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching push notifications', e, stack);
    }
    return null;
  }

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    await LocalStorageService.remove('@auth/accessToken');
    await LocalStorageService.remove('@auth/refreshToken');
  }
}
