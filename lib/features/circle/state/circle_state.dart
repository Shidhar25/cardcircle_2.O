import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/models.dart';

class CircleState extends ChangeNotifier {
  late List<Friend> _friends;

  CircleState() {
    _initData();
  }

  List<Friend> get friends => _friends;

  void _initData() {
    _friends = [
      Friend(
        id: 'f1',
        name: 'Rahul Mehta',
        username: '@rahulmehta',
        initials: 'RM',
        cardsCount: 6,
        savings: '₹32,400',
        level: 'Hack Master',
        isFollowing: true,
        commonCards: ['SBI Cashback', 'HDFC Regalia'],
        gradientColors: [const Color(0xFF134E5E), const Color(0xFF71B280)],
      ),
      Friend(
        id: 'f2',
        name: 'Priya Singh',
        username: '@priyasingh',
        initials: 'PS',
        cardsCount: 4,
        savings: '₹21,800',
        level: 'Rewards Expert',
        isFollowing: true,
        commonCards: ['HDFC Regalia Gold'],
        gradientColors: [const Color(0xFF23074D), const Color(0xFF8B2FC9)],
      ),
      Friend(
        id: 'f3',
        name: 'Amit Patel',
        username: '@amitpatel',
        initials: 'AP',
        cardsCount: 8,
        savings: '₹54,200',
        level: 'Legend',
        isFollowing: false,
        commonCards: ['HDFC Regalia Gold', 'Axis Ace'],
        gradientColors: [const Color(0xFF0F3460), const Color(0xFF533483)],
      ),
      Friend(
        id: 'f4',
        name: 'Deepika Rao',
        username: '@deepikarao',
        initials: 'DR',
        cardsCount: 3,
        savings: '₹12,600',
        level: 'Saver',
        isFollowing: true,
        commonCards: ['Axis Ace'],
        gradientColors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
      ),
      Friend(
        id: 'f5',
        name: 'Karan Joshi',
        username: '@karanjoshi',
        initials: 'KJ',
        cardsCount: 5,
        savings: '₹28,900',
        level: 'Expert',
        isFollowing: false,
        commonCards: ['ICICI Amazon Pay', 'SBI Cashback'],
        gradientColors: [const Color(0xFF7B5B00), const Color(0xFFC89B00)],
      ),
    ];
  }

  void toggleFollow(String id) {
    LoggerService.debug('Toggling follow for friend ID: $id');
    for (var f in _friends) {
      if (f.id == id) {
        f.isFollowing = !f.isFollowing;
        break;
      }
    }
    notifyListeners();
  }

  Future<void> loadContactsFromDirectory() async {
    final list = await ApiService.getContactDirectory();
    if (list != null) {
      final List<Friend> directoryFriends = [];
      for (final item in list) {
        final String contactName = item['contact_name'] ?? 'Unknown';
        final String displayName = item['matched_user_display_name'] ?? contactName;
        final String contactId = item['contact_id'] ?? '';
        final String matchedUserId = item['matched_user_id'] ?? '';
        final String action = item['action'] ?? '';
        
        final isSelf = action == 'self';
        final isMatched = matchedUserId.isNotEmpty;

        String initials = 'C';
        if (contactName.isNotEmpty) {
          try {
            final clean = contactName.trim().replaceAll(RegExp(r'[^\w]'), '');
            initials = clean.isNotEmpty ? clean[0] : String.fromCharCode(contactName.runes.first);
          } catch (_) {
            initials = 'C';
          }
        }

        directoryFriends.add(Friend(
          id: matchedUserId.isNotEmpty ? matchedUserId : contactId,
          name: contactName,
          username: isMatched ? '@$displayName' : 'Not on CardCircle',
          initials: initials.toUpperCase(),
          cardsCount: isSelf ? 5 : (isMatched ? 3 : 0),
          savings: isMatched ? '₹15,000' : '₹0',
          level: isSelf ? 'Me' : (isMatched ? 'Saver' : 'Invite Only'),
          isFollowing: isSelf || action == 'request_received',
          commonCards: isMatched ? ['SBI Cashback'] : [],
          gradientColors: isSelf 
              ? [const Color(0xFF134E5E), const Color(0xFF71B280)]
              : [const Color(0xFF23074D), const Color(0xFF8B2FC9)],
        ));
      }
      _friends = directoryFriends;
      notifyListeners();
    }
  }
}
