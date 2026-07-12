import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/neo_pop_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  late AnimationController _cursorController;

  late Animation<double> _ringProgress;
  late Animation<double> _cardProgress;
  late Animation<double> _person1Progress;
  late Animation<double> _person2Progress;
  late Animation<double> _person3Progress;
  late Animation<double> _wordmarkProgress;
  late Animation<double> _taglineProgress;

  static const Duration _totalDuration = Duration(milliseconds: 4200);

  @override
  void initState() {
    super.initState();
    LoggerService.info('Initializing splash screen sequence...');

    _controller = AnimationController(vsync: this, duration: _totalDuration);

    _ringProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.34, curve: Curves.easeOutCubic),
    );

    _cardProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.24, 0.48, curve: Curves.easeOutCubic),
    );

    _person1Progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.58, curve: Curves.easeOutCubic),
    );
    _person2Progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.47, 0.63, curve: Curves.easeOutCubic),
    );
    _person3Progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 0.68, curve: Curves.easeOutCubic),
    );

    _wordmarkProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 0.83, curve: Curves.linear),
    );

    _taglineProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 1.0, curve: Curves.linear),
    );

    // Slow independent breathing glow behind the whole logo, runs forever.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Blinking typewriter cursor, runs forever, only rendered while typing.
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Attach listener BEFORE starting the animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;

          try {
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
          } catch (e) {
            LoggerService.error('Bootstrap API failed during splash: $e');
            // Continue routing even if bootstrap fails to avoid app hanging
          }

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
        });
      }
    });

    // Start the animation
    _controller.forward();
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
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_controller, _glowController]),
                builder: (context, _) {
                  final double glow = 0.15 + (_glowController.value * 0.15);
                  return SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: _LogoPainter(
                        ringProgress: _ringProgress.value,
                        cardProgress: _cardProgress.value,
                        person1Progress: _person1Progress.value,
                        person2Progress: _person2Progress.value,
                        person3Progress: _person3Progress.value,
                        glowOpacity: glow,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: Listenable.merge([_wordmarkProgress, _cursorController]),
                builder: (context, _) {
                  return _TypewriterWordmark(
                    progress: _wordmarkProgress.value,
                    showCursor: _wordmarkProgress.value < 1.0 &&
                        _cursorController.value > 0.5,
                  );
                },
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: Listenable.merge([_taglineProgress, _cursorController]),
                builder: (context, _) {
                  return _TypewriterTagline(
                    progress: _taglineProgress.value,
                    showCursor: _taglineProgress.value < 1.0 &&
                        _cursorController.value > 0.5,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double ringProgress;
  final double cardProgress;
  final double person1Progress;
  final double person2Progress;
  final double person3Progress;
  final double glowOpacity;

  _LogoPainter({
    required this.ringProgress,
    required this.cardProgress,
    required this.person1Progress,
    required this.person2Progress,
    required this.person3Progress,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double ringRadius = size.width * 0.44;

    // Soft ambient glow
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF6C4CE0).withValues(alpha: glowOpacity), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius * 1.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, ringRadius * 1.5, glowPaint);

    // ---- Exact C-Ring Formation ----
    // Starts top-right (~63 degrees), sweeps counter-clockwise to bottom-right (~40 degrees)
    final double startAngle = -1.1;
    final double totalSweep = -4.5;

    if (ringProgress > 0) {
      final double sweep = totalSweep * ringProgress;
      final double strokeW = size.width * 0.085;

      final Rect ringRect = Rect.fromCircle(center: center, radius: ringRadius);
      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          center: Alignment.center,
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [
            Color(0xFFE8B84B), // 0.0 - Gold fallback
            Color(0xFFE8B84B), // 0.10 - Gold (Bottom Right)
            Color(0xFF9B51E0), // 0.35 - Magenta/Purple (Bottom Left)
            Color(0xFF3A2A8C), // 0.50 - Deep Purple (Left)
            Color(0xFF34C6F4), // 0.65 - Blue (Top Left)
            Color(0xFF00E5FF), // 0.85 - Cyan (Top Right)
            Color(0xFF00E5FF), // 1.0 - Cyan fallback
          ],
          stops: [0.0, 0.10, 0.35, 0.50, 0.65, 0.85, 1.0],
        ).createShader(ringRect);

      canvas.drawArc(ringRect, startAngle, sweep, false, ringPaint);

      // Tracer Spark
      if (ringProgress < 1.0) {
        final double tipAngle = startAngle + sweep;
        final Offset tip = Offset(
          center.dx + ringRadius * math.cos(tipAngle),
          center.dy + ringRadius * math.sin(tipAngle),
        );
        final Paint tracerGlow = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(tip, strokeW * 0.55, tracerGlow);
        canvas.drawCircle(tip, strokeW * 0.3, Paint()..color = Colors.white);
      }
    }

    // ---- Matte 3D Card ----
    if (cardProgress > 0) {
      final Offset finalPos = Offset(center.dx + size.width * 0.01, center.dy - size.height * 0.05);
      final Offset startPos = finalPos + Offset(-size.width * 0.75, -size.height * 0.75);
      final Offset pos = Offset.lerp(startPos, finalPos, cardProgress)!;
      final double scale = 0.4 + (0.6 * cardProgress);
      final double rotation = (-45 + (33 * cardProgress)) * math.pi / 180; // Settles at -12deg
      final double opacity = cardProgress.clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      canvas.scale(scale);

      final Rect cardRect = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.64,
        height: size.height * 0.42,
      );
      final RRect cardRRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(16));

      // 3D Metallic Card Gradient
      canvas.drawRRect(
        cardRRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF383838).withValues(alpha: opacity),
              const Color(0xFF111111).withValues(alpha: opacity),
            ],
          ).createShader(cardRect),
      );

      // Golden Edge/Border
      canvas.drawRRect(
        cardRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFE8B84B).withValues(alpha: 0.8 * opacity),
      );

      // EMV Chip
      final Rect chipRect = Rect.fromLTWH(
        cardRect.left + 24,
        cardRect.top + 24,
        cardRect.width * 0.15,
        cardRect.height * 0.26,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, const Radius.circular(4)),
        Paint()..color = const Color(0xFFE8B84B).withValues(alpha: opacity),
      );
      final Paint chipLine = Paint()
        ..color = const Color(0xFF111111).withValues(alpha: 0.6 * opacity)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(chipRect.left, chipRect.center.dy), Offset(chipRect.right, chipRect.center.dy), chipLine);
      canvas.drawLine(Offset(chipRect.center.dx, chipRect.top), Offset(chipRect.center.dx, chipRect.bottom), chipLine);

      // Contactless Waves
      final Paint wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE8B84B).withValues(alpha: opacity);
      final Offset waveOrigin = Offset(cardRect.right - 28, cardRect.top + 34);
      for (int i = 0; i < 3; i++) {
        final double r = 6.0 + i * 6.5;
        canvas.drawArc(Rect.fromCircle(center: waveOrigin, radius: r), -0.7, 1.4, false, wavePaint);
      }

      canvas.restore();
    }

    // ---- 3D Avatars ----
    final Offset avatarBase = Offset(center.dx - size.width * 0.02, center.dy + size.height * 0.16);

    // Left (Purple)
    _drawFlyingAvatar(
      canvas,
      finalPos: avatarBase + Offset(-size.width * 0.17, -size.height * 0.03),
      startOffset: Offset(-size.width * 0.9, size.height * 0.1),
      radius: size.width * 0.08,
      colors: [const Color(0xFF9B51E0), const Color(0xFF3A2A8C)],
      progress: person1Progress,
    );
    // Right (Cyan)
    _drawFlyingAvatar(
      canvas,
      finalPos: avatarBase + Offset(size.width * 0.17, -size.height * 0.03),
      startOffset: Offset(size.width * 0.9, size.height * 0.1),
      radius: size.width * 0.08,
      colors: [const Color(0xFF00E5FF), const Color(0xFF007788)],
      progress: person3Progress,
    );
    // Center (Gold)
    _drawFlyingAvatar(
      canvas,
      finalPos: avatarBase + Offset(0, size.height * 0.02),
      startOffset: Offset(0, size.height * 0.85),
      radius: size.width * 0.11,
      colors: [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      progress: person2Progress,
    );
  }

  void _drawFlyingAvatar(
      Canvas canvas, {
        required Offset finalPos,
        required Offset startOffset,
        required double radius,
        required List<Color> colors,
        required double progress,
      }) {
    if (progress <= 0) return;
    final Offset startPos = finalPos + startOffset;
    final Offset pos = Offset.lerp(startPos, finalPos, progress)!;
    final double scale = 0.3 + (0.7 * progress.clamp(0.0, 1.0));
    final double rotation = (1 - progress) * 25 * math.pi / 180;
    final double opacity = progress.clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);

    final Color c1 = colors[0].withValues(alpha: opacity);
    final Color c2 = colors[1].withValues(alpha: opacity);

    // 3D Spherical Head
    final Rect headRect = Rect.fromCircle(center: Offset(0, -radius * 0.55), radius: radius * 0.55);
    final Paint headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [c1, c2],
      ).createShader(headRect);
    canvas.drawCircle(headRect.center, headRect.width / 2, headPaint);

    // 3D Body
    final Rect bodyRect = Rect.fromCenter(center: Offset(0, radius * 0.55), width: radius * 1.8, height: radius * 1.3);
    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.6),
        radius: 1.2,
        colors: [c1, c2],
      ).createShader(bodyRect);

    canvas.drawRRect(
      RRect.fromRectAndCorners(bodyRect, topLeft: Radius.circular(radius), topRight: Radius.circular(radius)),
      bodyPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => true;
}

class _TypewriterWordmark extends StatelessWidget {
  final double progress;
  final bool showCursor;

  const _TypewriterWordmark({required this.progress, required this.showCursor});

  static const String _first = 'Card';
  static const String _second = 'Circle';

  @override
  Widget build(BuildContext context) {
    final int totalChars = _first.length + _second.length;
    final int shown = (progress * totalChars).floor().clamp(0, totalChars);

    final String firstShown = _first.substring(0, math.min(shown, _first.length));
    final int secondCount = (shown - _first.length).clamp(0, _second.length);
    final String secondShown = _second.substring(0, secondCount);

    const TextStyle style = TextStyle(
      fontSize: 46,
      fontFamily: 'Montserrat', // Uses geometric sans if available
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: -0.5,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD0D0D0), Color(0xFF9A9A9A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(firstShown, style: style),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFE7B0), Color(0xFFE8B84B), Color(0xFF9A6A10)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(secondShown, style: style),
        ),
        if (showCursor)
          Container(width: 3, height: 42, color: Colors.white, margin: const EdgeInsets.only(left: 4)),
      ],
    );
  }
}

class _TypewriterTagline extends StatelessWidget {
  final double progress;
  final bool showCursor;

  const _TypewriterTagline({required this.progress, required this.showCursor});

  static const String _line1 = "THE BEST CREDIT CARD HACKS";
  static const String _line2 = "AREN'T ON BLOGS.";
  static const List<_Seg> _line3 = [
    _Seg("THEY'RE IN ", Color(0xFF34C6F4)), // Blue
    _Seg("YOUR ", Color(0xFF9B51E0)),       // Purple
    _Seg("FRIEND CIRCLE.", Color(0xFFE8B84B)), // Gold
  ];

  double _lineProgress(int index) {
    const double slice = 1 / 3;
    final double p = (progress - (slice * index)) / slice;
    return p.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    const TextStyle base = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.5,
      color: Color(0xFFE0E0E0), // Brighter white/grey
    );

    final double p1 = _lineProgress(0);
    final double p2 = _lineProgress(1);
    final double p3 = _lineProgress(2);

    final String shown1 = _line1.substring(0, (p1 * _line1.length).floor());
    final String shown2 = _line2.substring(0, (p2 * _line2.length).floor());

    return Column(
      children: [
        Text(shown1, style: base, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(shown2, style: base, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(style: base, children: _buildRevealedSpans(_line3, p3)),
        ),
        if (showCursor)
          Container(width: 2, height: 12, color: Colors.white, margin: const EdgeInsets.only(top: 4)),
      ],
    );
  }

  List<TextSpan> _buildRevealedSpans(List<_Seg> segments, double lineProgress) {
    final int totalChars = segments.fold(0, (sum, s) => sum + s.text.length);
    int remaining = (lineProgress * totalChars).floor();
    final List<TextSpan> spans = [];
    for (final seg in segments) {
      if (remaining <= 0) break;
      final int take = math.min(remaining, seg.text.length);
      spans.add(TextSpan(text: seg.text.substring(0, take), style: TextStyle(color: seg.color)));
      remaining -= take;
    }
    return spans;
  }
}

class _Seg {
  final String text;
  final Color color;
  const _Seg(this.text, this.color);
}

// ... Keep your MaintenanceScreen and ForceUpdateScreen classes identical here
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
              NeoPopButton.primary(
                onPressed: () {
                  // Mocks opening play store/app store link
                },
                fullWidth: false,
                depth: 6.0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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