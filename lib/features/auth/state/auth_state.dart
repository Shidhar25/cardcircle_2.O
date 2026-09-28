import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/api_result.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/logo_assets.dart';
import '../../../shared/models/models.dart';

class AuthState extends ChangeNotifier {
  bool _hasOnboarded = false;
  ProfileData? _profile;
  late User _user;

  AuthState() {
    _initUser();
    _loadPersisted();
    // FCM can rotate a device's token at any time (reinstall, app data
    // clear, Google Play Services refresh) — not just at login. Without
    // this, a rotated token is never told to the backend, the old one
    // keeps getting sent to, and it eventually dies as "not-registered"
    // with nothing replacing it: pushes just stop arriving until the next
    // fresh login. Only forwarded while a profile is actually loaded, since
    // there is no access token to attach it to before that.
    //
    // Guarded: `FirebaseMessaging.instance` throws synchronously when no
    // Firebase app has been initialised, which is the case in every widget
    // test that builds an `AuthState` without also calling
    // `Firebase.initializeApp()` — this must not take the whole screen down
    // with it.
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        if (_profile == null) return;
        await ApiService.registerPushToken(
          token: token,
          deviceType: DeviceService.platformLabel,
          deviceName: await DeviceService.deviceName(),
        );
      });
    } catch (e, s) {
      LoggerService.error('Failed to listen for FCM token refresh', e, s);
    }
  }

  bool get hasOnboarded => _hasOnboarded;
  bool get hasProfile => _profile != null;
  ProfileData? get profile => _profile;
  User get user => _user;

  /// Blank slate for a signed-out (or not-yet-loaded) session.
  ///
  /// This must NOT seed demo cards or demo stats. It runs on construction and
  /// again on logout, so anything invented here leaks across account
  /// switches: log out of one account and into another and you'd briefly —
  /// or permanently, if the cards fetch failed — see fabricated cards with
  /// fabricated colours, plus the previous user's name and stats.
  /// Real values arrive from fetchUserCards() and refreshProfileFromServer().
  void _initUser() {
    _user = User(
      name: '',
      username: '@',
      initials: '',
      level: 'New Member',
      levelIndex: 0,
      points: 0,
      pointsToNextLevel: 5000,
      streak: 0,
      cards: const [],
      friendsCount: 0,
      hacksShared: 0,
      followersCount: 0,
      followingCount: 0,
    );
  }

  void _loadPersisted() {
    _hasOnboarded = LocalStorageService.getBool('@cardcircle/onboarded');
    final profileStr = LocalStorageService.getString('@cardcircle/profile');
    if (profileStr != null) {
      try {
        final parsed = ProfileData.fromJson(jsonDecode(profileStr));
        _profile = parsed;
        _user = _user.copyWith(
          name: parsed.name,
          username: '@${parsed.username}',
          initials: parsed.initials,
        );
        fetchUserCards();
        refreshProfileFromServer();
        registerPushToken();
      } catch (e, s) {
        LoggerService.error('Failed to parse persistent profile', e, s);
      }
    }
    notifyListeners();
  }

  Future<void> markOnboarded() async {
    LoggerService.info('Marking user as onboarded.');
    await LocalStorageService.setBool('@cardcircle/onboarded', true);
    _hasOnboarded = true;
    notifyListeners();
  }

  Future<void> saveProfile(ProfileData data) async {
    LoggerService.info('Saving user profile: ${data.username}');
    await LocalStorageService.setString(
      '@cardcircle/profile',
      jsonEncode(data.toJson()),
    );
    _profile = data;
    _user = _user.copyWith(
      name: data.name,
      username: '@${data.username}',
      initials: data.initials,
    );
    notifyListeners();
    fetchUserCards();
    refreshProfileFromServer();
    // The one place every login and signup passes through — this is what
    // actually links a device's push token to this phone number's account.
    // Requesting permission and a token any earlier (e.g. at app launch)
    // had nowhere valid to send it: registration requires an access token,
    // which does not exist before this point.
    registerPushToken();
  }

  Future<void> refreshProfileFromServer() async {
    try {
      LoggerService.info('Refreshing profile from server...');
      final data = await ApiService.getUserProfile();
      if (data != null) {
        _user = _user.copyWith(
          name: data['name'] ?? _user.name,
          username:
              '@${data['username'] ?? _user.username.replaceAll('@', '')}',
          followersCount: data['followers_count'] ?? _user.followersCount,
          followingCount: data['following_count'] ?? _user.followingCount,
        );
        notifyListeners();
      }
    } catch (e, s) {
      LoggerService.error('Error refreshing profile from server', e, s);
    }
  }

  void addPoints(int amount) {
    LoggerService.info('Adding points to user: $amount');
    _user.points += amount;
    notifyListeners();
  }

  Future<void> logout() async {
    LoggerService.info('Logging out AuthState...');
    _profile = null;
    await LocalStorageService.remove('@cardcircle/profile');
    _initUser();
    notifyListeners();
  }

  /// `bank-of-baroda` -> `Bank Of Baroda`. The saved-card response only
  /// gives the bank slug (`bank_id`/`bank_name`), not a display name.
  static String _titleCaseSlug(String slug) => slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// The first usable URL in [candidates].
  static String? _firstUrl(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }

  /// The saved-card id for one `GET /user/cards` row, with a loud warning
  /// when the row has none.
  ///
  /// Resolving the id lives on [CreditCard]; what belongs here is noticing
  /// that it failed. Silence is how the old fallback turned a missing field
  /// into a 500 from the database instead of a message anyone could act on.
  static String _savedCardId(Map<String, dynamic> item) {
    final id = CreditCard.savedIdFrom(item);
    if (id.isEmpty) {
      LoggerService.warning(
        'Saved card "${item['card_name'] ?? '?'}" has no user_card_id — '
        'it cannot be deleted or shared. Row keys: ${item.keys.toList()}',
      );
    }
    return id;
  }

  Future<void> fetchUserCards() async {
    final responseList = await ApiService.getUserCards();
    if (responseList != null) {
      final List<CreditCard> fetchedCards = [];
      for (final item in responseList) {
        final userCardId = _savedCardId(item);
        final cardId = (item['card_id'] ?? '') as String;
        final bankSlug = (item['bank_id'] ?? item['bank_name'] ?? '') as String;
        final bankDisplayName = _titleCaseSlug(bankSlug);
        final cardName = (item['card_name'] ?? '') as String;
        final issuer = item['issuer'] as String?;
        final network = item['network'] as String?;

        // `image` is the object form (`{url, is_card_specific}`) and
        // `image_url` the flat one. Both ship today; the object is
        // preferred because it states card-specificity outright instead of
        // leaving it to be guessed from the path.
        final image = (item['image'] as Map?)?.cast<String, dynamic>();
        final String? finalImageUrl = _firstUrl([
          image?['url'],
          item['image_url'],
        ]);
        final bool isCardSpecific = image?['is_card_specific'] is bool
            ? image!['is_card_specific'] as bool
            : (finalImageUrl != null && !finalImageUrl.contains('/generic/'));

        final brand = bankBrandFor(bankSlug);

        // The server's own URL comes first now, for both marks. `/banks`
        // serves real logos (mostly `/bank/logo/*.svg`) or an explicit null,
        // and `/user/cards` carries `network_logo.url` per card — so there
        // is nothing left for the app to guess at.
        final String? bankLogoUrl =
            await ApiService.bankLogoFor(bankSlug) ?? LogoAssets.bank(bankSlug);

        final networkLogo = (item['network_logo'] as Map?)
            ?.cast<String, dynamic>();
        // 1. What the server sent for this specific card. 2. Failing that,
        // whatever `/card-networks` states for the network generally.
        // Nothing here is bundled with the app or guessed from a naming
        // convention — only what the API itself has said.
        final String? networkLogoUrl =
            _firstUrl([networkLogo?['url']]) ??
            await ApiService.networkLogoFor(network);

        fetchedCards.add(
          CreditCard(
            id: userCardId,
            catalogCardId: cardId,
            name: cardName,
            bank: brand.name.isNotEmpty ? brand.name : bankDisplayName,
            bankId: bankSlug,
            network: network ?? '',
            lastFour: cardId.length > 4
                ? cardId.substring(cardId.length - 4)
                : 'XXXX',
            gradientColors: brand.gradient,
            type: (item['card_type'] as String? ?? 'General').toLowerCase(),
            category: (item['card_type'] as String?) ?? 'General',
            imageUrl: finalImageUrl,
            isCardSpecific: isCardSpecific,
            bankLogoUrl: bankLogoUrl,
            networkLogoUrl: networkLogoUrl,
            issuer: (issuer != null && issuer.isNotEmpty) ? issuer : null,
          ),
        );
      }

      _user = _user.copyWith(cards: fetchedCards);
      notifyListeners();
    }
  }

  Future<ApiResult<Map<String, dynamic>>> deleteCard(String userCardId) async {
    if (userCardId.trim().isEmpty) {
      // The row arrived without a saved-card id. Sending an empty or catalog
      // id deletes nothing and returns a 500 from the uuid cast.
      LoggerService.warning('Delete skipped: card has no saved-card id.');
      return const ApiResult.failure(
        'This card is missing its id — pull to refresh your cards and try '
        'again.',
      );
    }
    final result = await ApiService.deleteUserCards([userCardId]);
    if (result.ok) {
      _user.cards.removeWhere((c) => c.id == userCardId);
      notifyListeners();
    }
    return result;
  }

  /// Registers this device for push.
  ///
  /// The token is requested from Firebase rather than hardcoded — a fixed
  /// token means every install registers as the same device, so notifications
  /// go to whoever registered it first and nobody else is reachable.
  Future<void> registerPushToken() async {
    final token = await NotificationService.registerForPush();
    if (token == null || token.isEmpty) {
      LoggerService.info('Push not registered: permission denied or no token.');
      return;
    }
    await ApiService.registerPushToken(
      token: token,
      deviceType: DeviceService.platformLabel,
      deviceName: await DeviceService.deviceName(),
    );
  }
}
