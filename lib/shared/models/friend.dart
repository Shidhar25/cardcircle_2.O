import 'package:flutter/material.dart';

import 'contact_action.dart';

/// A person in your contact directory.
///
/// [action] is the single source of truth for the relationship. There used
/// to be a mutable `isFollowing` bool alongside it, and the two drifted the
/// moment anyone pressed Follow: the toggle flipped the bool but left
/// `action` on `follow`, so the row kept saying "Follow", stayed in
/// Suggested, and never appeared under Following. Everything relationship
/// shaped is now derived from [action].
@immutable
class Friend {
  /// The matched CardCircle user id when there is one, otherwise the
  /// directory's contact id. Follow/unfollow address people by this.
  final String id;

  /// The address-book row id (`contact_id`), always present.
  ///
  /// Kept separate from [id] because invites are addressed by contact,
  /// never by user — an invite-only contact has no user id at all. The two
  /// happen to be equal for invite-only rows, and relying on that
  /// coincidence is how the wrong id ends up in a request.
  final String contactId;

  /// The contact's phone number as the directory returned it.
  ///
  /// Shown where a contact needs identifying without a username — two
  /// people in an address book share a name often enough that the number
  /// is the only thing telling them apart. Empty when the directory did
  /// not include one.
  final String mobileNumber;

  final String name;
  final String username;
  final String initials;
  final int cardsCount;
  final String level;

  /// Relationship state from the directory. Drives the row's control and
  /// which tab the person appears in.
  final ContactAction action;

  final List<String> commonCards;
  final List<Color> gradientColors;

  const Friend({
    required this.id,
    required this.contactId,
    this.mobileNumber = '',
    required this.name,
    required this.username,
    required this.initials,
    required this.cardsCount,
    required this.level,
    required this.action,
    required this.commonCards,
    required this.gradientColors,
  });

  /// An approved, active follow. A sent-but-pending request is deliberately
  /// not "following".
  bool get isFollowing => action == ContactAction.following;

  /// Returns a copy in a new relationship state, for optimistic updates.
  Friend withAction(ContactAction next) => Friend(
    id: id,
    contactId: contactId,
    mobileNumber: mobileNumber,
    name: name,
    username: username,
    initials: initials,
    cardsCount: cardsCount,
    level: level,
    action: next,
    commonCards: commonCards,
    gradientColors: gradientColors,
  );
}
