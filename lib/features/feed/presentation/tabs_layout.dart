import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'feed_screen.dart';

import 'communities_screen.dart';
import '../../circle/presentation/circle_screen.dart';
import '../../challenges/presentation/challenges_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class TabsLayout extends StatefulWidget {
  const TabsLayout({super.key});

  @override
  State<TabsLayout> createState() => _TabsLayoutState();
}

class _TabsLayoutState extends State<TabsLayout> {
  int _currentIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      FeedScreen(
        onNavigateToProfile: () {
          _onTabTapped(4);
        },
      ),
      const CommunitiesScreen(),
      const CircleScreen(),
      const ChallengesScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    // Premium tactile feel on tab change
    HapticFeedback.lightImpact();

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Allows the background and lists to flow under the floating nav bar
      extendBody: true,
      backgroundColor: AppColors.background,
      body: PremiumAnimatedIndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Our custom curvy, floating navigation bar
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 70,
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(40), // Premium curvy pill shape
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_filled,
                label: 'Feed',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.groups_rounded,
                label: 'Communities',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.people_alt_rounded,
                label: 'Circle',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.stars_rounded,
                label: 'Challenges',
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds individual animated nav items
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bouncy Scale Animation for the Icon
            AnimatedScale(
              scale: isSelected ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.mutedForeground,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // Smooth text transition (bolder and slightly larger when active)
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.mutedForeground,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// A custom IndexedStack that adds a premium fade + scale transition
/// when switching between tabs, while keeping the state of all tabs alive.
class PremiumAnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const PremiumAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<PremiumAnimatedIndexedStack> createState() => _PremiumAnimatedIndexedStackState();
}

class _PremiumAnimatedIndexedStackState extends State<PremiumAnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnimation);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.02),
      end: Offset.zero,
    ).animate(curvedAnimation);

    _controller.forward();
  }

  @override
  void didUpdateWidget(PremiumAnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: IndexedStack(
            index: widget.index,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}