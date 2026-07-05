import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MascotCharacter extends StatefulWidget {
  final double size;
  final String mood; // 'idle' | 'happy' | 'celebrate' | 'thinking'

  const MascotCharacter({
    super.key,
    this.size = 180,
    this.mood = 'idle',
  });

  @override
  State<MascotCharacter> createState() => _CardCircleMascotState();
}

class _CardCircleMascotState extends State<MascotCharacter>
    with TickerProviderStateMixin {
  late AnimationController _bobController;
  late AnimationController _swayController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  late Animation<double> _bobAnimation;
  late Animation<double> _swayAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  bool _blink = false;
  Timer? _blinkTimer;
  Timer? _blinkSubTimer;

  @override
  void initState() {
    super.initState();

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _bobAnimation = Tween<double>(begin: 0.0, end: -10.0).animate(
      CurvedAnimation(parent: _bobController, curve: Curves.easeInOutSine),
    );
    _bobController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bobController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _bobController.forward();
      }
    });
    _bobController.forward();

    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _swayAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOutSine),
    );
    _swayController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _swayController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _swayController.forward();
      }
    });
    _swayController.forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.linear),
    );

    // Slow diagonal holographic sheen sweeping across the card body —
    // this is what sells the "premium metal card" feel.
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -0.4, end: 1.4).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _scheduleBlink();

    if (widget.mood == 'celebrate' || widget.mood == 'happy') {
      _runPulse();
    }
  }

  @override
  void didUpdateWidget(covariant MascotCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood != oldWidget.mood &&
        (widget.mood == 'celebrate' || widget.mood == 'happy')) {
      _runPulse();
    }
  }

  void _runPulse() {
    _scaleController.forward().then((_) {
      _scaleController.reverse().then((_) {
        _scaleController.forward().then((_) {
          _scaleController.reverse().then((_) {
            _scaleController.forward().then((_) {
              _scaleController.reverse();
            });
          });
        });
      });
    });
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final delay = 2500 + math.Random().nextInt(2500);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {
        _blink = true;
      });
      _blinkSubTimer?.cancel();
      _blinkSubTimer = Timer(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        setState(() {
          _blink = false;
        });
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _bobController.dispose();
    _swayController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    _blinkTimer?.cancel();
    _blinkSubTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double W = widget.size;
    final double H = widget.size * 1.2;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_bobAnimation, _swayAnimation, _scaleAnimation, _shimmerAnimation]),
      builder: (context, child) {
        final double bobY = _bobAnimation.value;
        final double swayAngle = _swayAnimation.value * (4.0 * math.pi / 180.0);
        final double scale = _scaleAnimation.value;

        return Transform.translate(
          offset: Offset(0, bobY),
          child: Transform.rotate(
            angle: swayAngle,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: W,
                height: H,
                child: CustomPaint(
                  painter: CardCirclePainter(
                    mood: widget.mood,
                    blink: _blink,
                    shimmerT: _shimmerAnimation.value,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circo — the CardCircle mascot.
/// A premium, card-shaped character: rounded metal card body with a
/// holographic sheen, EMV-style chip, contactless signal, and simple
/// dot-eyed face. Designed to read as "a trusted friend who is great
/// with money", not a cartoon animal.
class CardCirclePainter extends CustomPainter {
  final String mood;
  final bool blink;
  final double shimmerT; // 0..1 sweep progress for the holographic sheen

  CardCirclePainter({
    required this.mood,
    required this.blink,
    this.shimmerT = 0.0,
  });

  static const Color violet = Color(0xFF6C5CE7);
  static const Color mint = Color(0xFF00E0A4);
  static const Color amberGold = Color(0xFFFFB020);
  static const Color ink = Color(0xFF0B0D12);
  static const Color platinum = Color(0xFFE7EAF0);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 200.0;
    final double scaleY = size.height / 240.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // ---- 1. Community ring backdrop (the "Circle") ----
    final Paint circleRingPaint = Paint()
      ..color = mint.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(const Offset(100, 118), 92, circleRingPaint);

    final Paint dashedRingPaint = Paint()
      ..color = violet.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    _drawDashedCircle(canvas, const Offset(100, 118), 82, dashedRingPaint);

    // ---- 2. Soft ambient glow behind the card body (premium halo) ----
    final Rect glowRect = const Rect.fromLTWH(28, 46, 144, 110);
    final Paint haloPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [violet.withValues(alpha: 0.35), mint.withValues(alpha: 0.25)],
      ).createShader(glowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, const Radius.circular(30)),
      haloPaint,
    );

    // ---- 3. Card body (the mascot's whole "self") ----
    final Rect cardRect = const Rect.fromLTWH(40, 62, 120, 76);
    final RRect cardRRect =
    RRect.fromRectAndRadius(cardRect, const Radius.circular(18));

    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [violet, mint],
      ).createShader(cardRect);
    canvas.drawRRect(cardRRect, bodyPaint);

    // Metallic edge stroke for a "premium metal card" finish.
    final Paint edgeStrokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [platinum, Colors.white],
      ).createShader(cardRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawRRect(cardRRect, edgeStrokePaint);

    // Holographic sheen sweeping diagonally across the card body.
    canvas.save();
    canvas.clipRRect(cardRRect);
    final double sweepX = 40 + (shimmerT * 160);
    final Rect sheenRect = Rect.fromLTWH(sweepX - 26, 50, 30, 110);
    final Paint sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(sheenRect);
    canvas.save();
    canvas.translate(sheenRect.center.dx, sheenRect.center.dy);
    canvas.rotate(-18 * math.pi / 180.0);
    canvas.translate(-sheenRect.center.dx, -sheenRect.center.dy);
    canvas.drawRect(sheenRect, sheenPaint);
    canvas.restore();
    canvas.restore();

    // ---- 4. EMV chip (bottom-left) — a nod to a real card, not a face ----
    final Rect chipRect = const Rect.fromLTWH(54, 116, 20, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          colors: [amberGold, Color(0xFFB8860B)],
        ).createShader(chipRect),
    );
    final Paint chipLinePaint = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(54, 123), const Offset(74, 123), chipLinePaint);
    canvas.drawLine(const Offset(61, 116), const Offset(61, 130), chipLinePaint);

    // ---- 5. Contactless signal (right edge) — signature "wave" detail ----
    final Paint wavePaint = Paint()
      ..color = platinum.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(146, 100)
        ..quadraticBezierTo(154, 92, 146, 84),
      wavePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(150, 104)
        ..quadraticBezierTo(162, 92, 150, 80),
      wavePaint..color = platinum.withValues(alpha: 0.55),
    );

    // ---- 6. Face: simple dot eyes + curved mouth on the card front ----
    final double eyeTiltThinking = mood == 'thinking' ? -4.0 : 0.0;

    if (blink) {
      final Paint closedEyePaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()..moveTo(74, 92)..quadraticBezierTo(83, 87, 92, 92),
        closedEyePaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(108, 92 + eyeTiltThinking)
          ..quadraticBezierTo(117, 87 + eyeTiltThinking, 126, 92 + eyeTiltThinking),
        closedEyePaint,
      );
    } else {
      final Paint eyePaint = Paint()..color = ink;
      canvas.drawCircle(const Offset(83, 92), 6.5, eyePaint);
      canvas.drawCircle(
          Offset(117, 92 + eyeTiltThinking), 6.5, eyePaint);

      // tiny highlight dot for a bit of life/premium polish
      canvas.drawCircle(
          const Offset(85, 89.5), 1.6, Paint()..color = Colors.white.withValues(alpha: 0.8));
      canvas.drawCircle(
          Offset(119, 89.5 + eyeTiltThinking), 1.6, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }

    final Paint mouthPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    if (mood == 'happy' || mood == 'celebrate') {
      canvas.drawPath(
        Path()..moveTo(83, 106)..quadraticBezierTo(100, 116, 117, 106),
        mouthPaint,
      );
    } else if (mood == 'thinking') {
      canvas.drawPath(
        Path()..moveTo(88, 108)..quadraticBezierTo(100, 104, 112, 108),
        mouthPaint,
      );
      // "..." thinking bubble
      final Paint dotPaint = Paint()..color = ink.withValues(alpha: 0.7);
      canvas.drawCircle(const Offset(150, 56), 2.2, dotPaint);
      canvas.drawCircle(const Offset(158, 50), 2.6, dotPaint);
      canvas.drawCircle(const Offset(167, 43), 3.0, dotPaint);
    } else {
      canvas.drawPath(
        Path()..moveTo(88, 107)..quadraticBezierTo(100, 111, 112, 107),
        mouthPaint,
      );
    }

    // ---- 7. Stub arms ----
    final Paint limbPaint = Paint()
      ..shader = const LinearGradient(
        colors: [violet, mint],
      ).createShader(const Rect.fromLTWH(20, 90, 160, 30));

    // Left arm
    canvas.save();
    canvas.translate(40, 96);
    final double leftArmAngle = mood == 'celebrate' ? -150.0 : -20.0;
    canvas.rotate(leftArmAngle * math.pi / 180.0);
    canvas.translate(-40, -96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(31, 92, 9, 30), const Radius.circular(5)),
      limbPaint,
    );
    canvas.restore();

    // Right arm — waves for 'happy', throws up for 'celebrate'
    canvas.save();
    canvas.translate(160, 96);
    double rightArmAngle;
    if (mood == 'celebrate') {
      rightArmAngle = 150.0;
    } else if (mood == 'happy') {
      rightArmAngle = 55.0;
    } else {
      rightArmAngle = 20.0;
    }
    canvas.rotate(rightArmAngle * math.pi / 180.0);
    canvas.translate(-160, -96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(160, 92, 9, 30), const Radius.circular(5)),
      limbPaint,
    );
    canvas.restore();

    // ---- 8. Stub legs ----
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(75, 136, 9, 22), const Radius.circular(5)),
      limbPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(116, 136, 9, 22), const Radius.circular(5)),
      limbPaint,
    );

    // Little feet
    final Paint footPaint = Paint()..color = amberGold.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(70, 156, 18, 10), const Radius.circular(5)),
      footPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(111, 156, 18, 10), const Radius.circular(5)),
      footPaint,
    );

    // ---- 9. Social network nodes on celebrate — "the circle cheering" ----
    if (mood == 'celebrate') {
      _drawNetworkNode(canvas, const Offset(24, 66), const Offset(58, 84), mint);
      _drawNetworkNode(canvas, const Offset(176, 58), const Offset(142, 76), amberGold);
      _drawNetworkNode(canvas, const Offset(18, 128), const Offset(52, 130), violet);
      _drawNetworkNode(canvas, const Offset(182, 132), const Offset(148, 130), mint);

      // confetti flecks
      final List<Color> confettiColors = [violet, mint, amberGold];
      final math.Random rnd = math.Random(7);
      for (int i = 0; i < 8; i++) {
        final double x = 40 + rnd.nextDouble() * 120;
        final double y = 30 + rnd.nextDouble() * 30;
        final Paint fleckPaint = Paint()..color = confettiColors[i % 3];
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rnd.nextDouble() * math.pi);
        canvas.drawRect(const Rect.fromLTWH(-2.5, -2.5, 5, 5), fleckPaint);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const int dashCount = 24;
    const double dashLength = (math.pi * 2) / (dashCount * 2);
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * 2 * dashLength;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLength,
        false,
        paint,
      );
    }
  }

  void _drawNetworkNode(Canvas canvas, Offset node, Offset connectTo, Color color) {
    final Paint linePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2.0;
    canvas.drawLine(node, connectTo, linePaint);

    canvas.drawCircle(node, 10, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(node, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CardCirclePainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.blink != blink ||
        oldDelegate.shimmerT != shimmerT;
  }
}