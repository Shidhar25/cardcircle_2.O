import 'dart:convert';
import 'package:flutter/material.dart' hide Badge;
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
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

  void _initUser() {
    final myCards = [
      CreditCard(
        id: 'c1',
        name: 'Regalia Gold',
        bank: 'HDFC Bank',
        lastFour: '4821',
        gradientColors: [const Color(0xFF7B5B00), const Color(0xFFC89B00)],
        type: 'premium',
        category: 'Premium',
      ),
      CreditCard(
        id: 'c2',
        name: 'Cashback Card',
        bank: 'SBI',
        lastFour: '3310',
        gradientColors: [const Color(0xFF0F3460), const Color(0xFF1A1A2E)],
        type: 'cashback',
        category: 'Cashback',
      ),
      CreditCard(
        id: 'c3',
        name: 'Amazon Pay',
        bank: 'ICICI Bank',
        lastFour: '7645',
        gradientColors: [const Color(0xFF134E5E), const Color(0xFF71B280)],
        type: 'shopping',
        category: 'Shopping',
      ),
      CreditCard(
        id: 'c4',
        name: 'Ace Card',
        bank: 'Axis Bank',
        lastFour: '9023',
        gradientColors: [const Color(0xFF1A1A2E), const Color(0xFF533483)],
        type: 'cashback',
        category: 'Cashback',
      ),
      CreditCard(
        id: 'c5',
        name: 'Millennia',
        bank: 'HDFC Bank',
        lastFour: '5512',
        gradientColors: [const Color(0xFF23074D), const Color(0xFF8B2FC9)],
        type: 'shopping',
        category: 'Shopping',
      ),
    ];

    final badges = [
      Badge(
        id: 'b1',
        name: 'Cashback King',
        iconName: 'star',
        description: 'Earned ₹10,000+ in cashback',
        earned: true,
        rarity: 'epic',
        color: const Color(0xFFFFD700),
      ),
      Badge(
        id: 'b2',
        name: 'Travel Pro',
        iconName: 'airplane',
        description: 'Used airport lounge 10 times',
        earned: true,
        rarity: 'rare',
        color: const Color(0xFF00D4FF),
      ),
      Badge(
        id: 'b3',
        name: 'Card Collector',
        iconName: 'card',
        description: 'Own 5+ credit cards',
        earned: true,
        rarity: 'common',
        color: const Color(0xFF8B5CF6),
      ),
      Badge(
        id: 'b4',
        name: 'Hack Master',
        iconName: 'flash',
        description: 'Share 20 verified hacks',
        earned: false,
        rarity: 'legendary',
        color: const Color(0xFFFF6B35),
      ),
      Badge(
        id: 'b5',
        name: 'Elite Member',
        iconName: 'diamond',
        description: 'Top 1% saver on platform',
        earned: false,
        rarity: 'legendary',
        color: const Color(0xFF00FF88),
      ),
      Badge(
        id: 'b6',
        name: 'Streak Legend',
        iconName: 'flame',
        description: 'Maintain 100-day streak',
        earned: false,
        rarity: 'epic',
        color: const Color(0xFFFF4757),
      ),
    ];

    _user = User(
      name: 'Shridhar Hande',
      username: '@shridhar',
      initials: 'SS',
      level: 'Cashback Hunter',
      levelIndex: 1,
      points: 2840,
      pointsToNextLevel: 5000,
      savings: 18750,
      streak: 12,
      cards: myCards,
      badges: badges,
      friendsCount: 24,
      hacksShared: 8,
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
    await LocalStorageService.setString('@cardcircle/profile', jsonEncode(data.toJson()));
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
          username: '@${data['username'] ?? _user.username.replaceAll('@', '')}',
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

  Future<void> fetchUserCards() async {
    final responseList = await ApiService.getUserCards();
    if (responseList != null) {
      final List<CreditCard> fetchedCards = [];
      for (final item in responseList) {
        final cardData = item['card'] ?? item;
        final userCardId = item['user_card_id'] ?? '';
        final cardId = item['card_id'] ?? cardData['id'] ?? '';
        final bankName = item['bank_name'] ?? cardData['bank'] ?? '';
        final cardName = item['card_name'] ?? cardData['card_name'] ?? '';
        final nickname = item['nickname'] ?? '';
        final category = cardData['category'] ?? 'General';
        
        List<Color> gradients = [const Color(0xFF1F1C2C), const Color(0xFF928DAB)];
        final bankLower = bankName.toLowerCase();
        if (bankLower.contains('hdfc')) {
          gradients = [const Color(0xFF7B5B00), const Color(0xFFC89B00)];
        } else if (bankLower.contains('amex') || bankLower.contains('american express')) {
          gradients = [const Color(0xFF1E3C72), const Color(0xFF2A5298)];
        } else if (bankLower.contains('sbi')) {
          gradients = [const Color(0xFF0F3460), const Color(0xFF1A1A2E)];
        } else if (bankLower.contains('icici')) {
          gradients = [const Color(0xFFE65C00), const Color(0xFFF9D423)];
        } else if (bankLower.contains('axis')) {
          gradients = [const Color(0xFF800080), const Color(0xFFFF00FF)];
        } else if (bankLower.contains('yes')) {
          gradients = [const Color(0xFF0052D4), const Color(0xFF9FFB00)];
        }
        
        fetchedCards.add(CreditCard(
          id: userCardId.isNotEmpty ? userCardId : cardId,
          name: cardName,
          bank: bankName,
          lastFour: nickname.isNotEmpty ? nickname : (cardId.length > 4 ? cardId.substring(cardId.length - 4) : 'XXXX'),
          gradientColors: gradients,
          type: category.toLowerCase(),
          category: category,
        ));
      }
      
      _user = _user.copyWith(cards: fetchedCards);
      notifyListeners();
    }
  }

  Future<bool> deleteCard(String userCardId) async {
    final success = await ApiService.deleteUserCards([userCardId]);
    if (success) {
      _user.cards.removeWhere((c) => c.id == userCardId);
      notifyListeners();
    }
    return success;
  }
}
