import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/theme/app_theme.dart';
import '../models/models.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final Function(String) onComplete;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onComplete,
  });

  static const Map<String, IconData> iconMap = {
    'wallet': Icons.account_balance_wallet_rounded,
    'people': Icons.people_alt_rounded,
    'flash': Icons.flash_on_rounded,
    'gift': Icons.card_giftcard_rounded,
    'flame': Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final double ratio = (challenge.progress / challenge.total).clamp(0.0, 1.0);
    final isDone = challenge.progress >= challenge.total || challenge.completed;
    final iconData = iconMap[challenge.iconName] ?? Icons.stars;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppColors.green.withValues(alpha: 0.3) : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.green.withValues(alpha: 0.1)
                          : AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      iconData,
                      size: 20,
                      color: isDone ? AppColors.green : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        challenge.daysLeft > 0 ? '${challenge.daysLeft}d left' : 'No time limit',
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 10, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      '+${challenge.rewardPoints} pts',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            challenge.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Progress Bar & Details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isDone ? 'Completed' : 'In Progress',
                          style: TextStyle(
                            color: isDone ? AppColors.green : AppColors.mutedForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${challenge.progress} / ${challenge.total}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          heightFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDone ? AppColors.green : AppColors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDone) ...[
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: challenge.claimed ? null : () => onComplete(challenge.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: challenge.claimed ? AppColors.elevated : AppColors.green,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    challenge.claimed ? 'Claimed' : 'Claim',
                    style: TextStyle(
                      color: challenge.claimed ? AppColors.mutedForeground : const Color(0xFF050505),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
