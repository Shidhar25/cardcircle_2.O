import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/models.dart';

class CircleState extends ChangeNotifier {
  List<Friend> _friends = [];
  List<Friend> get friends => _friends;

  List<Friend> get suggestedFriends => _friends.where((f) => f.username != 'Not on CardCircle' && !f.isFollowing && f.level != 'Me').toList();
  List<Friend> get inviteOnlyFriends => _friends.where((f) => f.username == 'Not on CardCircle').toList();

  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> get incomingRequests => _incomingRequests;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> get followersList => _followers;

  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> get followingList => _following;

  bool _isLoadingIncoming = false;
  bool get isLoadingIncoming => _isLoadingIncoming;

  bool _isLoadingFollowersFollowing = false;
  bool get isLoadingFollowersFollowing => _isLoadingFollowersFollowing;

  Future<bool> toggleFollow(String id) async {
    LoggerService.debug('Toggling follow for friend ID: $id');
    Friend? targetFriend;
    for (var f in _friends) {
      if (f.id == id) {
        targetFriend = f;
        break;
      }
    }

    if (targetFriend == null) return false;

    final wasFollowing = targetFriend.isFollowing;
    final success = wasFollowing
        ? await ApiService.unfollowUser(id)
        : await ApiService.followUser(id);

    if (success) {
      targetFriend.isFollowing = !wasFollowing;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> fetchIncomingRequests() async {
    _isLoadingIncoming = true;
    notifyListeners();
    final list = await ApiService.getIncomingFollowRequests();
    if (list != null) {
      _incomingRequests = list;
    }
    _isLoadingIncoming = false;
    notifyListeners();
  }

  Future<void> fetchFollowersAndFollowing() async {
    _isLoadingFollowersFollowing = true;
    notifyListeners();
    final followersResult = await ApiService.getFollowers();
    if (followersResult != null) {
      _followers = followersResult;
    }
    final followingResult = await ApiService.getFollowing();
    if (followingResult != null) {
      _following = followingResult;
    }
    _isLoadingFollowersFollowing = false;
    notifyListeners();
  }

  Future<bool> approveRequest(String followId, List<String> allowedCardIds) async {
    final success = await ApiService.approveFollowRequest(followId, allowedCardIds);
    if (success) {
      _incomingRequests.removeWhere((req) => req['follow_id'] == followId);
      await loadContactsFromDirectory();
      notifyListeners();
    }
    return success;
  }

  Future<bool> rejectRequest(String followId) async {
    final success = await ApiService.rejectFollowRequest(followId);
    if (success) {
      _incomingRequests.removeWhere((req) => req['follow_id'] == followId);
      notifyListeners();
    }
    return success;
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
    await fetchIncomingRequests();
    await fetchFollowersAndFollowing();
  }
}
