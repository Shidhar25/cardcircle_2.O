import 'package:firebase_messaging/firebase_messaging.dart';
import 'logger_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Requests permission for push notifications and returns the device registration token.
  static Future<String?> requestPermissionAndGetToken() async {
    try {
      LoggerService.info('Requesting push notification permissions...');

      // Request permission for alert, badge, and sound notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      LoggerService.info(
        'Notification authorization status: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Fetch the Firebase Messaging token for this device
        String? token = await _messaging.getToken();
        LoggerService.info(
          'FCM Registration Token retrieved successfully: $token',
        );
        return token;
      } else {
        LoggerService.warning('User declined push notification permissions.');
      }
    } catch (e, stack) {
      LoggerService.error(
        'Failed to request notification permission or fetch token',
        e,
        stack,
      );
    }
    return null;
  }
}
