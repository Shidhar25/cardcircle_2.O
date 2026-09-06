import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import 'feed_screen.dart';
import 'discover_screen.dart';
import '../../circle/presentation/circle_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class TabsLayout extends StatefulWidget {
  /// Which tab to open on. Notifications route here to land the reader on
  /// Circle, so the tab has to be selectable from outside.
  final int initialIndex;

  const TabsLayout({super.key, this.initialIndex = 0});

  /// Tab positions, so callers name the destination rather than passing a
  /// bare integer that silently means the wrong screen if the order ever
  /// changes.
  static const int homeTab = 0;
  static const int benefitsTab = 1;
  static const int circleTab = 2;
  static const int profileTab = 3;

  @override
  State<TabsLayout> createState() => _TabsLayoutState();
}

class _TabsLayoutState extends State<TabsLayout> {
  late int _currentIndex = widget.initialIndex;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      FeedScreen(
        onNavigateToProfile: () {
          _onTabTapped(3);
        },
      ),
      const DiscoverScreen(),
      const CircleScreen(),
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

      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(currentIndex: _currentIndex, onTap: _onTabTapped),
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
  State<PremiumAnimatedIndexedStack> createState() =>
      _PremiumAnimatedIndexedStackState();
}

class _PremiumAnimatedIndexedStackState
    extends State<PremiumAnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(curvedAnimation);
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
          child: IndexedStack(index: widget.index, children: widget.children),
        ),
      ),
    );
  }
}
