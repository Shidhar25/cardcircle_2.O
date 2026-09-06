/// The kinds of notification the app knows how to present.
enum NotificationKind {
  /// Someone from the reader's synced contacts has just joined
  /// (`CONTACT_JOINED`). Carries `joined_user_id` / `joined_display_name`.
  contactJoined,

  /// Someone asked to follow the reader.
  followRequest,

  /// Something else — still shown, just without a tailored icon or action.
  other;

  static NotificationKind parse(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'CONTACT_JOINED':
        return NotificationKind.contactJoined;
      case 'FOLLOW_REQUEST':
        return NotificationKind.followRequest;
      default:
        return NotificationKind.other;
    }
  }
}

/// One row from `GET /push/notifications`.
///
/// Unknown types are kept rather than filtered: the server records the
/// title and body, so an unrecognised notification still reads correctly
/// even on a build that predates its type. Only the icon and the tap
/// action are type-specific.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final bool isRead;
  final DateTime? createdAt;

  /// The `data` block, as sent.
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.isRead,
    required this.createdAt,
    required this.data,
  });

  /// The account of whoever just joined, for [NotificationKind.contactJoined].
  String? get joinedUserId {
    final v = data['joined_user_id'];
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? get joinedDisplayName {
    final v = data['joined_display_name'];
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  static AppNotification? tryParse(Map<String, dynamic> json) {
    final id = (json['notification_id'] ?? json['id'])?.toString();
    // Without an id it cannot be marked read, and a row that re-appears
    // after every tap is worse than one that is absent.
    if (id == null || id.isEmpty) return null;

    final raw = json['data'];
    return AppNotification(
      id: id,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? json['message'] ?? '').toString(),
      kind: NotificationKind.parse(json['notification_type']?.toString()),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
      data: raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  /// Elapsed time, phrased the way a reader thinks about it.
  ///
  /// The list previously printed `created_at` verbatim — an ISO timestamp,
  /// which tells the reader nothing at a glance.
  String get relativeTime {
    final at = createdAt;
    if (at == null) return '';

    final diff = DateTime.now().difference(at);
    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Whether tapping should take the reader somewhere.
  bool get isActionable => kind == NotificationKind.contactJoined;
}
