import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/models.dart';
import 'neo_pop_button.dart';

class FriendItem extends StatefulWidget {
  final Friend friend;
  final Future<void> Function() onToggleFollow;

  const FriendItem({
    super.key,
    required this.friend,
    required this.onToggleFollow,
  });

  @override
  State<FriendItem> createState() => _FriendItemState();
}

class _FriendItemState extends State<FriendItem> {
  bool _isLoading = false;

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
                colors: widget.friend.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.friend.initials,
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
                      widget.friend.name,
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
                        widget.friend.level,
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
                  widget.friend.username,
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Follow/Following/Invite Action Button
          Builder(
            builder: (context) {
              final bool isInviteOnly = widget.friend.level == 'Invite Only';
              final bool isFollowing = widget.friend.isFollowing;
              return NeoPopButton(
                onPressed: _isLoading
                    ? null
                    : (isInviteOnly
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invitation link sent to ${widget.friend.name}!'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                          }
                        : () async {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              await widget.onToggleFollow();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          }),
                style: NeoPopButtonStyle.flat,
                color: isInviteOnly || isFollowing
                    ? Colors.transparent
                    : AppColors.primary,
                shadowColor: isInviteOnly || isFollowing
                    ? Colors.transparent
                    : const Color(0xFF008899),
                depth: isInviteOnly || isFollowing ? 0 : 4.0,
                fullWidth: false,
                isLoading: _isLoading,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  isInviteOnly ? 'Invite' : (isFollowing ? 'Following' : 'Follow'),
                  style: TextStyle(
                    color: (isInviteOnly || isFollowing) ? AppColors.mutedForeground : const Color(0xFF050505),
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
