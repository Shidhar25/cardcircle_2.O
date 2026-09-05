/// The relationship state `GET /user/contacts/directory` reports for a
/// contact, in its `action` field.
///
/// This drives what a row can do, so it must stay a distinct state rather
/// than collapsing into a boolean — a pending request, an approved follow and
/// a block all previously read as "not following" and offered a Follow
/// button, which either did nothing or re-sent a request that was already
/// rejected.
enum ContactAction {
  /// The contact resolved to your own account.
  self,

  /// Not a CardCircle user yet — nothing to follow, only to invite.
  inviteOnly,

  /// You follow them and it is approved.
  following,

  /// You sent a follow request that is still pending.
  requestSent,

  /// Your request was rejected, or they blocked you.
  blocked,

  /// They sent you a follow request awaiting your response.
  requestReceived,

  /// Matched user, no active relationship — you can send a request.
  follow;

  /// Parses the backend's snake_case string.
  ///
  /// An unrecognised value falls back to [follow] rather than throwing: a new
  /// server-side state should degrade to "you may request" instead of
  /// crashing the Circle screen.
  static ContactAction parse(String? raw) {
    switch (raw) {
      case 'self':
        return ContactAction.self;
      case 'invite_only':
        return ContactAction.inviteOnly;
      case 'following':
        return ContactAction.following;
      case 'request_sent':
        return ContactAction.requestSent;
      case 'blocked':
        return ContactAction.blocked;
      case 'request_received':
        return ContactAction.requestReceived;
      case 'follow':
      default:
        return ContactAction.follow;
    }
  }

  /// Whether this contact has a CardCircle account behind them.
  bool get isMatchedUser =>
      this != ContactAction.inviteOnly && this != ContactAction.self;

  /// Whether the row belongs in Suggested.
  ///
  /// Excludes yourself and anyone who blocked you, per product rules, plus
  /// people you already follow — Suggested is for relationships you could
  /// still start, not a directory dump.
  bool get belongsInSuggested =>
      this == ContactAction.follow ||
      this == ContactAction.requestSent ||
      this == ContactAction.requestReceived;

  /// Label for the row's trailing control.
  String get label {
    switch (this) {
      case ContactAction.following:
        return 'Following';
      case ContactAction.requestSent:
        return 'Requested';
      case ContactAction.requestReceived:
        return 'Respond';
      case ContactAction.inviteOnly:
        return 'Invite';
      case ContactAction.follow:
        return 'Follow';
      case ContactAction.self:
      case ContactAction.blocked:
        return '';
    }
  }

  /// Where this state sorts in the contacts list, lowest first.
  ///
  /// The list is ordered by what the user can do with the row rather than
  /// by name: people you can act on now come first, and address-book
  /// entries who are not on CardCircle sink to the bottom — there is
  /// nothing to do with them but send an invite, and they are usually the
  /// bulk of a phone book.
  ///
  /// `self` and `blocked` are filtered out before sorting; they are given
  /// the last positions so an unfiltered caller still cannot float them to
  /// the top.
  int get sortPriority {
    switch (this) {
      case ContactAction.follow:
        return 0;
      case ContactAction.requestSent:
        return 1;
      case ContactAction.requestReceived:
        return 2;
      case ContactAction.following:
        return 3;
      case ContactAction.inviteOnly:
        return 4;
      case ContactAction.self:
        return 5;
      case ContactAction.blocked:
        return 6;
    }
  }

  /// Whether the control does anything when tapped. A sent request has no
  /// action until the other side answers, so it reads as a status, not a
  /// button.
  bool get isActionable =>
      this == ContactAction.follow ||
      this == ContactAction.following ||
      this == ContactAction.inviteOnly ||
      this == ContactAction.requestReceived;
}
