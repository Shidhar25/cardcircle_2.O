import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/card_visual.dart';
import '../../../shared/models/models.dart' as models;
import '../../../shared/widgets/neo_pop_button.dart';

import '../../../shared/widgets/gritty_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<Color> levelColors = [
    AppColors.secondary,
    AppColors.primary,
    AppColors.purple,
    AppColors.cyan,
    AppColors.gold,
  ];

  static const List<Map<String, dynamic>> settingsOptions = [
    {'label': 'Notification Preferences', 'icon': Icons.notifications_none_rounded},
    {'label': 'Privacy Settings', 'icon': Icons.security_rounded},
    {'label': 'Connected Cards', 'icon': Icons.credit_card_rounded},
    {'label': 'Invite Friends', 'icon': Icons.person_add_alt_1_rounded},
    {'label': 'Help & Support', 'icon': Icons.help_outline_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthState>(context, listen: false).refreshProfileFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final user = authState.user;

    final Color levelColor = levelColors[user.levelIndex.clamp(0, levelColors.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Provider.of<AuthState>(context, listen: false).refreshProfileFromServer(),
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20, top: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.elevated,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.settings_outlined,
                          size: 20,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: levelColor, width: 3),
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondary, // Solid Periwinkle
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  user.initials,
                                  style: const TextStyle(
                                    color: AppColors.darkText,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.name.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.username.toLowerCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: levelColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: levelColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: levelColor),
                            const SizedBox(width: 6),
                            Text(
                              user.level,
                              style: TextStyle(
                                color: levelColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      _buildStatCol('Followers', user.followersCount.toString(), AppColors.cyan),
                      _buildStatDivider(),
                      _buildStatCol('Following', user.followingCount.toString(), AppColors.gold),
                      _buildStatDivider(),
                      _buildStatCol('Friends', user.friendsCount.toString(), AppColors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildStackedCardsSection(context, user.cards),

                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      ...List.generate(settingsOptions.length, (index) {
                        final opt = settingsOptions[index];
                        return Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              onTap: () {
                                if (opt['label'] == 'Connected Cards') {
                                  Navigator.pushNamed(context, '/select-cards', arguments: {'fromProfile': true});
                                }
                              },
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.elevated,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Icon(opt['icon'], size: 18, color: AppColors.primary),
                              ),
                              title: Text(
                                opt['label'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  size: 16, color: AppColors.mutedForeground),
                            ),
                          ),
                        );
                      }),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () => _showLogoutConfirmation(context, authState),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.destructive),
                          ),
                          title: const Text(
                            'Log out',
                            style: TextStyle(
                              color: AppColors.destructive,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildStackedCardsSection(BuildContext context, List<models.CreditCard> cards) {
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Cards (0)',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/select-cards', arguments: {'fromProfile': true}),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Add', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('No cards added yet.', style: TextStyle(color: AppColors.mutedForeground)),
              ),
            ),
          ],
        ),
      );
    }

    // Limit to 3 cards for the stacked visual, similar to the image
    final displayCards = cards.take(3).toList();
    // Calculate total height based on number of cards to stack nicely
    final double containerHeight = 150.0 + (displayCards.length - 1) * 35.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () => _showCardDetailsModal(context, cards, 0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MY CARDS (${cards.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/select-cards', arguments: {'fromProfile': true}),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, size: 4, color: Colors.white),
                            SizedBox(width: 2),
                            Icon(Icons.circle, size: 4, color: Colors.white),
                            SizedBox(width: 2),
                            Icon(Icons.circle, size: 4, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: containerHeight - 56, // Total minus header area
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: List.generate(displayCards.length, (index) {
                    // Reverse index so the first item in the list is on top (rendered last)
                    int reversedIndex = displayCards.length - 1 - index;
                    models.CreditCard card = displayCards[reversedIndex];

                    // Positioning math
                    double topOffset = index * 35.0; // Distance from top of stack area
                    double horizontalPadding = (displayCards.length - 1 - index) * 8.0; // Narrower at top

                    // Fading effect for cards further back
                    double opacity = 1.0;
                    if (index < displayCards.length - 1) {
                      opacity = 0.5 + (index / displayCards.length) * 0.4;
                    }

                    return Positioned(
                      top: topOffset,
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: index == displayCards.length - 1
                              ? AppColors.purple // Lightest for front card
                              : AppColors.secondary.withValues(alpha: opacity), // Darker for back cards
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            if (index > 0)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, -2),
                              )
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Simple text icon representation based on bank
                                if (index == displayCards.length - 1) ...[
                                  Text(
                                    card.bank.isNotEmpty ? card.bank[0].toUpperCase() : 'C',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    card.bank,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    card.bank.isNotEmpty ? card.bank[0].toUpperCase() : 'C',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            Text(
                              // Using category or a placeholder number for the UI feel
                              card.category,
                              style: TextStyle(
                                color: index == displayCards.length - 1 ? Colors.black87 : Colors.white,
                                fontSize: index == displayCards.length - 1 ? 16 : 14,
                                fontWeight: index == displayCards.length - 1 ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthState authState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to log out of CardCircle?',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            NeoPopButton(
              onPressed: () async {
                Navigator.pop(context);
                await ApiService.logout();
                await authState.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
              style: NeoPopButtonStyle.flat,
              color: AppColors.destructive,
              shadowColor: AppColors.destructive.withValues(alpha: 0.6),
              depth: 4.0,
              fullWidth: false,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const Text(
                'Log out',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildStatCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 8,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCardDetailsModal(BuildContext context, List<models.CreditCard> cards, int initialIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CardDetailsModalView(cards: cards, initialIndex: initialIndex);
      },
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 30, color: AppColors.border);
  }
}

class _CardDetailsModalView extends StatefulWidget {
  final List<models.CreditCard> cards;
  final int initialIndex;

  const _CardDetailsModalView({
    required this.cards,
    required this.initialIndex,
  });

  @override
  State<_CardDetailsModalView> createState() => _CardDetailsModalViewState();
}

class _CardDetailsModalViewState extends State<_CardDetailsModalView> {
  // Large multiple of the card count used as the PageView's starting offset,
  // so the user can keep swiping in either direction and the deck appears to
  // loop endlessly instead of stopping at the first/last card.
  static const int _loopWindows = 5000;

  late PageController _pageController;
  double _currentPage = 0;
  int get _cardCount => widget.cards.length;
  int get _loopBaseIndex => _cardCount * (_loopWindows ~/ 2);

  @override
  void initState() {
    super.initState();
    final initialPage = _loopBaseIndex + widget.initialIndex;
    _currentPage = initialPage.toDouble();
    _pageController = PageController(initialPage: initialPage, viewportFraction: 1.0);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardList = widget.cards;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'YOUR CARDS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Stacked Vertical Page Controller Carousel
          Expanded(
            flex: 4,
            child: cardList.isEmpty
                ? const SizedBox.shrink()
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    // Effectively-infinite item count with modulo indexing
                    // below makes the deck loop endlessly in both directions.
                    itemCount: _cardCount * _loopWindows,
                    itemBuilder: (context, index) {
                      final realIndex = index % _cardCount;
                      double delta = index - _currentPage;
                      if (delta > 2 || delta < -1) return const SizedBox.shrink();

                      // Ease the raw scroll delta so the scale/opacity/rotate
                      // transforms settle smoothly instead of tracking the
                      // finger linearly.
                      final double t = delta.abs().clamp(0.0, 1.0);
                      final double eased = Curves.easeOutCubic.transform(t);

                      double scale = (1 - eased * 0.1).clamp(0.75, 1.0);
                      double translateY = delta * -70;
                      double translateX = delta * 20;
                      double rotate = delta * -0.08;
                      double opacity = (1 - eased * 0.4).clamp(0.0, 1.0);

                      if (delta < 0) {
                        opacity = (1 - eased * 3).clamp(0.0, 1.0);
                        translateY = delta * 150;
                        scale = 1.0;
                      }

                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(translateX, translateY),
                          child: Transform.rotate(
                            angle: rotate,
                            child: Transform.scale(
                              scale: scale,
                              child: Center(
                                child: CardVisual(
                                  card: cardList[realIndex],
                                  compact: false,
                                  showTactileTab: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Pagination Dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cardList.length, (i) {
                bool isActive = i == _currentPage.round() % _cardCount;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: isActive ? 24 : 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                    border: isActive ? Border.all(color: Colors.black) : null,
                  ),
                );
              }),
            ),
          ),

          // Active Card Details Breakdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              width: double.infinity,
              child: Stack(
                children: List.generate(cardList.length, (i) {
                  bool isActive = i == _currentPage.round();
                  final card = cardList[i];
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isActive ? 1.0 : 0.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CARD NETWORK',
                                  style: TextStyle(
                                    color: AppColors.mutedForeground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card.bank.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'CATEGORY',
                                  style: TextStyle(
                                    color: AppColors.mutedForeground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CARDHOLDER NAME',
                          style: TextStyle(
                            color: AppColors.mutedForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}