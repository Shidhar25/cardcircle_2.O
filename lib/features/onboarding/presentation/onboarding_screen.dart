import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 02 — Onboarding. Matches CardCircle.html's `isOnboard` block:
/// SKIP, a per-page illustration, kicker/title/body, dot pagination, and a
/// full-width ghost-gold Next/Get started CTA — 3 pages lifted from the
/// prototype's `OB` fixture.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _ObPage {
  final String kicker;
  final String title;
  final String body;
  const _ObPage({
    required this.kicker,
    required this.title,
    required this.body,
  });
}

const List<_ObPage> _kPages = [
  _ObPage(
    kicker: '01 · THE PROBLEM',
    title: 'Your card has\nbenefits you\nnever use',
    body:
        'Banks bury the good stuff in 40-page terms. Your circle already figured it out.',
  ),
  _ObPage(
    kicker: '02 · THE CIRCLE',
    title: 'Trust people,\nnot blog posts',
    body:
        'Follow friends and top savers. See exactly which cards they swear by and why.',
  ),
  _ObPage(
    kicker: '03 · THE PAYOFF',
    title: 'Spend the same,\nkeep more of it',
    body:
        'Match benefits to the cards you already hold, and stop leaving them on the table.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final state = Provider.of<AuthState>(context, listen: false);
    await state.markOnboarded();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _next() {
    if (_index < _kPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSkip = _index < _kPages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: canSkip
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                          ),
                          child: GestureDetector(
                            onTap: _finish,
                            child: MonoLabel(
                              'SKIP',
                              size: 10.5,
                              letterSpacing: 1.4,
                              color: AppColors.textFaint,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _kPages.length,
                  itemBuilder: (context, i) {
                    final page = _kPages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 210,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 300,
                                  height: 300,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.gold.withValues(alpha: 0.13),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.65],
                                    ),
                                  ),
                                ),
                                switch (i) {
                                  0 => const _ProblemIllustration(),
                                  1 => const _CircleIllustration(),
                                  _ => const _PayoffIllustration(),
                                },
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          MonoLabel(
                            page.kicker,
                            size: 9.5,
                            letterSpacing: 2.2,
                            color: AppColors.gold,
                            uppercase: false,
                          ),
                          const SizedBox(height: AppSpacing.mdLg),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: AppText.sans(
                              29,
                              weight: FontWeight.w500,
                              color: AppColors.text,
                              letterSpacing: -0.7,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: AppText.sans(
                              13.5,
                              color: AppColors.textDim,
                              height: 1.62,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_kPages.length, (i) {
                    final bool active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2.8),
                      height: 4,
                      width: active ? 26 : 4,
                      decoration: BoxDecoration(
                        color: active ? AppColors.gold : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    GoldButton(
                      label: _index == _kPages.length - 1
                          ? 'Get started'
                          : 'Next',
                      icon: PhosphorIconsRegular.arrowRight,
                      onTap: _next,
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    MonoLabel(
                      '0${_index + 1} / 0${_kPages.length}',
                      size: 9.5,
                      letterSpacing: 1.5,
                      color: AppColors.textGhost,
                      uppercase: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page 1 — three stacked card faces.
class _ProblemIllustration extends StatelessWidget {
  const _ProblemIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 200,
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 52,
            child: Transform.rotate(
              angle: -0.26,
              child: Container(
                width: 190,
                height: 118,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.elevated.withValues(alpha: 0.5),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ),
          Positioned(
            left: 34,
            top: 44,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 190,
                height: 118,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.border.withValues(alpha: 0.75),
                  border: Border.all(color: AppColors.textGhost),
                ),
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 32,
            child: Container(
              width: 190,
              height: 118,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B2F16), AppColors.background],
                  stops: [0.0, 0.68],
                ),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: 24,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [AppColors.goldLight, AppColors.goldDark],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(
                      '•••• 4471',
                      style: AppText.mono(
                        9,
                        ls: 2,
                        c: AppColors.text.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MonoLabel(
                      'HIDDEN 5%',
                      size: 8,
                      letterSpacing: 1.2,
                      color: AppColors.gold,
                      uppercase: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 2 — a ring of avatar dots orbiting a center card icon.
class _CircleIllustration extends StatelessWidget {
  const _CircleIllustration();

  static const _hues = [
    AvatarHue.gold,
    AvatarHue.teal,
    AvatarHue.violet,
    AvatarHue.steel,
    AvatarHue.gold,
  ];
  static const _initials = ['R', 'D', 'M', 'K', 'A'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
          ),
          ...List.generate(5, (i) {
            final angle = (i / 5) * 2 * 3.14159265 - 3.14159265 / 2;
            const r = 88.0;
            return Transform.translate(
              offset: Offset(r * math.cos(angle), r * math.sin(angle)),
              child: AvatarBubble(
                initials: _initials[i],
                size: 38,
                hue: _hues[i],
              ),
            );
          }),
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B2F16), AppColors.background],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
            ),
            child: const Icon(
              PhosphorIconsRegular.creditCard,
              size: 24,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 3 — a bar chart, coin sparkles, and a card resting behind it.
class _PayoffIllustration extends StatelessWidget {
  const _PayoffIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 200,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 24,
            child: Container(
              width: 200,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.border, AppColors.background],
                  stops: [0.0, 0.7],
                ),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(34, AppColors.border),
                const SizedBox(width: 5.6),
                _bar(52, AppColors.textGhost),
                const SizedBox(width: 5.6),
                _bar(76, AppColors.goldDark),
                const SizedBox(width: 5.6),
                Container(
                  width: 16,
                  height: 66,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.goldLight, AppColors.gold],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double heightFraction, Color color) {
    return Container(
      width: 16,
      height: heightFraction,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}
