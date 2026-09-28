import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'logger_service.dart';

/// Handles a push that arrives while the app is backgrounded or killed.
///
/// Must be a top-level (or static) function annotated exactly like this —
/// the platform calls it in a separate isolate that never ran `main()`, so
/// it cannot see anything built there. It is registered once, in `main()`,
/// before `runApp`.
///
/// The backend now sends the notification's title/body inside `data`
/// (sanitised to a flat string map — see [NotificationService]'s class
/// doc), not in a `notification` block, which is what made this silent:
/// Android and iOS only auto-display a `notification` block on their own.
/// A data-only message reaches the app with nothing shown for it unless
/// something here puts a notification up — which, until now, nothing did.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService._showLocal(message);
}

/// Push notifications: registration, and actually showing one.
///
/// FCM's own system-tray display only fires for a `notification` block, and
/// only while the app is backgrounded or killed — never in the foreground,
/// on either platform. This backend sends `data`-only messages, so none of
/// that automatic path ever applied: a push arrived, and nothing appeared,
/// in every app state. [_showLocal] is what closes that gap, fired from
/// [firebaseMessagingBackgroundHandler] and from the foreground listener
/// [init] registers.
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Channel every notification is posted on. Android requires one; the id
  /// is also declared in AndroidManifest.xml as the default, so a
  /// `notification`-block push FCM displays automatically (backgrounded)
  /// lands on the same channel rather than an unstyled "Miscellaneous" one.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cardcircle_default',
    'CardCircle',
    description: 'Follow requests, circle activity, and other updates.',
    importance: Importance.high,
  );

  /// Wires up local-notification display and tap handling. Call once, in
  /// `main()`, before `runApp` — cheap and safe to run whether or not push
  /// permission has been granted yet; nothing here requests it.
  static Future<void> init({
    required void Function(Map<String, dynamic> data) onNotificationOpened,
  }) async {
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Defaults to true, which fires iOS's permission dialog right here
        // — at `init()`, called from `main()` before the person has even
        // reached the login screen. The real ask happens later, from
        // `registerForPush()` via `FirebaseMessaging.requestPermission()`,
        // once there is an account to attach it to.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          onNotificationOpened(
            (jsonDecode(payload) as Map).cast<String, dynamic>(),
          );
        } catch (e, stack) {
          LoggerService.error('Bad notification tap payload', e, stack);
        }
      },
    );

    // A push that arrives while the app is open never goes through the OS
    // tray at all — this is the only thing standing between it and being
    // invisible in the one state most opens happen in.
    FirebaseMessaging.onMessage.listen(_showLocal);

    // The tap paths: the app was backgrounded (onMessageOpenedApp fires),
    // or was killed and this launch is the tap itself (getInitialMessage).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => onNotificationOpened(message.data),
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) onNotificationOpened(initial.data);
  }

  /// Puts [message] on screen via the local-notifications plugin.
  ///
  /// Reads the `notification` block first, in case the backend or a future
  /// message type does carry one, and falls back to `data['title']` /
  /// `data['body']` — the shape this backend actually sends.
  ///
  /// A pure function so the fallback can be pinned in a test without
  /// touching the plugin: [RemoteMessage] is a plain data class, no
  /// platform channel involved in constructing one.
  @visibleForTesting
  static (String?, String?) resolveContent(RemoteMessage message) {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body =
        message.notification?.body ?? message.data['body']?.toString();
    return (title, body);
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final (title, body) = resolveContent(message);
    // Dropped rather than shown blank: `AppNotification` already treats an
    // empty title/body as a real row once the user opens the list, so
    // there's nowhere useful for an empty banner to point.
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    try {
      await _local.show(
        // FCM's own message id collides across messages far less than a
        // counter would, and keeps a repeat push from stacking duplicate
        // banners.
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Round-tripped through the tap handler above rather than passing
        // `message.data` directly — the plugin only carries a String.
        payload: jsonEncode(message.data),
      );
    } catch (e, stack) {
      LoggerService.error('Failed to show local notification', e, stack);
    }
  }

  /// Shows a fake push locally, without any FCM/APNs round trip.
  ///
  /// Real push delivery on iOS needs an APNs key uploaded to Firebase, which
  /// in turn needs a paid Apple Developer account — neither of which exists
  /// yet for this project. Everything *downstream* of "a push arrived"
  /// (the banner, tapping it, [onNotificationOpened] routing to the right
  /// screen) is plain Dart that [_showLocal] already drives and does not
  /// depend on FCM/APNs at all, so this lets that path be verified on a
  /// real device today. Debug-only: guarded by [kDebugMode] here and at the
  /// one place that calls it ([ProfileScreen]'s settings list), so it can
  /// never appear in a release build.
  static Future<void> debugShowFakePush({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (!kDebugMode) return;
    await _showLocal(
      RemoteMessage(
        messageId: 'debug-${DateTime.now().millisecondsSinceEpoch}',
        data: {'title': title, 'body': body, ...data},
      ),
    );
  }

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
