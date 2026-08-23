import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/mascot_character.dart';
import '../../../shared/widgets/neo_pop_button.dart';
import '../../../shared/widgets/gritty_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class SlideData {
  final String title;
  final String subtitle;
  final String mood;
  final Color glowColor;
  final String speechBubble;

  SlideData({
    required this.title,
    required this.subtitle,
    required this.mood,
    required this.glowColor,
    required this.speechBubble,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<SlideData> _slides = [
    SlideData(
      title: 'Discover hidden\ncashback hacks',
      subtitle:
          'Community-powered secrets your bank never told you. Unlock ₹50,000+ in hidden savings.',
      mood: 'thinking',
      glowColor: AppColors.secondary,
      speechBubble: 'Did you know your card has secret benefits? 🤫',
    ),
    SlideData(
      title: 'Build your\nCard Circle',
      subtitle:
          'See which cards your friends swear by. Trust-driven card discovery through your social network.',
      mood: 'happy',
      glowColor: AppColors.primary,
      speechBubble: 'Your friends saved ₹32K last month! 🎉',
    ),
    SlideData(
      title: 'Earn while\nyou spend',
      subtitle:
          'Complete challenges, climb the leaderboard, and win exclusive rewards every month.',
      mood: 'celebrate',
      glowColor: AppColors.purple,
      speechBubble: 'Level up to unlock premium hacks! ⭐',
    ),
  ];

  void _handleNext() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleGetStarted() async {
    final state = Provider.of<AuthState>(context, listen: false);
    await state.markOnboarded();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _handleSkip() async {
    final state = Provider.of<AuthState>(context, listen: false);
    await state.markOnboarded();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final SlideData currentSlide = _slides[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _currentIndex < _slides.length - 1
                    ? TextButton(
                        onPressed: _handleSkip,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(height: 48),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() {
                      _currentIndex = idx;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 40,
                            child: Container(
                              width: 340,
                              height: 340,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    slide.glowColor.withValues(alpha: 0.12),
                                    slide.glowColor.withValues(alpha: 0.02),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MascotCharacter(
                                size: 200,
                                mood: slide.mood,
                              ),
                              const SizedBox(height: 10),
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(maxWidth: sw * 0.72),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 10.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: slide.glowColor.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: slide.glowColor.withValues(alpha: 0.31),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      slide.speechBubble.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: slide.glowColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -9,
                                    child: CustomPaint(
                                      size: const Size(16, 10),
                                      painter: SpeechBubbleTailPainter(
                                        color: slide.glowColor.withValues(alpha: 0.31),
                                        fillColor: slide.glowColor.withValues(alpha: 0.07),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              Text(
                                slide.title.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 32,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                slide.subtitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.mutedForeground,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final bool isActive = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    height: 7,
                    width: isActive ? 28 : 7,
                    decoration: BoxDecoration(
                      color: isActive ? currentSlide.glowColor : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _currentIndex == _slides.length - 1
                    ? NeoPopButton.primary(
                        onPressed: _handleGetStarted,
                        depth: 7.0,
                        child: const NeoPopButtonText(
                          'Get Started',
                          icon: Icons.arrow_forward_rounded,
                        ),
                      )
                    : GestureDetector(
                        onTap: _handleNext,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: currentSlide.glowColor,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: currentSlide.glowColor,
                            size: 28,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 24.0),
                child: Text(
                  '${_currentIndex + 1} of ${_slides.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeechBubbleTailPainter extends CustomPainter {
  final Color color;
  final Color fillColor;

  SpeechBubbleTailPainter({
    required this.color,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    final Path borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
