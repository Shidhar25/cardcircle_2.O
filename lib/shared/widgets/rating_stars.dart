import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/theme/app_theme.dart';
import '../models/hack_rating.dart';

/// A compact "★ 4.2 (12)" badge for an aggregate rating.
///
/// Renders nothing at all when nobody has rated: an empty aggregate shown
/// as "0.0" reads as a damning score rather than an absent one.
class RatingBadge extends StatelessWidget {
  final HackRating rating;

  /// Whether this is the circle's score rather than the platform's. Circle
  /// ratings are the app's whole premise, so they are tinted gold and
  /// labelled; the platform average is quieter.
  final bool fromCircle;

  final double size;

  const RatingBadge({
    super.key,
    required this.rating,
    this.fromCircle = false,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (!rating.hasRatings) return const SizedBox.shrink();

    final color = fromCircle ? AppColors.gold : AppColors.textFaint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsFill.star, size: size + 1, color: color),
        const SizedBox(width: 4),
        Text(
          rating.display,
          style: AppText.mono(size, ls: 0.3, w: FontWeight.w700, c: color),
        ),
        const SizedBox(width: 4),
        // The sample size, because an average without one invites the
        // reader to treat two votes like two hundred. Flexible so a narrow
        // parent ellipsises it instead of overflowing.
        Flexible(
          child: Text(
            fromCircle
                ? '· ${rating.count} in your circle'
                : '(${rating.count})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: AppText.sans(size, color: AppColors.textFaint),
          ),
        ),
      ],
    );
  }
}

/// Five tappable stars for submitting a rating.
///
/// [value] is the user's own score, or null when they have not rated. The
/// control shows their score rather than the average, because that is what
/// tapping changes.
class RatingPicker extends StatelessWidget {
  final int? value;
  final bool busy;
  final ValueChanged<int> onRate;
  final double size;

  const RatingPicker({
    super.key,
    required this.value,
    required this.onRate,
    this.busy = false,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = value != null && star <= value!;
        return GestureDetector(
          // Ignoring taps while a submission is in flight keeps the shown
          // score and the stored one from diverging on a fast double-tap.
          onTap: busy ? null : () => onRate(star),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
            child: Opacity(
              opacity: busy ? 0.5 : 1,
              child: Icon(
                filled ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                size: size,
                color: filled ? AppColors.gold : AppColors.textFaint,
              ),
            ),
          ),
        );
      }),
    );
  }
}
