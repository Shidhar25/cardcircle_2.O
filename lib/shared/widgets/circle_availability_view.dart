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

/// One line for a feed row: overlapping faces plus who they are.
///
/// The compact form deliberately names at most two people — a benefit five
/// friends hold should read "rahul_k, priya +3", not push the card's own
/// content off the screen.
class CircleAvailabilityStrip extends StatelessWidget {
  final CircleAvailability availability;
  final VoidCallback? onTap;

  const CircleAvailabilityStrip({
    super.key,
    required this.availability,
    this.onTap,
  });

  static const int _maxFaces = 3;
  static const int _maxNames = 2;

  @override
  Widget build(BuildContext context) {
    if (availability.isEmpty) return const SizedBox.shrink();

    final faces = availability.users.take(_maxFaces).toList();
    final named = availability.users.take(_maxNames).toList();
    final extra = availability.othersBeyond(named.length);
    final who = named.map((u) => u.displayName).join(', ');

    final String line;
    if (who.isEmpty) {
      // The count arrived without names — permissions can hide the list
      // while the number still stands.
      line = '${availability.count} in your circle can avail this';
    } else if (extra > 0) {
      line = '$who +$extra in your circle can avail this';
    } else {
      line = '$who in your circle can avail this';
    }

    return InkWell(
      onTap: onTap,
      child: Row(
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
          Expanded(
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(11.5, color: AppColors.teal),
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
              '${availability.count} '
              '${availability.count == 1 ? 'person' : 'people'} you follow '
              'hold a card for this.',
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
