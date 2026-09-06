import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/app_notification.dart';

/// Distinguishes "argument not passed" from "passed as null", which a
/// plain `??` default cannot.
const Object _unset = Object();

/// A live CONTACT_JOINED row, as the backfill records it.
Map<String, dynamic> _row({
  String? type = 'CONTACT_JOINED',
  Object? data = _unset,
  Object? id = 'n1',
  bool isRead = false,
  String? createdAt,
}) => {
  'notification_id': id,
  'title': 'A friend joined CardCircle!',
  'body': 'Bob is now on CardCircle - follow them to see their cards',
  'notification_type': type,
  'is_read': isRead,
  'created_at': createdAt,
  'data': identical(data, _unset)
      ? {'joined_user_id': 'u9', 'joined_display_name': 'Bob'}
      : data,
};

void main() {
  group('CONTACT_JOINED', () {
    test('parses the type and its data', () {
      final n = AppNotification.tryParse(_row())!;
      expect(n.kind, NotificationKind.contactJoined);
      expect(n.joinedUserId, 'u9');
      expect(n.joinedDisplayName, 'Bob');
    });

    test('is actionable — there is somewhere useful to go', () {
      // The point of the notification is to follow them, so it routes to
      // Circle rather than being a dead row.
      expect(AppNotification.tryParse(_row())!.isActionable, isTrue);
    });

    test('other kinds are shown but lead nowhere', () {
      final follow = AppNotification.tryParse(_row(type: 'FOLLOW_REQUEST'))!;
      expect(follow.kind, NotificationKind.followRequest);
      expect(follow.isActionable, isFalse);
    });

    test('an unknown type still renders rather than being dropped', () {
      // The server recorded a title and body, so the row reads correctly
      // even on a build that predates the type.
      final n = AppNotification.tryParse(_row(type: 'SOMETHING_NEW'))!;
      expect(n.kind, NotificationKind.other);
      expect(n.title, isNotEmpty);
      expect(n.isActionable, isFalse);
    });
  });

  group('malformed rows', () {
    test('no id means it is dropped', () {
      // Without an id it can never be marked read, so it would come back
      // unread after every tap.
      expect(AppNotification.tryParse(_row(id: null)), isNull);
      expect(AppNotification.tryParse(_row(id: '')), isNull);
    });

    test('a missing data block does not throw', () {
      final n = AppNotification.tryParse(_row(data: <String, dynamic>{}))!;
      expect(n.joinedUserId, isNull);
      expect(n.joinedDisplayName, isNull);
    });

    test('a non-map data block does not throw', () {
      for (final bad in ['nope', 42, null]) {
        final n = AppNotification.tryParse(_row(data: bad));
        expect(n, isNotNull, reason: '$bad');
        expect(n!.joinedUserId, isNull, reason: '$bad');
      }
    });

    test('an unparseable timestamp yields no time rather than throwing', () {
      final n = AppNotification.tryParse(_row(createdAt: 'not a date'))!;
      expect(n.createdAt, isNull);
      expect(n.relativeTime, isEmpty);
    });
  });

  group('relative time', () {
    String ago(Duration d) => AppNotification.tryParse(
      _row(createdAt: DateTime.now().subtract(d).toUtc().toIso8601String()),
    )!.relativeTime;

    test('reads the way someone thinks about elapsed time', () {
      // The list used to print the ISO timestamp verbatim.
      expect(ago(const Duration(seconds: 20)), 'Just now');
      expect(ago(const Duration(minutes: 5)), '5m ago');
      expect(ago(const Duration(hours: 3)), '3h ago');
      expect(ago(const Duration(days: 2)), '2d ago');
      expect(ago(const Duration(days: 14)), '2w ago');
    });

    test('a clock skewed into the future does not print a negative', () {
      final future = DateTime.now().add(const Duration(minutes: 5));
      final n = AppNotification.tryParse(
        _row(createdAt: future.toUtc().toIso8601String()),
      )!;
      expect(n.relativeTime, 'Just now');
    });
  });

  test('unread state is read from the payload', () {
    expect(AppNotification.tryParse(_row())!.isRead, isFalse);
    expect(AppNotification.tryParse(_row(isRead: true))!.isRead, isTrue);
  });
}
