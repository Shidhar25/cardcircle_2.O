import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/logger_service.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/api_service.dart';
import 'features/auth/state/auth_state.dart';
import 'features/feed/state/feed_state.dart';
import 'features/circle/state/circle_state.dart';
import 'features/challenges/state/challenges_state.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verify_otp_screen.dart';
import 'features/auth/presentation/create_profile_screen.dart';
import 'features/feed/presentation/tabs_layout.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/profile/presentation/select_tags_screen.dart';
import 'features/profile/presentation/select_cards_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Logger and Storage services
  LoggerService.init();
  LoggerService.info('Starting CardCircle App...');
  await LocalStorageService.init();
  await ApiService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => FeedState()),
        ChangeNotifierProvider(create: (_) => CircleState()),
        ChangeNotifierProxyProvider<AuthState, ChallengesState>(
          create: (_) => ChallengesState(),
          update: (_, authState, challengesState) =>
              (challengesState ?? ChallengesState())..updateAuth(authState),
        ),
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
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.purple,
          surface: AppColors.card,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/verify-otp': (context) => const VerifyOTPScreen(),
        '/create-profile': (context) => const CreateProfileScreen(),
        '/home': (context) => const TabsLayout(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/select-tags': (context) => const SelectTagsScreen(),
        '/select-cards': (context) => const SelectCardsScreen(),
      },
    );
  }
}
