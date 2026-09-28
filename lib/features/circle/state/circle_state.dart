import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_result.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/models.dart';

class CircleState extends ChangeNotifier {
  List<Friend> _friends = [];
  List<Friend> get friends => _friends;

  /// People you could still start a relationship with.
  ///
  /// Excludes yourself, anyone who blocked you, contacts who aren't on the
  /// platform, and people you already follow — see
  /// [ContactAction.belongsInSuggested].
  List<Friend> get suggestedFriends =>
      _friends.where((f) => f.action.belongsInSuggested).toList();

  /// Matched contacts you already follow.
  List<Friend> get followingFriends =>
      _friends.where((f) => f.action == ContactAction.following).toList();

  /// Contacts with no CardCircle account yet — invite targets.
  List<Friend> get inviteOnlyFriends =>
      _friends.where((f) => f.action == ContactAction.inviteOnly).toList();

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

  /// Advances the relationship with [id] and reports what the server said.
  ///
  /// The pill flips the instant this is called — to `requestSent` or back
  /// to `follow`, whichever the tap implies — rather than waiting out the
  /// round trip first. A user tapping Follow wants to see it react now, not
  /// after a network delay; a spinner for every tap made the whole screen
  /// feel slow. The optimistic guess is reconciled with the server's actual
  /// `status` on success, and rolled back to exactly what it was before the
  /// tap if the call fails — so a rejected follow never leaves a pill
  /// stuck showing a state the server didn't agree to.
  ///
  ///   * following  -> unfollow  -> follow (you may request again)
  ///   * follow     -> request   -> requestSent (it creates a *request*)
  Future<ApiResult<Map<String, dynamic>>> toggleFollow(String id) async {
    final index = _friends.indexWhere((f) => f.id == id);
    final friend = index == -1 ? null : _friends[index];

    if (friend != null && !friend.action.isActionable) {
      return const ApiResult.failure('No action available for this contact.');
    }

    // Someone can follow you without being in your address book, so the
    // Followers tab offers a follow-back for people who are not in
    // `_friends` at all. Treating an unknown id as an error made that
    // button do nothing; instead assume "not yet following" and let the
    // server arbitrate.
    final wasFollowing = friend?.action == ContactAction.following;
    final previousAction = friend?.action;
    LoggerService.debug(
      'Toggling follow for $id (${friend?.action.name ?? 'not in directory'})',
    );

    if (friend != null) {
      final optimistic = wasFollowing
          ? ContactAction.follow
          : ContactAction.requestSent;
      _friends[index] = friend.withAction(optimistic);
      notifyListeners();
    }

    // The Followers tab's "follow back" button reads a different, raw row
    // (`_followers`, keyed by `user_id`) rather than `_friends` — someone
    // can follow you without being in your address book. Flip its
    // `follow_back_status` the same way, so that pill reacts instantly too.
    final followerRowIndex = friend == null
        ? _followers.indexWhere((r) => r['user_id'] == id)
        : -1;
    final previousFollowBackStatus = followerRowIndex == -1
        ? null
        : _followers[followerRowIndex]['follow_back_status'];
    if (followerRowIndex != -1) {
      _followers[followerRowIndex] = {
        ..._followers[followerRowIndex],
        'follow_back_status': 'PENDING',
      };
      notifyListeners();
    }

    final result = wasFollowing
        ? await ApiService.unfollowUser(id)
        : await ApiService.followUser(id);

    if (!result.ok) {
      // Roll back to exactly what it was before the tap — never guess a
      // different failure state, since the server hasn't said anything
      // actually changed.
      if (friend != null && previousAction != null) {
        final rollbackIndex = _friends.indexWhere((f) => f.id == id);
        if (rollbackIndex != -1) {
          _friends[rollbackIndex] = _friends[rollbackIndex].withAction(
            previousAction,
          );
          notifyListeners();
        }
      }
      if (followerRowIndex != -1) {
        final rollbackRowIndex = _followers.indexWhere(
          (r) => r['user_id'] == id,
        );
        if (rollbackRowIndex != -1) {
          _followers[rollbackRowIndex] = {
            ..._followers[rollbackRowIndex],
            'follow_back_status': previousFollowBackStatus,
          };
          notifyListeners();
        }
      }
      return result;
    }

    final next = resolveAction(
      result.data?['status'] as String?,
      wasFollowing: wasFollowing,
    );

    if (friend != null) {
      final settledIndex = _friends.indexWhere((f) => f.id == id);
      if (settledIndex != -1) {
        _friends[settledIndex] = _friends[settledIndex].withAction(next);
        notifyListeners();
      }
    } else {
      // Nothing local to update — re-read so the followers row reflects the
      // new relationship.
      await fetchFollowersAndFollowing();
    }
    return result;
  }

  /// Maps the follow endpoints' `data.status` onto a [ContactAction].
  ///
  /// The follow API reports the *relationship record's* status — `PENDING`,
  /// `APPROVED`, `REJECTED`, `CANCELLED`, `BLOCKED` — which is a different
  /// vocabulary from the contact directory's `action` field. Passing one
  /// through `ContactAction.parse` therefore never matched, and the value
  /// silently degraded to `follow`; it only looked correct because the
  /// endpoint-implied fallback happened to agree. This maps the two
  /// vocabularies explicitly.
  @visibleForTesting
  static ContactAction resolveAction(
    String? status, {
    required bool wasFollowing,
  }) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return ContactAction.requestSent;
      case 'APPROVED':
        return ContactAction.following;
      case 'BLOCKED':
        return ContactAction.blocked;
      case 'REJECTED':
      case 'CANCELLED':
        // The relationship is over; you may ask again.
        return ContactAction.follow;
    }

    // Some responses report the directory vocabulary instead. Trust it only
    // when the server actually named a state we recognise — `parse`
    // degrades anything unknown to `follow`, which right after a successful
    // follow would put a "Follow" button back on the row.
    if (status != null && status.isNotEmpty) {
      final parsed = ContactAction.parse(status);
      if (parsed != ContactAction.follow || status == 'follow') return parsed;
    }

    // No status at all: fall back to what the endpoint necessarily means.
    // POST creates a pending request; DELETE cancels the relationship.
    return wasFollowing ? ContactAction.follow : ContactAction.requestSent;
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

  Future<ApiResult<Map<String, dynamic>>> approveRequest(
    String followId,
    List<String> allowedCardIds,
  ) async {
    final result = await ApiService.approveFollowRequest(
      followId,
      allowedCardIds,
    );
    if (result.ok) {
      _incomingRequests.removeWhere((req) => req['follow_id'] == followId);
      notifyListeners();
      // The approval changes this person's directory state, so re-read it
      // rather than guessing.
      await loadContactsFromDirectory();
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> rejectRequest(String followId) async {
    final result = await ApiService.rejectFollowRequest(followId);
    if (result.ok) {
      _incomingRequests.removeWhere((req) => req['follow_id'] == followId);
      notifyListeners();
    }
    return result;
  }

  List<Map<String, dynamic>> _outgoingRequests = [];
  List<Map<String, dynamic>> get outgoingRequests => _outgoingRequests;

  Future<void> fetchOutgoingRequests() async {
    final list = await ApiService.getOutgoingFollowRequests();
    if (list != null) {
      _outgoingRequests = list;
      notifyListeners();
    }
  }

  /// Cancels a request you sent. Same endpoint as unfollow — the server
  /// cancels whichever relationship exists with that recipient.
  Future<ApiResult<Map<String, dynamic>>> cancelOutgoing(String userId) async {
    final result = await ApiService.unfollowUser(userId);
    if (result.ok) {
      _outgoingRequests.removeWhere((r) => r['following_user_id'] == userId);
      // The directory row for this person goes back to "follow".
      final i = _friends.indexWhere((f) => f.id == userId);
      if (i != -1) {
        _friends[i] = _friends[i].withAction(ContactAction.follow);
      }
      notifyListeners();
    }
    return result;
  }

  /// Loads every list this screen shows, in parallel.
  Future<void> loadAll() async {
    await Future.wait([loadContactsFromDirectory(), fetchOutgoingRequests()]);
  }

  Future<void> loadContactsFromDirectory() async {
    final list = await ApiService.getContactDirectory();
    if (list != null) {
      final List<Friend> directoryFriends = [];
      for (final item in list) {
        final String contactName = item['contact_name'] ?? 'Unknown';
        final String displayName =
            item['matched_user_display_name'] ?? contactName;
        final String contactId = item['contact_id'] ?? '';
        final String matchedUserId = item['matched_user_id'] ?? '';
        final action = ContactAction.parse(item['action'] as String?);
        final isSelf = action == ContactAction.self;
        final isMatched = action.isMatchedUser && matchedUserId.isNotEmpty;

        String initials = 'C';
        if (contactName.isNotEmpty) {
          try {
            final clean = contactName.trim().replaceAll(RegExp(r'[^\w]'), '');
            initials = clean.isNotEmpty
                ? clean[0]
                : String.fromCharCode(contactName.runes.first);
          } catch (_) {
            initials = 'C';
          }
        }

        directoryFriends.add(
          Friend(
            id: matchedUserId.isNotEmpty ? matchedUserId : contactId,
            contactId: contactId,
            mobileNumber: (item['mobile_number'] ?? '').toString(),
            name: contactName,
            username: isMatched ? '@$displayName' : 'Not on CardCircle',
            initials: initials.toUpperCase(),
            // Only what the directory actually returns. Inventing card
            // counts or levels here put fake numbers against real people.
            cardsCount: (item['cards_count'] as int?) ?? 0,
            level: isSelf ? 'Me' : (isMatched ? '' : 'Invite Only'),
            action: action,
            commonCards:
                (item['common_cards'] as List?)?.cast<String>() ?? const [],
            gradientColors: isSelf
                ? [const Color(0xFF134E5E), const Color(0xFF71B280)]
                : [const Color(0xFF23074D), const Color(0xFF8B2FC9)],
          ),
        );
      }
      _friends = directoryFriends;
      notifyListeners();
    }
    await fetchIncomingRequests();
    await fetchFollowersAndFollowing();
  }

  /// Drops every list held for the signed-out account.
  ///
  /// Called on logout: without this, the next account to sign in on this
  /// device would briefly see the previous account's contacts, followers
  /// and requests until each list happened to refetch.
  void clear() {
    _friends = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _followers = [];
    _following = [];
    notifyListeners();
  }
}
