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

  /// A request still worth showing under Requests > Incoming.
  ///
  /// Same reasoning as [_isPendingOutgoing]: `GET /follow/requests/incoming`
  /// keeps a row around after it settles, so without filtering an
  /// already-approved/rejected request sat there forever with live
  /// Approve/Reject buttons that no longer did anything meaningful.
  static bool _isPendingIncoming(Map<String, dynamic> row) {
    final status = (row['status'] as String?)?.trim().toUpperCase();
    return status == null || status.isEmpty || status == 'PENDING';
  }

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
  /// The pill flips the instant this is called, before the round trip —
  /// to `requestSent`/`open`->`PENDING`, or back to `follow`/removed from
  /// Following & Requests-Sent, whichever the tap implies — and is rolled
  /// back to exactly what it was if the server rejects it. A user tapping
  /// Follow, Follow back, or Requested-to-cancel wants to see it react now,
  /// not after a network delay or a manual pull-to-refresh, and every tab
  /// reads this same [CircleState], so the update is dynamic across
  /// Following, Followers, Requests and Contacts/Suggested at once rather
  /// than only wherever the tap happened.
  ///
  ///   * following   -> unfollow -> follow    (you may request again)
  ///   * requestSent -> unfollow -> follow    (cancelling; same endpoint as
  ///                                           [cancelOutgoing] — the server
  ///                                           just tears down whichever
  ///                                           relationship exists)
  ///   * follow      -> request  -> requestSent (it creates a *request*)
  ///
  /// [id] can be a synced contact (in `_friends`), someone already in
  /// `_following` who was never a synced contact (followed from search or
  /// a benefit's detail page), a follower being followed back (in
  /// `_followers`, via `follow_back_status`), a row in `_outgoingRequests`,
  /// or any combination — all matching rows are updated together so no tab
  /// is left showing a stale relationship. [displayName] names the new
  /// `_outgoingRequests` row a fresh follow adds, for a caller (the
  /// Followers tab's "Follow back") with no `_friends` row to read a name
  /// from.
  Future<ApiResult<Map<String, dynamic>>> toggleFollow(
    String id, {
    String? displayName,
  }) async {
    final index = _friends.indexWhere((f) => f.id == id);
    final friend = index == -1 ? null : _friends[index];

    // Only these three ever reach here from the UI: Follow, Follow back
    // (both create a request) and Requested (cancels one). Everything else
    // — self, blocked, inviteOnly (has its own Invite flow), following
    // itself only via a dedicated Unfollow control — has no path to this
    // method at all, but is still rejected defensively.
    if (friend != null &&
        friend.action != ContactAction.follow &&
        friend.action != ContactAction.following &&
        friend.action != ContactAction.requestSent) {
      return const ApiResult.failure('No action available for this contact.');
    }

    final followingIndex = _following.indexWhere((f) => f['user_id'] == id);
    final followerIndex = _followers.indexWhere((f) => f['user_id'] == id);
    final outgoingIndex = _outgoingRequests.indexWhere(
      (r) => r['following_user_id'] == id,
    );

    // Whether this tap tears an existing relationship down (unfollow, or
    // cancelling a request already sent) rather than starting one. Reading
    // this from `_friends` alone meant unfollowing someone who was never a
    // synced contact (followed via search, or a benefit's detail page) read
    // as "not following" and sent a fresh follow *request* instead — and a
    // sent-request row (`requestSent`) needs the same tear-down endpoint as
    // an unfollow, not another follow attempt.
    final tearingDown =
        friend?.action == ContactAction.following ||
        friend?.action == ContactAction.requestSent ||
        followingIndex != -1 ||
        outgoingIndex != -1;
    LoggerService.debug(
      'Toggling follow for $id (${friend?.action.name ?? 'not in directory'}, '
      'tearingDown=$tearingDown)',
    );

    final previousAction = friend?.action;
    final previousFollowBackStatus = followerIndex == -1
        ? null
        : _followers[followerIndex]['follow_back_status'];
    final removedFollowingRow = followingIndex == -1
        ? null
        : _following[followingIndex];
    final removedOutgoingRow = outgoingIndex == -1
        ? null
        : _outgoingRequests[outgoingIndex];
    final name =
        friend?.name ??
        displayName ??
        (followerIndex == -1
            ? null
            : _followers[followerIndex]['name']?.toString()) ??
        'them';

    _applyFollowState(
      friendId: id,
      followerId: id,
      following: tearingDown ? ContactAction.follow : ContactAction.requestSent,
      followBackStatus: tearingDown ? null : 'PENDING',
    );
    if (tearingDown) {
      if (followingIndex != -1) _following.removeAt(followingIndex);
      if (outgoingIndex != -1) _outgoingRequests.removeAt(outgoingIndex);
    } else {
      // A fresh request shows up in Requests > Sent immediately too, not
      // just as this row's own pill.
      _outgoingRequests.insert(0, {
        'following_user_id': id,
        'following_display_name': name,
        'status': 'PENDING',
      });
    }
    notifyListeners();

    final result = tearingDown
        ? await ApiService.unfollowUser(id)
        : await ApiService.followUser(id);

    if (!result.ok) {
      // Roll back to exactly what it was before the tap — never guess a
      // different failure state, since the server hasn't said anything
      // actually changed.
      _applyFollowState(
        friendId: id,
        followerId: id,
        following: previousAction,
        followBackStatus: previousFollowBackStatus,
      );
      if (tearingDown) {
        if (removedFollowingRow != null) {
          _following.insert(
            followingIndex.clamp(0, _following.length),
            removedFollowingRow,
          );
        }
        if (removedOutgoingRow != null) {
          _outgoingRequests.insert(
            outgoingIndex.clamp(0, _outgoingRequests.length),
            removedOutgoingRow,
          );
        }
      } else {
        _outgoingRequests.removeWhere((r) => r['following_user_id'] == id);
      }
      notifyListeners();
      return result;
    }

    final next = resolveAction(
      result.data?['status'] as String?,
      wasFollowing: tearingDown,
    );
    _applyFollowState(friendId: id, following: next);
    notifyListeners();
    return result;
  }

  /// Writes [following] and/or [followBackStatus] onto whichever of
  /// `_friends` / `_followers` currently has a row for this id, leaving
  /// lists with no matching row untouched. Centralised so `toggleFollow`'s
  /// optimistic-apply, its rollback, and its post-success reconciliation
  /// all touch the same two lists the same way rather than three
  /// hand-copied blocks that could drift apart.
  void _applyFollowState({
    required String friendId,
    String? followerId,
    ContactAction? following,
    Object? followBackStatus = _unset,
  }) {
    if (following != null) {
      final i = _friends.indexWhere((f) => f.id == friendId);
      if (i != -1) _friends[i] = _friends[i].withAction(following);
    }
    if (followerId != null && !identical(followBackStatus, _unset)) {
      final i = _followers.indexWhere((f) => f['user_id'] == followerId);
      if (i != -1) {
        _followers[i] = {
          ..._followers[i],
          'follow_back_status': followBackStatus,
        };
      }
    }
  }

  /// Sentinel distinguishing "leave `follow_back_status` alone" from
  /// "set it to null" — a real, valid value meaning "open" (see
  /// [FollowBackStatus.parse]).
  static const Object _unset = Object();

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
      _incomingRequests = list.where(_isPendingIncoming).toList();
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

  /// A request still worth showing under Requests > Sent.
  ///
  /// The server keeps the row around after it settles rather than deleting
  /// it, so `APPROVED`/`REJECTED`/`CANCELLED`/`BLOCKED` all still come back
  /// from `GET /follow/requests/outgoing` — without filtering, an approved
  /// request sat in "Sent" forever with a stray Cancel button that no
  /// longer did anything meaningful. Missing `status` is kept: several call
  /// sites default it to `'PENDING'` on the assumption an omitted status
  /// means still-pending.
  static bool _isPendingOutgoing(Map<String, dynamic> row) {
    final status = (row['status'] as String?)?.trim().toUpperCase();
    return status == null || status.isEmpty || status == 'PENDING';
  }

  Future<void> fetchOutgoingRequests() async {
    final list = await ApiService.getOutgoingFollowRequests();
    if (list != null) {
      _outgoingRequests = list.where(_isPendingOutgoing).toList();
      notifyListeners();
    }
  }

  /// Cancels a request you sent. Same endpoint as unfollow — the server
  /// cancels whichever relationship exists with that recipient.
  ///
  /// Optimistic, like [toggleFollow]: the row disappears from Sent and the
  /// matching Contacts/Suggested and Followers ("follow back requested")
  /// rows flip back immediately, rolled back if the server refuses.
  Future<ApiResult<Map<String, dynamic>>> cancelOutgoing(
    String userId,
  ) async {
    final outgoingIndex = _outgoingRequests.indexWhere(
      (r) => r['following_user_id'] == userId,
    );
    final removedOutgoingRow = outgoingIndex == -1
        ? null
        : _outgoingRequests[outgoingIndex];

    final friendIndex = _friends.indexWhere((f) => f.id == userId);
    final previousAction = friendIndex == -1
        ? null
        : _friends[friendIndex].action;

    final followerIndex = _followers.indexWhere(
      (f) => f['user_id'] == userId,
    );
    final previousFollowBackStatus = followerIndex == -1
        ? null
        : _followers[followerIndex]['follow_back_status'];

    if (outgoingIndex != -1) _outgoingRequests.removeAt(outgoingIndex);
    _applyFollowState(
      friendId: userId,
      followerId: userId,
      following: ContactAction.follow,
      followBackStatus: null,
    );
    notifyListeners();

    final result = await ApiService.unfollowUser(userId);
    if (!result.ok) {
      if (removedOutgoingRow != null) {
        _outgoingRequests.insert(
          outgoingIndex.clamp(0, _outgoingRequests.length),
          removedOutgoingRow,
        );
      }
      _applyFollowState(
        friendId: userId,
        followerId: userId,
        following: previousAction,
        followBackStatus: previousFollowBackStatus,
      );
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
