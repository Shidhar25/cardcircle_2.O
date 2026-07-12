import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_state.dart';
import '../state/feed_state.dart';
import '../../../shared/widgets/hack_card.dart';
import '../../../shared/widgets/offer_card.dart';
import '../../circle/state/circle_state.dart';
import '../../../shared/widgets/neo_pop_button.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback onNavigateToProfile;

  const FeedScreen({
    super.key,
    required this.onNavigateToProfile,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _activeTab = 'hacks'; // 'hacks' | 'offers'
  final List<Map<String, String>> _activities = [
    {'name': 'Amit', 'action': 'saved ₹1,200', 'time': '5m', 'initials': 'AP', 'color': '0xFF00E5FF'},
    {'name': 'Priya', 'action': 'unlocked Gold', 'time': '20m', 'initials': 'PS', 'color': '0xFF9D4EDD'},
    {'name': 'Rahul', 'action': 'claimed Flat ₹100', 'time': '1h', 'initials': 'RM', 'color': '0xFFFFD700'},
    {'name': 'Deepika', 'action': 'shared a hack', 'time': '3h', 'initials': 'DR', 'color': '0xFF00FF88'},
    {'name': 'Karan', 'action': 'joined Dining club', 'time': '5h', 'initials': 'KJ', 'color': '0xFFFF3333'},
  ];

  Future<void> _handleRefresh() async {
    final feedState = Provider.of<FeedState>(context, listen: false);
    final circleState = Provider.of<CircleState>(context, listen: false);
    await Future.wait([
      feedState.loadHacks(),
      feedState.loadOffers(),
      circleState.loadContactsFromDirectory(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final feedState = Provider.of<FeedState>(context);
    final circleState = Provider.of<CircleState>(context);

    final user = authState.user;
    final hacks = feedState.hacks;
    final offers = feedState.offers;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Card',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const Text(
                        'Circle',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pushNamed(context, '/notifications'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            if (circleState.incomingRequests.isNotEmpty)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    circleState.incomingRequests.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: widget.onNavigateToProfile,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.purple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: -0.1, curve: Curves.easeOutQuad),

            // Friends horizontal activities carousel
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Text(
                    "Friends' Activity",
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: _activities.length,
                    itemBuilder: (context, actIdx) {
                      final act = _activities[actIdx];
                      final colorVal = int.parse(act['color']!);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(colorVal).withValues(alpha: 0.15),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                act['initials']!,
                                style: TextStyle(
                                  color: Color(colorVal),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${act['name']} ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${act['action']} • ${act['time']}',
                              style: const TextStyle(
                                color: AppColors.mutedForeground,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),

            // Tab toggles (Hacks vs Offers)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeTab = 'hacks';
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 'hacks' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeTab == 'hacks' ? [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
                          ] : [],
                        ),
                        child: Center(
                          child: Text(
                            'Savings Hacks',
                            style: TextStyle(
                              color: _activeTab == 'hacks'
                                  ? AppColors.background
                                  : AppColors.mutedForeground,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeTab = 'offers';
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 'offers' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeTab == 'offers' ? [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
                          ] : [],
                        ),
                        child: Center(
                          child: Text(
                            'Deals & Offers',
                            style: TextStyle(
                              color: _activeTab == 'offers'
                                  ? AppColors.background
                                  : AppColors.mutedForeground,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),
            const SizedBox(height: 8),

            // Tab contents
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                child: _activeTab == 'hacks'
                    ? (hacks.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.6,
                              alignment: Alignment.center,
                              child: _buildEmptyState('No hacks available.'),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: circleState.suggestedFriends.isNotEmpty
                                ? hacks.length + 1
                                : hacks.length,
                            itemBuilder: (context, idx) {
                              if (circleState.suggestedFriends.isNotEmpty) {
                                  if (idx == 0) {
                                    return _buildSuggestedFriendsRow(circleState);
                                  }
                                  final hack = hacks[idx - 1];
                                  return HackCard(
                                    hack: hack,
                                    onLike: () => feedState.likeHack(hack.id),
                                  ).animate().fade(delay: (200 + (idx * 50)).ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad);
                              } else {
                                  final hack = hacks[idx];
                                  return HackCard(
                                    hack: hack,
                                    onLike: () => feedState.likeHack(hack.id),
                                  ).animate().fade(delay: (200 + (idx * 50)).ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad);
                              }
                            },
                          ))
                    : (offers.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.6,
                              alignment: Alignment.center,
                              child: _buildEmptyState('No offers available.'),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: circleState.suggestedFriends.isNotEmpty
                                ? offers.length + 1
                                : offers.length,
                            itemBuilder: (context, idx) {
                              if (circleState.suggestedFriends.isNotEmpty) {
                                  if (idx == 0) {
                                    return _buildSuggestedFriendsRow(circleState);
                                  }
                                  return OfferCard(offer: offers[idx - 1])
                                      .animate()
                                      .fade(delay: (200 + (idx * 50)).ms, duration: 400.ms)
                                      .slideY(begin: 0.1, curve: Curves.easeOutQuad);
                              } else {
                                  return OfferCard(offer: offers[idx])
                                      .animate()
                                      .fade(delay: (200 + (idx * 50)).ms, duration: 400.ms)
                                      .slideY(begin: 0.1, curve: Curves.easeOutQuad);
                              }
                            },
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 40, color: AppColors.mutedForeground),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(color: AppColors.mutedForeground, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedFriendsRow(CircleState circleState) {
    final suggestions = circleState.suggestedFriends;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Suggested Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final friend = suggestions[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: friend.gradientColors,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        friend.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 28,
                      child: NeoPopButton(
                        onPressed: () async {
                          final success = await circleState.toggleFollow(friend.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sent follow request to ${friend.name}!'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                          } else if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to send follow request.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: NeoPopButtonStyle.flat,
                        color: AppColors.primary,
                        shadowColor: const Color(0xFF008899),
                        depth: 3.0,
                        fullWidth: true,
                        padding: EdgeInsets.zero,
                        child: const Center(
                          child: Text(
                            'Follow',
                            style: TextStyle(
                              color: Color(0xFF050505),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    ).animate().fade(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad);
  }
}