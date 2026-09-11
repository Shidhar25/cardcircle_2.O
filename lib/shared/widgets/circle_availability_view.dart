import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/circle_availability.dart';
import 'primitives.dart';

/// A friend's avatar — their picture when they have one, initials when not.
class _HolderAvatar extends StatelessWidget {
  final CircleHolder holder;
  final double size;
  final AvatarHue hue;

  const _HolderAvatar({
    required this.holder,
    required this.size,
    required this.hue,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = AvatarBubble(
      initials: holder.initials,
      size: size,
      hue: hue,
    );
    final url = holder.profilePictureUrl;
    if (url == null) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A dead or slow picture must not leave a hole where a face goes —
        // the initials stand in until it loads, and stay if it never does.
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

/// Deterministic avatar colour, so the same friend keeps the same hue
/// wherever they appear rather than changing with list position.
AvatarHue _hueFor(CircleHolder holder) {
  final key = holder.userId.isNotEmpty ? holder.userId : holder.displayName;
  return AvatarHue.values[key.hashCode.abs() % AvatarHue.values.length];
}

/// One line for a feed row: overlapping faces plus the count behind them.
///
/// The count leads, not the names — "4 people in your circle can avail this"
/// is the fact that makes a benefit worth opening, and it stays one short
/// line no matter how many friends hold the card. The names are a tap away
/// in [CircleAvailabilitySheet], since "who do I ask" is the next question
/// but not the first one.
class CircleAvailabilityStrip extends StatelessWidget {
  final CircleAvailability availability;

  const CircleAvailabilityStrip({super.key, required this.availability});

  static const int _maxFaces = 3;

  @override
  Widget build(BuildContext context) {
    if (availability.isEmpty) return const SizedBox.shrink();

    final faces = availability.users.take(_maxFaces).toList();
    final line = '${availability.peopleLabel} in your circle can avail this';

    final row = Row(
      children: [
        if (faces.isNotEmpty)
          SizedBox(
            height: 22,
            width: 22 + (faces.length - 1) * 14,
            child: Stack(
              children: [
                for (int i = 0; i < faces.length; i++)
                  Positioned(
                    left: i * 14,
                    child: Container(
                      // A ring in the card colour, so overlapping faces
                      // stay separable instead of merging into a blob.
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      padding: const EdgeInsets.all(1),
                      child: _HolderAvatar(
                        holder: faces[i],
                        size: 20,
                        hue: _hueFor(faces[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sans(11.5, color: AppColors.teal),
          ),
        ),
        // Only a strip that can actually name someone advertises a tap.
        if (availability.hasNames)
          const Icon(
            Icons.chevron_right_rounded,
            size: 15,
            color: AppColors.teal,
          ),
      ],
    );

    // With no names to show there is nothing to open, so the tap is left to
    // the card underneath, which opens the benefit itself.
    if (!availability.hasNames) return row;

    return InkWell(
      onTap: () => CircleAvailabilitySheet.show(context, availability),
      child: row,
    );
  }
}

/// The names behind the count, as a bottom sheet.
///
/// Opened from [CircleAvailabilityStrip] in the feed, where the reader has
/// seen "4 people can avail this" and wants to know which four. Same content
/// as the detail page's panel, so the answer doesn't change with the route
/// the reader took to it.
class CircleAvailabilitySheet extends StatelessWidget {
  final CircleAvailability availability;

  const CircleAvailabilitySheet({super.key, required this.availability});

  static Future<void> show(
    BuildContext context,
    CircleAvailability availability,
  ) {
    if (!availability.hasNames) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CircleAvailabilitySheet(availability: availability),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = availability.users;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.mdLg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Who can avail this',
            style: AppText.sans(
              19,
              weight: FontWeight.w500,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${availability.peopleLabel} in your circle',
            style: AppText.sans(12.5, color: AppColors.textDim),
          ),
          const SizedBox(height: AppSpacing.lg),
          // A circle large enough to fill the screen scrolls inside the
          // sheet rather than pushing itself past the top of it.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < users.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.mdLg),
                    _HolderRow(holder: users[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full answer on a benefit's detail page: who can avail it, and on
/// which of their cards.
///
/// Cards are named because "someone can" is not actionable — the reader is
/// deciding whom to ask, and the card is what makes that a real
/// conversation. Only cards a friend shared are ever present here.
class CircleAvailabilityPanel extends StatelessWidget {
  final CircleAvailability availability;

  const CircleAvailabilityPanel({super.key, required this.availability});

  @override
  Widget build(BuildContext context) {
    if (availability.isEmpty) return const SizedBox.shrink();

    final users = availability.users;

    return OutlinedSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: MonoLabel(
                  'WHO IN YOUR CIRCLE CAN AVAIL THIS',
                  size: 9.5,
                  letterSpacing: 1.8,
                  color: AppColors.textFaint,
                ),
              ),
              MonoLabel(
                '${availability.count}',
                size: 11,
                letterSpacing: 0,
                color: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.mdLg),

          if (users.isEmpty)
            // A count with no list: the people are there, their cards are
            // not shared. Saying so beats an empty panel.
            Text(
              '${availability.peopleLabel} you follow hold a card for this.',
              style: AppText.sans(12.5, color: AppColors.textDim, height: 1.5),
            )
          else
            for (int i = 0; i < users.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.mdLg),
              _HolderRow(holder: users[i]),
            ],
        ],
      ),
    );
  }
}

class _HolderRow extends StatelessWidget {
  final CircleHolder holder;

  const _HolderRow({required this.holder});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HolderAvatar(holder: holder, size: 30, hue: _hueFor(holder)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                holder.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(
                  13,
                  weight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              // One line per card: a friend with two qualifying cards is a
              // single person here, and both are worth naming.
              for (final card in holder.cards) ...[
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.credit_card_rounded,
                        size: 12,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card,
                        style: AppText.sans(
                          11.5,
                          color: AppColors.textDim,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
