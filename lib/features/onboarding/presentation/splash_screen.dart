import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/remote_config.dart';
import '../../../core/services/logger_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/neo_pop_button.dart';

/// v1 screen 01 — Splash. Matches CardCircle.html's splash block: a
/// breathing gold glow, a gold→teal ring draw, a spark tracer, a single card
/// flying in, three colored dots popping in sequence, a typewriter
/// "Card"+"Circle" wordmark, a staggered tagline, and a bottom progress bar
/// — over the prototype's `splashSeconds` (4.3s) auto-advance.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _glowController;
  late final AnimationController _cursorController;

  static const Duration _totalDuration = Duration(milliseconds: 4300);

  // Timeline intervals as fractions of _totalDuration, matching the
  // prototype's animation-delay values (ringDraw 0→1.35s, cardFly .55→1.35s,
  // dotUp at 1.35/1.5/1.65s, typeW at 1.95s and 2.45s, tagline rise at
  // 3.1/3.3/3.55s).
  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.314, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _card = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.128, 0.314, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _dot1 = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.314, 0.430, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _dot2 = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.349, 0.465, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _dot3 = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.384, 0.500, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _wordCard = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.453, 0.570, curve: Curves.linear),
  );
  late final Animation<double> _wordCircle = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.570, 0.709, curve: Curves.linear),
  );
  late final Animation<double> _tag1 = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.721, 0.837, curve: Curves.easeOut),
  );
  late final Animation<double> _tag2 = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.767, 0.884, curve: Curves.easeOut),
  );
  late final Animation<double> _tag3 = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.826, 0.942, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    LoggerService.info('Initializing splash screen sequence...');

    _controller = AnimationController(vsync: this, duration: _totalDuration);
    // CSS `breathe 2.8s` is one full 0%->50%->100% cycle; a 1400ms forward +
    // 1400ms reverse repeat reproduces that 2.8s period exactly.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), _advance);
      }
    });

    _controller.forward();
  }

  Future<void> _advance() async {
    if (!mounted) return;

    // The config fetch gates the whole app, so a slow or dead backend must
    // not strand the user on the splash: refresh() already swallows network
    // errors and the app falls through to cached/default values.
    await config.refresh();

    if (!mounted) return;
    if (config.flag('maintenanceMode')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MaintenanceScreen(message: config.text('maintenanceMessage')),
        ),
      );
      return;
    }
    if (config.flag('forceUpdate')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ForceUpdateScreen()),
      );
      return;
    }

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
    _controller.dispose();
    _glowController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _controller,
            _glowController,
            _cursorController,
          ]),
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 212,
                  height: 212,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Breathing radial gold glow. CSS: 0%/100% opacity
                      // .16 scale .96, 50% opacity .34 scale 1.06.
                      Builder(
                        builder: (context) {
                          final t = Curves.easeInOut.transform(
                            _glowController.value,
                          );
                          final opacity = 0.16 + 0.18 * t;
                          final scale = 0.96 + 0.10 * t;
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 330,
                                height: 330,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    // CSS base color is rgba(gold, .5); the
                                    // outer Opacity multiplies on top of it.
                                    colors: [
                                      AppColors.gold.withValues(alpha: 0.5),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.66],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Gold -> teal ring draw + spark tracer.
                      CustomPaint(
                        size: const Size(212, 212),
                        painter: _RingPainter(progress: _ring.value),
                      ),
                      // Single card flying in.
                      if (_card.value > 0) _SplashCard(progress: _card.value),
                      // Three colored dots.
                      Positioned(
                        bottom: 58,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SplashFigure(
                              size: 36,
                              progress: _dot1.value,
                              color: _Brand.figurePurple,
                            ),
                            const SizedBox(width: 1),
                            _SplashFigure(
                              size: 56,
                              progress: _dot2.value,
                              color: _Brand.figureGold,
                            ),
                            const SizedBox(width: 1),
                            _SplashFigure(
                              size: 36,
                              progress: _dot3.value,
                              color: _Brand.figureTeal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _Wordmark(
                  cardProgress: _wordCard.value,
                  circleProgress: _wordCircle.value,
                  // CSS cursor blinks until `fade .1s 3.1s reverse forwards`
                  // hides it at 3.2s, not merely until typing finishes.
                  showCursor:
                      _controller.value < (3.2 / 4.3) &&
                      _cursorController.value > 0.5,
                ),
                const SizedBox(height: 20),
                _Tagline(p1: _tag1.value, p2: _tag2.value, p3: _tag3.value),
                const SizedBox(height: 66),
                Container(
                  width: 112,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _controller.value.clamp(0.0, 1.0),
                    child: Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.goldDark, AppColors.gold],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The EMV chip's contact divisions.
class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x99241A05)
      ..strokeWidth = 0.9;

    // Two horizontal divisions and one vertical, the layout on a real
    // module.
    for (final f in [0.33, 0.67]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        paint,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The contactless symbol: three arcs opening to the right.
class _ContactlessPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _Brand.gold;

    // Struck from a centre off the left edge so each arc reads as a slice
    // of the same set of rings.
    final centre = Offset(-size.width * 0.30, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final radius = size.width * (0.52 + i * 0.30);
      paint.strokeWidth = size.width * 0.115;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 4.6,
        math.pi / 2.3,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The four-point sparkle over the C of "Circle".
class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Concave sides: each point tapers into the centre, which is what
    // separates a sparkle from a plus sign.
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + w * 0.10, cy - h * 0.10, w, cy)
      ..quadraticBezierTo(cx + w * 0.10, cy + h * 0.10, cx, h)
      ..quadraticBezierTo(cx - w * 0.10, cy + h * 0.10, 0, cy)
      ..quadraticBezierTo(cx - w * 0.10, cy - h * 0.10, cx, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFF6DE9B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Colours sampled from the brand logo rather than guessed.
///
/// The app's own palette is gold-on-Nocturne; the mark carries a wider
/// cyan-to-purple sweep that exists nowhere else, so it is kept local to the
/// splash instead of being pushed into [AppColors] where it would invite use
/// on ordinary chrome.
class _Brand {
  const _Brand._();

  static const cyan = Color(0xFF2EE1FD);
  static const blue = Color(0xFF3B7BF6);
  static const purple = Color(0xFFA841FA);
  static const gold = Color(0xFFE8C252);
  static const goldDeep = Color(0xFFB8892E);

  /// The three figures: a smaller purple and teal flanking a gold centre.
  static const figurePurple = Color(0xFF7C3AED);
  static const figureGold = Color(0xFFCEA550);
  static const figureTeal = Color(0xFF1B93B4);

  static const silver = Color(0xFFF2F3F7);
  static const silverDim = Color(0xFFA9AEC2);
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 76.0;
    const strokeWidth = 15.0;
    // The mark is a "C": a gap at the top right, then the stroke running
    // clockwise through gold at the bottom, purple up the left, and cyan
    // across the top. Measured off the logo.
    const startAngle = -20 * math.pi / 180;
    // CSS: stroke-dasharray 478, stroke-dashoffset 478 -> 92, so only
    // (478-92)/478 of the ring's circumference is ever drawn — not a full
    // circle.
    const maxSweepFraction = 310.0 / 360.0;
    final sweep = 2 * math.pi * progress * maxSweepFraction;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          _Brand.gold,
          _Brand.gold,
          _Brand.purple,
          _Brand.blue,
          _Brand.cyan,
          _Brand.cyan,
        ],
        stops: [0.0, 0.22, 0.52, 0.70, 0.86, 1.0],
        transform: GradientRotation(-20 * math.pi / 180),
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweep, false, paint);

    if (progress < 1.0) {
      final tipAngle = startAngle + sweep;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(
        tip,
        8,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(tip, 4.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SplashCard extends StatelessWidget {
  final double progress;
  const _SplashCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    // CSS cardFly: 0% translate(-58px,-64px) rotate(-46deg) scale(.42)
    // opacity 0  ->  100% translate(0,-6px) rotate(-11deg) scale(1) opacity 1.
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    double lerp(double a, double b) => a + (b - a) * eased;
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(lerp(-58, 1), lerp(-64, -14)),
        child: Transform.rotate(
          angle: lerp(-46, -11) * math.pi / 180,
          child: Transform.scale(
            scale: lerp(0.42, 1.0),
            child: Container(
              width: 104,
              height: 66,
              padding: const EdgeInsets.fromLTRB(11, 13, 9, 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                // Near-black with a lit gold edge, as in the mark — not the
                // grey plate the prototype used.
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF23252C), Color(0xFF0C0D12)],
                  stops: [0.0, 0.78],
                ),
                border: Border.all(color: _Brand.gold.withValues(alpha: 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: 17,
                    height: 13,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_Brand.gold, _Brand.goldDeep],
                      ),
                    ),
                    // The contact grid. Without it the chip is a gold
                    // rectangle; the divisions are what make it read as a
                    // chip at this size.
                    child: CustomPaint(painter: _ChipPainter()),
                  ),
                  // Drawn rather than an icon glyph: the logo's symbol is
                  // three concentric arcs opening right, which no Material
                  // icon matches, and a font-backed icon is one more thing
                  // that can fail to load.
                  Positioned(
                    right: 1,
                    top: 1,
                    child: CustomPaint(
                      size: const Size(13, 16),
                      painter: _ContactlessPainter(),
                    ),
                  ),
                  // Deliberately no card number here — CardCircle never
                  // asks for or displays one, and the splash sets that
                  // expectation from the first screen.
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three figures inside the ring: a head above a shoulder cap.
///
/// The logo draws people, not dots. A circle alone reads as a bullet; the
/// shoulder is what makes the group legible at a glance.
class _SplashFigure extends StatelessWidget {
  final double size;
  final double progress;
  final Color color;

  const _SplashFigure({
    required this.size,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Rises and scales in, matching the logo's staggered entrance.
    final eased = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    final head = size * 0.46;
    final bodyW = size * 0.86;
    final bodyH = size * 0.54;

    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 34),
        child: Transform.scale(
          scale: 0.4 + 0.6 * eased,
          child: SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: head,
                  height: head,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.white, 0.34)!, color],
                    ),
                  ),
                ),
                SizedBox(height: size * 0.05),
                // Shoulders: a rounded cap, flat where it meets the base.
                Container(
                  width: bodyW,
                  height: bodyH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(bodyW / 2),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(color, Colors.white, 0.22)!,
                        Color.lerp(color, Colors.black, 0.22)!,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Card" in brushed silver, "Circle" in gold, with the sparkle that sits
/// over the C in the logo.
///
/// Both halves are gradient-filled rather than flat, which is what makes
/// the mark read as metal rather than as coloured text.
class _Wordmark extends StatelessWidget {
  final double cardProgress;
  final double circleProgress;
  final bool showCursor;

  const _Wordmark({
    required this.cardProgress,
    required this.circleProgress,
    required this.showCursor,
  });

  static const _size = 42.0;

  TextStyle get _style => AppText.sans(
    _size,
    weight: FontWeight.w500,
    color: Colors.white,
    letterSpacing: -1.4,
  );

  Widget _metal(String text, List<Color> colors) {
    if (text.isEmpty) return const SizedBox.shrink();
    // ShaderMask paints the gradient through the glyphs, so the fill
    // follows the letterforms instead of sitting behind them.
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: _style),
    );
  }

  @override
  Widget build(BuildContext context) {
    const first = 'Card';
    const second = 'Circle';
    final firstShown = first.substring(
      0,
      (cardProgress.clamp(0.0, 1.0) * first.length).round(),
    );
    final secondShown = second.substring(
      0,
      (circleProgress.clamp(0.0, 1.0) * second.length).round(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metal(firstShown, const [
          _Brand.silver,
          Colors.white,
          _Brand.silverDim,
        ]),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _metal(secondShown, const [
              _Brand.gold,
              Color(0xFFF6DE9B),
              _Brand.goldDeep,
            ]),
            // The four-point sparkle above the C, revealed with it.
            if (secondShown.isNotEmpty)
              Positioned(
                left: _size * 0.52,
                top: -_size * 0.06,
                child: Opacity(
                  opacity: circleProgress.clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: const Size(13, 13),
                    painter: _SparklePainter(),
                  ),
                ),
              ),
          ],
        ),
        if (showCursor)
          Container(
            width: 2,
            height: _size * 0.82,
            color: AppColors.text,
            margin: const EdgeInsets.only(left: 3, top: 4),
          ),
      ],
    );
  }
}

/// The logo's three-line tagline, with the last line split between the
/// blue-to-purple "THEY'RE IN YOUR" and the gold "FRIEND CIRCLE."
class _Tagline extends StatelessWidget {
  final double p1;
  final double p2;
  final double p3;

  const _Tagline({required this.p1, required this.p2, required this.p3});

  @override
  Widget build(BuildContext context) {
    Widget line(double p, Widget child) => Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - p.clamp(0.0, 1.0)) * 8),
        child: child,
      ),
    );

    final style = AppText.mono(
      10.5,
      ls: 2.4,
      c: AppColors.textDim,
      w: FontWeight.w500,
    );

    return Column(
      children: [
        line(p1, Text('THE BEST CREDIT CARD HACKS', style: style)),
        const SizedBox(height: 5),
        line(p2, Text("AREN'T ON BLOGS.", style: style)),
        const SizedBox(height: 5),
        line(
          p3,
          Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(
                  text: "THEY'RE IN ",
                  style: style.copyWith(color: _Brand.blue),
                ),
                TextSpan(
                  text: 'YOUR ',
                  style: style.copyWith(color: _Brand.purple),
                ),
                TextSpan(
                  text: 'FRIEND CIRCLE.',
                  style: style.copyWith(color: _Brand.gold),
                ),
              ],
            ),
          ),
        ),
      ],
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
              const Icon(Icons.construction, size: 64, color: AppColors.gold),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'System Maintenance',
                style: AppText.sans(
                  21,
                  weight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.sans(14, color: AppColors.textDim, height: 1.5),
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
                size: 64,
                color: AppColors.teal,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Update Required',
                style: AppText.sans(
                  21,
                  weight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'A new version of CardCircle is available. Please update the application to continue.',
                textAlign: TextAlign.center,
                style: AppText.sans(14, color: AppColors.textDim, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xxl),
              NeoPopButton.primary(
                onPressed: () {},
                fullWidth: false,
                depth: 6.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                child: const NeoPopButtonText(
                  'Update Now',
                  icon: Icons.update_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
