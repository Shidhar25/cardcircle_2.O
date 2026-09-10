/// Who in the reader's circle holds a card this benefit works on.
///
/// Sent per hack as `circle_availability`. The point of the app is that a
/// benefit is worth more when someone you know can actually use it, so this
/// answers "who could avail this?" rather than "how many people exist".
///
/// A friend holding two qualifying cards appears once, with both cards
/// listed. Only cards a friend explicitly shared are ever named, so this
/// stays inside the permission model the circle already has.
class CircleAvailability {
  /// Distinct friends who can avail it — the server's own count, which is
  /// the number to trust when [users] is truncated.
  final int count;

  final List<CircleHolder> users;

  const CircleAvailability({required this.count, required this.users});

  static const CircleAvailability none = CircleAvailability(
    count: 0,
    users: [],
  );

  bool get isEmpty => count == 0 && users.isEmpty;

  /// Friends beyond the ones a compact summary names.
  int othersBeyond(int shown) {
    final extra = count - shown;
    return extra > 0 ? extra : 0;
  }

  static CircleAvailability parse(dynamic raw) {
    if (raw is! Map) return none;
    final json = raw.cast<String, dynamic>();
    final users =
        (json['users'] as List?)
            ?.whereType<Map>()
            .map((u) => CircleHolder.fromJson(u.cast<String, dynamic>()))
            .nonNulls
            .toList() ??
        const <CircleHolder>[];
    final rawCount = json['count'];
    final count = rawCount is num ? rawCount.toInt() : users.length;
    return CircleAvailability(count: count, users: users);
  }
}

/// One friend, and the qualifying cards of theirs the reader may see.
class CircleHolder {
  final String userId;
  final String displayName;
  final String? profilePictureUrl;
  final List<String> cards;

  const CircleHolder({
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
    this.cards = const [],
  });

  static CircleHolder? fromJson(Map<String, dynamic> json) {
    final name = json['display_name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final picture = json['profile_picture_url']?.toString().trim();
    return CircleHolder(
      userId: json['user_id']?.toString() ?? '',
      displayName: name,
      profilePictureUrl: (picture == null || picture.isEmpty) ? null : picture,
      cards:
          (json['cards'] as List?)
              ?.map((c) => c.toString().trim())
              .where((c) => c.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  /// Two letters for the avatar fallback, from a display name that may be
  /// a handle (`rahul_k`) rather than a first/last pair.
  String get initials {
    final parts = displayName
        .split(RegExp(r'[\s_.\-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final one = parts.first;
      return (one.length == 1 ? one : one.substring(0, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
