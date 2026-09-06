import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/config/config_inspector_screen.dart';
import 'core/config/remote_config.dart';
import 'core/services/logger_service.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/state/auth_state.dart';
import 'features/feed/state/feed_state.dart';
import 'features/circle/state/circle_state.dart';
import 'features/profile/state/category_state.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verify_otp_screen.dart';
import 'features/auth/presentation/create_profile_screen.dart';
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

  // Initialize Firebase and Request Notification Permissions
  try {
    await Firebase.initializeApp();
    LoggerService.info('Firebase initialized successfully.');
    final fcmToken = await NotificationService.requestPermissionAndGetToken();
    LoggerService.info('FCM Token: $fcmToken');
  } catch (e, stack) {
    LoggerService.error(
      'Failed to initialize Firebase or notifications',
      e,
      stack,
    );
  }

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

class CardCircleApp extends StatelessWidget {
  const CardCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardCircle',
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
        ConfigInspectorScreen.routeName: (context) =>
            const ConfigInspectorScreen(),
      },
    );
  }
}
