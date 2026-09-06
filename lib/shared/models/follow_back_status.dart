/// Whether you follow one of your followers back.
///
/// Reads `follow_back_status` from `GET /follow/followers`. Approving
/// someone's request is one-directional — they can see the cards you
/// shared, you still cannot see theirs — so this is what tells the
/// Followers list whether to offer a reciprocal follow.
enum FollowBackStatus {
  /// No relationship in that direction. Offer to follow them back.
  open,

  /// A request is already sitting with them, awaiting approval. Offering
  /// again would send a duplicate the server rejects.
  requested,

  /// Already mutual — nothing to offer.
  mutual;

  /// Reads the server's value.
  ///
  /// Null is the common case and means "not following them", so it maps to
  /// [open]. An empty or whitespace-only string is treated the same way: it
  /// is not a real status, and reading it as "already handled" would
  /// silently drop the offer — the worse of the two failure modes, because
  /// it is invisible.
  ///
  /// An unrecognised value maps to [mutual], on the reasoning that the
  /// server knows about a relationship this build does not: staying quiet
  /// beats offering a follow that will be rejected.
  static FollowBackStatus parse(Object? raw) {
    final value = raw?.toString().trim().toUpperCase();
    if (value == null || value.isEmpty) return FollowBackStatus.open;

    switch (value) {
      case 'PENDING':
        return FollowBackStatus.requested;
      case 'APPROVED':
        return FollowBackStatus.mutual;
      default:
        return FollowBackStatus.mutual;
    }
  }

  /// Whether the Followers row should show a "Follow back" control.
  bool get canFollowBack => this == FollowBackStatus.open;
}
