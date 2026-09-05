import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_state.dart';
import '../../circle/state/circle_state.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/card_stack.dart';

/// v1 screen 19 — Home: wordmark header with bell + avatar, greeting, and
/// the fan-out stack of the user's own cards.
///
/// Home is deliberately just the wallet. The prototype's "circle today"
/// strip and missing-benefits nudge were invented numbers — a fixture list
/// of friends and a savings figure derived from a hash of the card id — and
/// the benefit-of-the-day card duplicated the Benefits tab, which is where
/// browsing belongs.
class FeedScreen extends StatefulWidget {
  final VoidCallback onNavigateToProfile;

  const FeedScreen({super.key, required this.onNavigateToProfile});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _fanned = false;

  Future<void> _handleRefresh() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    final circleState = Provider.of<CircleState>(context, listen: false);
    await Future.wait([
      authState.refreshProfileFromServer(),
      authState.fetchUserCards(),
      circleState.loadContactsFromDirectory(),
    ]);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final circleState = Provider.of<CircleState>(context);
    final user = authState.user;
    final cards = user.cards;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: wordmark, bell (unread badge), avatar.
                  Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: AppText.sans(
                                  20,
                                  weight: FontWeight.w500,
                                  color: AppColors.text,
                                  letterSpacing: -0.4,
                                ),
                                children: [
                                  const TextSpan(text: 'Card'),
                                  TextSpan(
                                    text: 'Circle',
                                    style: AppText.sans(
                                      20,
                                      weight: FontWeight.w500,
                                      color: AppColors.gold,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _NotificationBell(
                                  unreadCount:
                                      circleState.incomingRequests.length,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/notifications',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                GestureDetector(
                                  onTap: widget.onNavigateToProfile,
                                  child: AvatarBubble(
                                    initials: user.initials,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOutCubic),

                  const SizedBox(height: AppSpacing.md),

                  // Greeting.
                  Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoLabel(
                              _greeting(),
                              size: 9.5,
                              letterSpacing: 2.0,
                              color: AppColors.textFaint,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              user.name,
                              style: AppText.sans(
                                25,
                                weight: FontWeight.w500,
                                color: AppColors.text,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 450.ms, delay: 60.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOutCubic),

                  const SizedBox(height: AppSpacing.xl),

                  // Card stack.
                  //
                  // The header keeps the page's gutter; the cards themselves
                  // sit in a narrower one so the plates read as large as the
                  // screen allows.
                  Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    MonoLabel(
                                      'YOUR CARDS · ${cards.length}',
                                      size: 9.5,
                                      letterSpacing: 1.8,
                                      color: AppColors.textFaint,
                                    ),
                                    if (cards.isNotEmpty)
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _fanned = !_fanned),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _fanned ? 'Collapse' : 'Fan out',
                                              style: AppText.sans(
                                                11.5,
                                                color: AppColors.gold,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              _fanned
                                                  ? PhosphorIconsRegular
                                                        .arrowsInLineVertical
                                                  : PhosphorIconsRegular
                                                        .arrowsOutLineVertical,
                                              size: 13,
                                              color: AppColors.gold,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.mdLg),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: CardStack(cards: cards, fanned: _fanned),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 450.ms, delay: 120.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOutCubic),

                  const SizedBox(height: AppSpacing.xxl),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      0,
                    ),
                    child: Text(
                      "You're seeing benefits matched to ${cards.length} card${cards.length == 1 ? '' : 's'}.",
                      textAlign: TextAlign.center,
                      style: AppText.sans(
                        11,
                        color: AppColors.textGhost,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              PhosphorIconsRegular.bell,
              size: 19,
              color: AppColors.text,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: 6,
              right: 7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Text(
                  '$unreadCount',
                  style: AppText.mono(
                    8.5,
                    ls: 0,
                    w: FontWeight.w700,
                    c: AppColors.background,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
