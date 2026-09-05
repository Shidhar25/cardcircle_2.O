import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Shared screen chrome matching CardCircle.html's phone-frame background:
/// a flat Nocturne base (`AppColors.background`) with a soft radial gold
/// glow pinned to the top, from the prototype's
/// `radial-gradient(120% 60% at 50% -8%, rgba(216,174,78,.09), transparent 62%)`.
///
/// No grain/noise texture — the prototype has none. Kept under the
/// `GrittyBackground` name so every existing screen (which already wraps
/// its body in this widget) picks up the retheme without further edits.
class GrittyBackground extends StatelessWidget {
  final Widget child;

  const GrittyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: AppColors.background)),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -1.16),
                  radius: 0.9,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.62],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
