import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/services/notification_service.dart';

RemoteMessage _message({RemoteNotification? notification, Map<String, dynamic> data = const {}}) =>
    RemoteMessage(notification: notification, data: data);

void main() {
  group('resolving what a push actually says', () {
    // The backend sends data-only messages — title/body live in `data`,
    // not in a `notification` block. Nothing auto-displays a data-only
    // message on either platform, in any app state, which is the whole
    // reason NotificationService has to show one itself.
    test('falls back to data.title / data.body', () {
      final (title, body) = NotificationService.resolveContent(
        _message(data: {'title': 'New follower', 'body': 'rahul_k followed you'}),
      );
      expect(title, 'New follower');
      expect(body, 'rahul_k followed you');
    });

    test('a notification block, if one ever arrives, wins', () {
      final (title, body) = NotificationService.resolveContent(
        _message(
          notification: const RemoteNotification(
            title: 'From the notification block',
            body: 'Also from it',
          ),
          data: {'title': 'From data', 'body': 'Also from data'},
        ),
      );
      expect(title, 'From the notification block');
      expect(body, 'Also from it');
    });

    test('a message with neither resolves to nothing', () {
      final (title, body) = NotificationService.resolveContent(_message());
      expect(title, isNull);
      expect(body, isNull);
    });

    test('a non-string data value does not throw', () {
      // The sanitizer on the backend is meant to prevent this, but a
      // malformed payload should degrade, not crash the handler.
      final (title, body) = NotificationService.resolveContent(
        _message(data: {'title': 42, 'body': true}),
      );
      expect(title, '42');
      expect(body, 'true');
    });
  });
}
