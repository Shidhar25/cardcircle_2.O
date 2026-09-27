import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'logger_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Asks for push permission and returns the device registration token.
  ///
  /// Safe to call when Firebase failed to initialise or the user says no —
  /// it returns null rather than throwing, and push is simply absent.
  static Future<String?> registerForPush() async {
    try {
      LoggerService.info('Requesting push notification permissions...');

      final settings = await _messaging.requestPermission(
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

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) {
        LoggerService.warning('User declined push notification permissions.');
        return null;
      }

      if (!await _apnsReady()) return null;

      final token = await _messaging.getToken();
      LoggerService.info('FCM registration token retrieved: $token');
      return token;
    } catch (e, stack) {
      LoggerService.error(
        'Failed to request notification permission or fetch token',
        e,
        stack,
      );
    }
    return null;
  }

  /// Waits for iOS to hand back an APNs token, which must exist before a
  /// Firebase token can be minted.
  ///
  /// On iOS, `getToken()` throws `apns-token-not-set` when registration with
  /// Apple has not finished — and granting permission does not mean it has.
  /// The old code called `getToken()` immediately, so on a real iPhone it
  /// threw into the catch below and push silently never worked; on Android
  /// the same code was fine, which is why it looked correct.
  ///
  /// Android has no APNs, so this is a no-op there.
  static Future<bool> _apnsReady() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return true;
    }

    // Registration is a round trip to Apple. A few short retries cover it
    // without blocking anything the user is looking at.
    for (var attempt = 0; attempt < 6; attempt++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // Expected on a simulator, which has no push support at all.
    LoggerService.warning(
      'No APNs token after waiting — skipping FCM token fetch. '
      'On a device this means the Push Notifications capability or the APNs '
      'key in Firebase is missing.',
    );
    return false;
  }
}
