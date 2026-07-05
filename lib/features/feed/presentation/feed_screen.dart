import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_state.dart';
import '../state/feed_state.dart';
import '../../../shared/widgets/hack_card.dart';
import '../../../shared/widgets/offer_card.dart';

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
  final List<Map<String, String>> _activities = [
    {'name': 'Amit', 'action': 'saved ₹1,200', 'time': '5m', 'initials': 'AP', 'color': '0xFF00D4FF'},
    {'name': 'Priya', 'action': 'unlocked Gold', 'time': '20m', 'initials': 'PS', 'color': '0xFF8B5CF6'},
    {'name': 'Rahul', 'action': 'claimed Flat ₹100', 'time': '1h', 'initials': 'RM', 'color': '0xFFFFD700'},
    {'name': 'Deepika', 'action': 'shared a hack', 'time': '3h', 'initials': 'DR', 'color': '0xFF00FF88'},
    {'name': 'Karan', 'action': 'joined Dining club', 'time': '5h', 'initials': 'KJ', 'color': '0xFFFF6B35'},
  ];

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final feedState = Provider.of<FeedState>(context);

    final user = authState.user;
    final hacks = feedState.hacks;
    final offers = feedState.offers;

    final int itemCount = hacks.length + offers.length;

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
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const Text(
                        'Circle',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onNavigateToProfile,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: itemCount + 1, // +1 for the top activities carousel
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Friends horizontal activities carousel
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          child: Text(
                            "Friends' Activity",
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                                  border: Border.all(color: AppColors.border, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(colorVal).withValues(alpha: 0.15),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        act['initials']!,
                                        style: TextStyle(
                                          color: Color(colorVal),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${act['name']} ',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${act['action']} • ${act['time']}',
                                      style: const TextStyle(
                                        color: AppColors.mutedForeground,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }

                  // Interleaved hacks and offers list
                  final dataIndex = index - 1;
                  final isEven = dataIndex % 2 == 0;
                  final hackIndex = dataIndex ~/ 2;
                  final offerIndex = dataIndex ~/ 2;

                  if (isEven && hackIndex < hacks.length) {
                    final hack = hacks[hackIndex];
                    return HackCard(
                      hack: hack,
                      onLike: () => feedState.likeHack(hack.id),
                    );
                  } else if (!isEven && offerIndex < offers.length) {
                    return OfferCard(offer: offers[offerIndex]);
                  } else {
                    // Fallback to whichever array is still populated
                    if (hackIndex < hacks.length) {
                      final hack = hacks[hackIndex];
                      return HackCard(
                        hack: hack,
                        onLike: () => feedState.likeHack(hack.id),
                      );
                    } else if (offerIndex < offers.length) {
                      return OfferCard(offer: offers[offerIndex]);
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
