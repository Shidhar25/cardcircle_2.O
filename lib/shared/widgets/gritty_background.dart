import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Custom painter rendering a heavy fabric / canvas weave texture with noise grit.
class FabricTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1.0;
    final random = math.Random(101);

    // Fine fabric horizontal weave lines
    for (double y = 0; y < size.height; y += 2.5) {
      final alpha = 0.012 + random.nextDouble() * 0.025;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Fine fabric vertical weave lines
    for (double x = 0; x < size.width; x += 2.5) {
      final alpha = 0.012 + random.nextDouble() * 0.025;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Micro noise grit particles
    final gritPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 6000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      gritPaint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.055);
      canvas.drawCircle(Offset(x, y), 0.7, gritPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reusable background wrapper that applies the fabric canvas texture across screens.
class GrittyBackground extends StatelessWidget {
  final Widget child;

  const GrittyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Solid base background
        Positioned.fill(
          child: Container(color: AppColors.background),
        ),
        
        // 2. The actual UI content
        child,

        // 3. The Texture OVERLAY (IgnorePointer ensures it doesn't block taps)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: FabricTexturePainter(),
            ),
          ),
        ),
      ],
    );
  }
}
