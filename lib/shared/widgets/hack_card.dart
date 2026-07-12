import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/models.dart';

class HackCard extends StatelessWidget {
  final Hack hack;
  final VoidCallback onLike;

  const HackCard({
    super.key,
    required this.hack,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF00D4FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hack.authorInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hack.author,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hack.authorLevel,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        hack.timestamp,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hack.category.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            hack.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),

          // Description & Blur Lock Overlay
          if (hack.isLocked)
            Stack(
              children: [
                // Blurred out placeholder description text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: double.infinity, color: AppColors.elevated),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 220, color: AppColors.elevated),
                  ],
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.card.withValues(alpha: 0.2),
                          AppColors.card.withValues(alpha: 0.95),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.purple.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock_rounded, size: 12, color: AppColors.purple),
                          SizedBox(width: 6),
                          Text(
                            'Level 2 Required to Unlock',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              hack.description,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 14),

          // Footer metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          hack.cardName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, size: 12, color: AppColors.green),
                        const SizedBox(width: 6),
                        Text(
                          hack.savings,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Like Button
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hack.liked
                        ? const Color(0xFFFF4757).withValues(alpha: 0.1)
                        : AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hack.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 13,
                        color: hack.liked ? const Color(0xFFFF4757) : AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hack.likes.toString(),
                        style: TextStyle(
                          color: hack.liked ? const Color(0xFFFF4757) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
