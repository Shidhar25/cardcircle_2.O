import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/config/remote_config.dart';
import 'core/services/invite_link.dart';
import 'core/services/logger_service.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/session_service.dart';
import 'shared/widgets/app_snackbar.dart';
import 'features/auth/state/auth_state.dart';
import 'features/feed/state/feed_state.dart';
import 'features/circle/state/circle_state.dart';
import 'features/profile/state/category_state.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verify_otp_screen.dart';
import 'features/auth/presentation/create_profile_screen.dart';
import 'features/auth/presentation/invite_preview_screen.dart';
import 'features/feed/presentation/tabs_layout.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/profile/presentation/select_tags_screen.dart';
import 'features/profile/presentation/select_cards_screen.dart';
import 'features/feed/presentation/notifications_screen.dart';
import 'features/feed/presentation/hack_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Logger and Storage services
  LoggerService.init();
  LoggerService.info('Starting CardCircle App...');
  await LocalStorageService.init();
  await ApiService.init();
  // Server-driven copy and feature toggles. The cached payload is restored
  // before the first frame so screens never flash their defaults; the splash
  // then refreshes it from the network.
  RemoteConfig.instance.restoreCached();

  // Firebase itself is awaited — it is fast, and messaging needs it in place
  // before anything asks for a token.
  //
  // The permission prompt deliberately is NOT awaited here. On iOS it is a
  // system modal, and asking before `runApp` puts it over a black screen
  // with no app behind it to explain why; it also blocks the first frame
  // behind a round trip to Apple. It runs after the UI is up instead.
  try {
    await Firebase.initializeApp();
    LoggerService.info('Firebase initialized successfully.');

    // Must be registered before `runApp` — a background/killed-state push
    // launches a separate isolate that calls this handler directly, and
    // misses it entirely if it isn't wired up by the time that happens.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Sets up the foreground listener and the notification tap handlers.
    // Not awaited: nothing here needs to block the first frame, and a push
    // that arrives in the half-second before this resolves is not one this
    // app is going to lose sleep over.
    unawaited(NotificationService.init(onNotificationOpened: _openNotifications));
  } catch (e, stack) {
    LoggerService.error('Failed to initialize Firebase', e, stack);
  }

  // Deliberately NOT called here. Asking for push permission — and minting
  // an FCM token — before the person has even logged in put the OS prompt
  // in front of a blank login screen, and the token it got back had nowhere
  // to go: `POST /push/tokens/register` requires an access token, so it was
  // fetched and silently thrown away every cold start. Registration now
  // happens from `AuthState.saveProfile`, right after a login or signup
  // actually has an account (and an access token) to attach it to.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => FeedState()),
        ChangeNotifierProvider(create: (_) => CircleState()),
        ChangeNotifierProvider(create: (_) => CategoryState()),
      ],
      child: const CardCircleApp(),
    ),
  );
}

/// Opens the notifications list for a push the user just tapped.
///
/// Fires from outside the widget tree — the app may not have finished its
/// first frame yet if this is a cold start opened by the tap itself — so it
/// waits for one rather than assuming [appNavigatorKey] is already attached.
///
/// Deliberately generic: every push kind lands here rather than being
/// routed by type, since the list is already where a reader resolves one
/// (approves a follow request, reads what a contact join was about).
void _openNotifications(Map<String, dynamic> data) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appNavigatorKey.currentState?.pushNamed('/notifications');
  });
}

/// Navigator and messenger handles for things that happen outside the widget
/// tree — specifically an expired session, which is discovered inside an API
/// call where there is no BuildContext to route from.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The one place a sign-out — tapped by the user or forced by an expired
/// session — tears down every piece of per-account state.
///
/// Before this, only [AuthState] was cleared on logout: [FeedState],
/// [CircleState] and [CategoryState] kept whatever the previous account had
/// loaded, so signing into a different account showed that account's old
/// benefits/circle/categories until each list happened to refetch (e.g. on
/// pull-to-refresh). Clearing all four here, synchronously, before routing
/// to `/login`, means the next account starts from an empty slate and the
/// providers naturally reload for whoever is now signed in — `TabsLayout`'s
/// screens call their own `loadAll`/`loadFirstPage` on init.
///
/// The server-side logout notification in [ApiService.logout] is
/// fire-and-forget, so this never blocks on the network — the user is
/// signed out and routed to `/login` immediately.
void performLogout(BuildContext context) {
  unawaited(ApiService.logout());
  Provider.of<AuthState>(context, listen: false).logout();
  Provider.of<FeedState>(context, listen: false).clearAll();
  Provider.of<CircleState>(context, listen: false).clear();
  Provider.of<CategoryState>(context, listen: false).clear();
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
}

class CardCircleApp extends StatefulWidget {
  const CardCircleApp({super.key});

  @override
  State<CardCircleApp> createState() => _CardCircleAppState();
}

class _CardCircleAppState extends State<CardCircleApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _inviteLinkSub;

  @override
  void initState() {
    super.initState();
    // Registered once, for the life of the app: when the refresh token is
    // rejected the user is dropped back at login with an explanation,
    // wherever they happened to be.
    SessionService.onSessionExpired = _handleSessionExpired;
    _initInviteLinkListener();
  }

  /// Watches for an invite link (`cardcircle://invite/<token>` today,
  /// `https://cardcircle.com/invite/<token>` once that domain is live —
  /// see [InviteLink]) opening or resuming the app, from both states a
  /// link can arrive in:
  ///
  ///   * the app was launched fresh by tapping the link ([getInitialLink]);
  ///   * the app was already running, in background or foreground
  ///     ([uriLinkStream]).
  ///
  /// A link that isn't a recognised invite link — including every other
  /// URL this app has no reason to receive — is logged and otherwise
  /// ignored rather than crashing or routing anywhere.
  Future<void> _initInviteLinkListener() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleIncomingLink(initial);
    } catch (e, stack) {
      LoggerService.error('Failed to read the initial deep link', e, stack);
    }

    _inviteLinkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object e, StackTrace stack) {
        LoggerService.error('Deep link stream error', e, stack);
      },
    );
  }

  void _handleIncomingLink(Uri uri) {
    final token = InviteLink.tokenFrom(uri);
    if (token == null) {
      LoggerService.warning('Ignoring unrecognised deep link: $uri');
      return;
    }
    // The link can arrive before the first frame (cold start) or mid-build
    // (already running), so routing waits for the frame to settle rather
    // than risking a navigation during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamed(
        '/invite-preview',
        arguments: token,
      );
    });
  }

  @override
  void dispose() {
    _inviteLinkSub?.cancel();
    super.dispose();
  }

  void _handleSessionExpired() {
    // The 401 can land during a build or a frame callback, so the routing
    // waits for the frame to finish rather than tearing down the tree
    // mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = appNavigatorKey.currentContext;
      if (navContext == null) return;

      performLogout(navContext);
      appMessengerKey.currentState?.showError(
        'Your session expired. Please sign in again.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardCircle',
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/verify-otp': (context) => const VerifyOTPScreen(),
        '/create-profile': (context) => const CreateProfileScreen(),
        '/invite-preview': (context) => const InvitePreviewScreen(),
        '/home': (context) {
          // An int argument selects the starting tab; anything else lands
          // on Home.
          final arg = ModalRoute.of(context)?.settings.arguments;
          return TabsLayout(initialIndex: arg is int ? arg : 0);
        },
        '/edit-profile': (context) => const EditProfileScreen(),
        '/select-tags': (context) => const SelectTagsScreen(),
        '/select-cards': (context) => const SelectCardsScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/hack-detail': (context) => const HackDetailScreen(),
        // Debug-only; the Profile entry point is gated the same way.
      },
    );
  }
}
