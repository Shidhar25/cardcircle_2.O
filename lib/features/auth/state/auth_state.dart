import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/api_result.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/card_network.dart';
import '../../../shared/models/models.dart';

class AuthState extends ChangeNotifier {
  bool _hasOnboarded = false;
  ProfileData? _profile;
  late User _user;

  AuthState() {
    _initUser();
    _loadPersisted();
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

  Future<void> fetchUserCards() async {
    final responseList = await ApiService.getUserCards();
    if (responseList != null) {
      final List<CreditCard> fetchedCards = [];
      for (final item in responseList) {
        final userCardId = (item['user_card_id'] ?? '') as String;
        final cardId = (item['card_id'] ?? '') as String;
        final bankSlug = (item['bank_id'] ?? item['bank_name'] ?? '') as String;
        final bankDisplayName = _titleCaseSlug(bankSlug);
        final cardName = (item['card_name'] ?? '') as String;
        final issuer = item['issuer'] as String?;
        final network = item['network'] as String?;
        final imageUrl = item['image_url'] as String?;

        // The saved-card endpoint has no `is_card_specific` flag, unlike
        // the catalog, so it is inferred from the path. Generic artwork
        // lives under `/generic/` — both `bank-generic-cards/` and
        // `bank-card-bg/`; card-specific art lives under
        // `/credit-card-images/`. Testing only for `bank-generic-cards`
        // mislabelled every `bank-card-bg` card as specific.
        final bool isCardSpecific =
            imageUrl != null && !imageUrl.contains('/generic/');

        // Bank identity comes from the curated brand registry, not the
        // network: bundled assets can't 404, can't be swapped for card
        // artwork by an upstream change, and render instantly.
        final brand = bankBrandFor(bankSlug);

        // Real bank mark for the plate. Sanitized upstream so card artwork
        // can't arrive here; resolves for banks that have an asset and
        // silently hides for the ones that don't.
        final String? bankLogoUrl = await ApiService.bankLogoFor(bankSlug);

        // Logo URL comes from the shared network registry, which only
        // names slugs that actually exist on S3 — RuPay has no artwork, so
        // it deliberately yields no URL and is identified by its label on
        // the plate instead.
        final String? networkLogoUrl = CardNetwork.parse(network)?.logoUrl;

        fetchedCards.add(
          CreditCard(
            id: userCardId.isNotEmpty ? userCardId : cardId,
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
            imageUrl: (imageUrl != null && imageUrl.isNotEmpty)
                ? imageUrl
                : null,
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
    final token = await NotificationService.requestPermissionAndGetToken();
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
