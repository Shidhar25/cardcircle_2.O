import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/mascot_character.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mascotController;
  late Animation<double> _mascotY;
  late Animation<double> _mascotOpacity;

  late AnimationController _logoController;
  late Animation<double> _logoOpacity;

  late AnimationController _taglineController;
  late Animation<double> _taglineOpacity;

  late AnimationController _screenController;
  late Animation<double> _screenOpacity;

  @override
  void initState() {
    super.initState();
    LoggerService.info('Initializing splash screen sequence...');

    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mascotY = Tween<double>(begin: 120.0, end: 0.0).animate(
      CurvedAnimation(parent: _mascotController, curve: Curves.easeOutBack),
    );
    _mascotOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mascotController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_logoController);

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineOpacity =
        Tween<double>(begin: 0.0, end: 1.0).animate(_taglineController);

    _screenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _screenOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(_screenController);

    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _mascotController.forward();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _taglineController.forward();

    // Call bootstrap config API
    final config = await ApiService.getBootstrapConfig();

    if (config != null) {
      final bool maintenanceMode = config['maintenanceMode'] ?? false;
      final bool forceUpdate = config['forceUpdate'] ?? false;

      if (maintenanceMode) {
        final message = config['maintenanceMessage'] ??
            'We are currently under maintenance. Please try again later.';
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MaintenanceScreen(message: message),
            ),
          );
        }
        return;
      }

      if (forceUpdate) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ForceUpdateScreen(),
            ),
          );
        }
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _screenController.forward();

    if (!mounted) return;
    final state = Provider.of<AuthState>(context, listen: false);
    if (!state.hasOnboarded) {
      LoggerService.info('Redirecting to onboarding.');
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (!state.hasProfile) {
      LoggerService.info('Redirecting to login.');
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      LoggerService.info('Redirecting to home.');
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _mascotController.dispose();
    _logoController.dispose();
    _taglineController.dispose();
    _screenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;
    const int numCols = 14;
    final double colWidth = sw / numCols;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _screenOpacity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(numCols, (index) {
              return Positioned(
                left: index * colWidth + colWidth * 0.15,
                top: 0,
                bottom: 0,
                child: RainColumn(
                  index: index,
                  screenHeight: sh,
                ),
              );
            }),
            Positioned(
              top: sh * 0.15,
              child: Container(
                width: sw * 1.2,
                height: sh * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D4FF).withValues(alpha: 0.09),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _mascotController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _mascotY.value),
                      child: Opacity(
                        opacity: _mascotOpacity.value,
                        child: const MascotCharacter(
                          size: 160,
                          mood: 'happy',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: const [
                          Text(
                            'Card',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            'Circle',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _taglineController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _taglineOpacity.value,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          "India's smartest card community",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.mutedForeground,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 3,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x2200D4FF),
                      Color(0x188B5CF6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RainColumn extends StatefulWidget {
  final int index;
  final double screenHeight;

  const RainColumn({
    super.key,
    required this.index,
    required this.screenHeight,
  });

  @override
  State<RainColumn> createState() => _RainColumnState();
}

class _RainColumnState extends State<RainColumn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late List<String> _chars;

  static final List<String> rainChars = [
    '₹', '4', '8', '1', '6', '*', '•', '\$', '0', '9', '5', '2',
    'N', 'U', 'L', 'L', '%', '>', '=', '#', '∞', '↑', '✓',
  ];

  @override
  void initState() {
    super.initState();
    final random = math.Random();

    final charCount = (widget.screenHeight / 22.0).ceil() + 2;
    _chars = List.generate(
      charCount,
      (_) => rainChars[random.nextInt(rainChars.length)],
    );

    final int speed = 1200 + (widget.index % 5) * 240;
    final int delay = widget.index * 80;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: speed),
    );

    _translateY = Tween<double>(
      begin: -widget.screenHeight * 0.6,
      end: widget.screenHeight * 0.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    final double fadeInDurationRatio = 300 / (speed + delay);
    final double fadeOutDurationRatio = 400 / (speed + delay);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.55),
        weight: fadeInDurationRatio * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.55),
        weight: (1.0 - fadeInDurationRatio - fadeOutDurationRatio) * 100,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.55, end: 0.0),
        weight: fadeOutDurationRatio * 100,
      ),
    ]).animate(_controller);

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Opacity(
            opacity: _opacity.value,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_chars.length, (i) {
                final isLast = i == _chars.length - 1;
                final isNearLast = i > _chars.length - 4;
                Color charColor = const Color(0x5500D4FF);
                if (isLast) {
                  charColor = Colors.white;
                } else if (isNearLast) {
                  charColor = const Color(0xFF00D4FF);
                }

                return SizedBox(
                  height: 22,
                  child: Text(
                    _chars[i],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: (13 + (widget.index % 3)).toDouble(),
                      color: charColor,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        );
      },
    );
  }
}

class MaintenanceScreen extends StatelessWidget {
  final String message;
  const MaintenanceScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction,
                size: 80,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(height: 24),
              const Text(
                'System Maintenance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_alt,
                size: 80,
                color: Color(0xFF00D4FF),
              ),
              const SizedBox(height: 24),
              const Text(
                'Update Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A new version of CardCircle is available. Please update the application to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Mocks opening play store/app store link
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Update Now',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
