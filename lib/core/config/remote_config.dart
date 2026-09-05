import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';

/// Server-driven app configuration.
///
/// The point of this layer is that copy changes, feature toggles and rollout
/// decisions ship from `GET /bootstrap/config` rather than from a new APK.
/// Every value has a compiled-in default, so a cold first launch with no
/// network still renders a complete, correct app — the server only ever
/// *overrides*.
///
/// Read order on startup, cheapest first:
///   1. [defaults]           — always present, never fails
///   2. the last cached payload — survives offline launches
///   3. the live fetch        — refreshes the cache for next time
///
/// Screens read through the typed accessors ([flag], [text], [number],
/// [strings]) so a malformed or unexpected server value degrades to the
/// default instead of throwing mid-build.
class RemoteConfig extends ChangeNotifier {
  RemoteConfig._();

  static final RemoteConfig instance = RemoteConfig._();

  static const String _cacheKey = '@config/values';

  /// Compiled-in fallbacks. Any key the server omits resolves to these.
  ///
  /// Keys are namespaced by screen so the server payload reads as a map of
  /// the app's surfaces rather than a flat bag of booleans.
  static const Map<String, dynamic> defaults = {
    // Kill switches handled during the splash hand-off. These names match
    // what `GET /bootstrap/config` already returns.
    'maintenanceMode': false,
    'maintenanceMessage':
        'We are currently under maintenance. Please try again later.',
    'forceUpdate': false,

    // Server-owned auth parameters. The OTP length and expiry are decided
    // by the backend that issues the code, so the screen reads them rather
    // than hardcoding a 6/60 that could silently drift out of agreement.
    'defaultSettings.otpLength': 6,
    'defaultSettings.otpExpirySeconds': 60,

    // Legal links, already in the payload under `legal`.
    'legal.termsUrl': 'https://cardcircle.com/terms',
    'legal.privacyUrl': 'https://cardcircle.com/privacy',

    // App-owned copy and toggles. These are not in the payload yet; adding
    // them server-side is what makes them changeable without a release.
    'auth.loginSubtitle': 'Log in with your number. Your circle stays private.',
    'auth.otpHelperText':
        'We only use this code to confirm the number is yours.',
    'auth.termsRequired': true,
    'auth.termsText': 'I agree to the Terms of Service and Privacy Policy.',
    'auth.legalFooter':
        'By continuing you agree to our Terms of Service and Privacy Policy.',

    // Benefits.
    'discover.title': 'Benefits',
    'discover.searchHint': 'Search benefits, cards, brands',
    'discover.tabLabels': ['MY BENEFITS', 'CIRCLE BENEFITS'],
    // Category pills are not configured here: they come from
    // `GET /category/list`, so the backend already owns that vocabulary.

    // Cards.
    'cards.showNameOnArt': true,
  };

  /// Every key the app reads, for the debug inspector.
  static List<String> get knownKeys => defaults.keys.toList()..sort();

  /// The currently applied overrides, for the debug inspector.
  Map<String, dynamic> get activeOverrides => Map.unmodifiable(_overrides);

  Map<String, dynamic> _overrides = const {};

  /// Whether a live payload has been applied this session. False means the
  /// app is running on defaults plus whatever was cached.
  bool get isFresh => _isFresh;
  bool _isFresh = false;

  /// Restores the last cached payload. Cheap and synchronous-ish — call it
  /// during app bootstrap, before the first frame.
  void restoreCached() {
    final raw = LocalStorageService.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _overrides = decoded;
        LoggerService.info('Restored ${decoded.length} cached config values.');
      }
    } catch (e, stack) {
      // A corrupt cache must never block startup; drop it and move on.
      LoggerService.error('Discarding corrupt config cache', e, stack);
      LocalStorageService.remove(_cacheKey);
    }
  }

  /// Fetches the live payload and caches it. Returns false when the network
  /// call fails, in which case the previously resolved values still stand.
  Future<bool> refresh() async {
    final payload = await ApiService.getBootstrapConfig();
    if (payload == null) return false;
    await apply(payload);
    return true;
  }

  /// Applies a payload and persists it for the next cold start.
  Future<void> apply(Map<String, dynamic> payload) async {
    _overrides = _flatten(payload);
    _isFresh = true;
    await LocalStorageService.setString(_cacheKey, jsonEncode(_overrides));
    LoggerService.info('Applied ${_overrides.length} remote config values.');
    notifyListeners();
  }

  /// Applies a payload without touching disk.
  ///
  /// Persistence is the only part of [apply] that needs a platform channel,
  /// so tests exercise resolution through this instead of standing up
  /// SharedPreferences.
  @visibleForTesting
  void applyForTest(Map<String, dynamic> payload) {
    _overrides = _flatten(payload);
  }

  /// Flattens a nested payload into dotted keys, so the server may send
  /// either `{"auth": {"socialLoginEnabled": true}}` or the already-flat
  /// `{"auth.termsRequired": true}` and both resolve identically.
  static Map<String, dynamic> _flatten(
    Map<String, dynamic> source, [
    String prefix = '',
  ]) {
    final out = <String, dynamic>{};
    source.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        out.addAll(_flatten(value, path));
      } else {
        out[path] = value;
      }
    });
    return out;
  }

  dynamic _raw(String key) =>
      _overrides.containsKey(key) ? _overrides[key] : defaults[key];

  /// Reads a boolean toggle. Accepts a real bool or the strings
  /// `"true"`/`"false"`, since JSON configs are often hand-edited.
  bool flag(String key, {bool fallback = false}) {
    final value = _raw(key);
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// Reads a string of copy. Blank values fall through to the default so an
  /// accidentally empty field never blanks out a headline.
  String text(String key, {String fallback = ''}) {
    final value = _raw(key);
    if (value is String && value.trim().isNotEmpty) return value;
    final def = defaults[key];
    if (def is String && def.isNotEmpty) return def;
    return fallback;
  }

  /// Reads a numeric value, tolerating a numeric string.
  num number(String key, {num fallback = 0}) {
    final value = _raw(key);
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Reads a list of strings, dropping any non-string entries. An empty or
  /// wrong-typed list falls back to the default, because callers index into
  /// these (tab labels, category pills) and an empty list would break layout.
  List<String> strings(String key, {List<String> fallback = const []}) {
    List<String>? coerce(dynamic value) {
      if (value is! List) return null;
      final items = value.whereType<String>().toList();
      return items.isEmpty ? null : items;
    }

    return coerce(_raw(key)) ?? coerce(defaults[key]) ?? fallback;
  }
}

/// Shorthand for `RemoteConfig.instance`, so screens read
/// `config.flag('auth.termsRequired')`.
RemoteConfig get config => RemoteConfig.instance;
