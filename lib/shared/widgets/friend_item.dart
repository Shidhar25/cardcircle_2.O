import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/theme/app_theme.dart';
import '../models/models.dart';

class FriendItem extends StatelessWidget {
  final Friend friend;
  final VoidCallback onToggleFollow;

  const FriendItem({
    super.key,
    required this.friend,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Circle Initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: friend.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              friend.initials,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Core details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      friend.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        friend.level,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  friend.username,
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                // Common Cards Row
                if (friend.commonCards.isNotEmpty)
                  Text(
                    'Also owns: ${friend.commonCards.join(", ")}',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),

          // Follow/Following/Invite Action Button
          Builder(
            builder: (context) {
              final bool isInviteOnly = friend.level == 'Invite Only';
              return ElevatedButton(
                onPressed: isInviteOnly
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invitation link sent to ${friend.name}!'),
                            backgroundColor: AppColors.green,
                          ),
                        );
                      }
                    : onToggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInviteOnly
                      ? Colors.transparent
                      : (friend.isFollowing ? Colors.transparent : AppColors.primary),
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: (isInviteOnly || friend.isFollowing)
                        ? const BorderSide(color: AppColors.border, width: 1.5)
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  isInviteOnly ? 'Invite' : (friend.isFollowing ? 'Following' : 'Follow'),
                  style: TextStyle(
                    color: (isInviteOnly || friend.isFollowing) ? AppColors.mutedForeground : const Color(0xFF050505),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}
