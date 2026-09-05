import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/config/config_inspector_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../state/category_state.dart';
import '../../../shared/widgets/card_stack.dart';
import '../../../shared/models/models.dart' as models;
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 24 — Profile. Matches CardCircle.html's `isProfile` block:
/// settings gear, conic-ring avatar, level pill, followers/following
/// stat row, the shared fan-out card stack, spend-category chips, and a
/// settings list ending in Log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _fanned = false;

  /// Dev-only rows are appended only in debug builds, so a release build
  /// has no path to the internals.
  static List<Map<String, dynamic>> get visibleSettingsOptions => [
    ...settingsOptions,
    if (ConfigInspectorScreen.isAvailable) ...[
      {
        'label': 'Remote config (dev)',
        'icon': PhosphorIconsRegular.slidersHorizontal,
        'route': ConfigInspectorScreen.routeName,
      },
    ],
  ];

  static const List<Map<String, dynamic>> settingsOptions = [
    {
      'label': 'Notification preferences',
      'icon': PhosphorIconsRegular.bell,
      'route': '/notifications',
    },
    {
      'label': 'Privacy & visibility',
      'icon': PhosphorIconsRegular.lockKey,
      'route': null,
    },
    {
      'label': 'Connected cards',
      'icon': PhosphorIconsRegular.creditCard,
      'route': '/select-cards',
    },
    {
      'label': 'Invite friends',
      'icon': PhosphorIconsRegular.userPlus,
      'route': null,
    },
    {
      'label': 'Help & support',
      'icon': PhosphorIconsRegular.lifebuoy,
      'route': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<AuthState>(context, listen: false).refreshProfileFromServer();
      // The chips below show the user's own tagged categories, so both the
      // catalogue and their selection are needed.
      final categories = Provider.of<CategoryState>(context, listen: false);
      categories.loadAll();
      categories.loadMine();
    });
  }

  void _showLogoutConfirmation(BuildContext context, AuthState authState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          title: Text(
            'Confirm Logout',
            style: AppText.sans(
              15,
              weight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of CardCircle?',
            style: AppText.sans(13, color: AppColors.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppText.sans(13, color: AppColors.textDim),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ApiService.logout();
                await authState.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
              child: Text(
                'Log out',
                style: AppText.sans(
                  13,
                  weight: FontWeight.w500,
                  color: AppColors.destructive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCardDetailsModal(
    BuildContext context,
    List<models.CreditCard> cards,
    int initialIndex,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CardDetailsModalView(
        cards: cards,
        initialIndex: initialIndex,
        cardHolderName: Provider.of<AuthState>(
          context,
          listen: false,
        ).user.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final user = authState.user;
    final myCategories = Provider.of<CategoryState>(context).mine;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => Provider.of<AuthState>(
              context,
              listen: false,
            ).refreshProfileFromServer(),
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconTile(
                        icon: PhosphorIconsRegular.gearSix,
                        iconSize: 18,
                        color: AppColors.textDim,
                        onTap: () =>
                            Navigator.pushNamed(context, '/edit-profile'),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/edit-profile'),
                          child: Container(
                            width: 88,
                            height: 88,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  AppColors.goldLight,
                                  AppColors.teal,
                                  Color(0xFFB5ABFC),
                                  AppColors.goldLight,
                                ],
                              ),
                            ),
                            child: AvatarBubble(
                              initials: user.initials,
                              size: 82,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        Text(
                          user.name,
                          style: AppText.sans(
                            21,
                            weight: FontWeight.w500,
                            color: AppColors.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        MonoLabel(
                          user.username.replaceAll('@', ''),
                          size: 11,
                          letterSpacing: 1.1,
                          color: AppColors.textFaint,
                          uppercase: false,
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5.6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                PhosphorIconsRegular.medal,
                                size: 13,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 6),
                              MonoLabel(
                                'LEVEL ${user.levelIndex + 1} · ${user.level}',
                                size: 9.5,
                                letterSpacing: 1.4,
                                color: AppColors.gold,
                                uppercase: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      0,
                    ),
                    child: OutlinedSurface(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.mdLg,
                      ),
                      child: Row(
                        children: [
                          _StatCol(
                            value: '${user.followersCount}',
                            label: 'FOLLOWERS',
                            onTap: () =>
                                Navigator.pushNamed(context, '/circle'),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: AppColors.border,
                          ),
                          _StatCol(
                            value: '${user.followingCount}',
                            label: 'FOLLOWING',
                            onTap: () =>
                                Navigator.pushNamed(context, '/circle'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MonoLabel(
                              'MY CARDS · ${user.cards.length}',
                              size: 9.5,
                              letterSpacing: 1.8,
                              color: AppColors.textFaint,
                            ),
                            if (user.cards.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _fanned = !_fanned),
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
                        const SizedBox(height: AppSpacing.mdLg),
                        GestureDetector(
                          onTap: user.cards.isEmpty
                              ? null
                              : () => _showCardDetailsModal(
                                  context,
                                  user.cards,
                                  0,
                                ),
                          child: CardStack(cards: user.cards, fanned: _fanned),
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/select-cards',
                            arguments: {'fromProfile': true},
                          ),
                          child: OutlinedSurface(
                            padding: EdgeInsets.zero,
                            child: SizedBox(
                              height: 46,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.plus,
                                    size: 15,
                                    color: AppColors.text,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add another card',
                                    style: AppText.sans(
                                      13,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MonoLabel(
                          'SPEND CATEGORIES',
                          size: 9.5,
                          letterSpacing: 1.8,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // The user's own tagged categories, from
                        // `GET /category/user`. These were five hardcoded
                        // words before, identical for every account and
                        // unrelated to what anyone actually picked in
                        // Select Tags.
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (myCategories.isEmpty)
                              Text(
                                'No categories picked yet.',
                                style: AppText.sans(
                                  11.5,
                                  color: AppColors.textFaint,
                                ),
                              )
                            else
                              ...myCategories.map(
                                (c) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        c.icon,
                                        size: 12,
                                        color: c.color(AppColors.textMuted),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        c.displayName,
                                        style: AppText.sans(
                                          11.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/select-tags'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  myCategories.isEmpty ? 'Pick' : 'Edit',
                                  style: AppText.sans(
                                    11.5,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      0,
                    ),
                    child: OutlinedSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ...visibleSettingsOptions.map(
                            (opt) => _SettingsRow(
                              label: opt['label'],
                              icon: opt['icon'],
                              onTap: () {
                                final route = opt['route'] as String?;
                                if (route == '/select-cards') {
                                  Navigator.pushNamed(
                                    context,
                                    route!,
                                    arguments: {'fromProfile': true},
                                  );
                                } else if (route != null) {
                                  Navigator.pushNamed(context, route);
                                }
                              },
                            ),
                          ),
                          _SettingsRow(
                            label: 'Log out',
                            icon: PhosphorIconsRegular.signOut,
                            destructive: true,
                            onTap: () =>
                                _showLogoutConfirmation(context, authState),
                          ),
                        ],
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

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCol({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              value,
              style: AppText.mono(
                19,
                ls: 0,
                w: FontWeight.w700,
                c: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            MonoLabel(
              label,
              size: 8.5,
              letterSpacing: 1.4,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color tint = destructive ? AppColors.destructive : AppColors.gold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.mdLg),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  color: destructive
                      ? AppColors.destructive.withValues(alpha: 0.12)
                      : AppColors.elevated,
                ),
                child: Icon(icon, size: 15, color: tint),
              ),
              const SizedBox(width: AppSpacing.mdLg),
              Expanded(
                child: Text(
                  label,
                  style: AppText.sans(
                    13,
                    color: destructive ? AppColors.destructive : AppColors.text,
                  ),
                ),
              ),
              if (!destructive)
                const Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 13,
                  color: AppColors.textGhost,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDetailsModalView extends StatefulWidget {
  final List<models.CreditCard> cards;
  final int initialIndex;
  final String cardHolderName;

  const _CardDetailsModalView({
    required this.cards,
    required this.initialIndex,
    required this.cardHolderName,
  });

  @override
  State<_CardDetailsModalView> createState() => _CardDetailsModalViewState();
}

class _CardDetailsModalViewState extends State<_CardDetailsModalView> {
  late PageController _pageController;
  double _currentPage = 0;
  int get _cardCount => widget.cards.length;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.toDouble();
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  bool _deleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Index of the card currently filling the viewport, clamped because a
  /// deletion shrinks the list under the controller.
  int get _visibleIndex =>
      _cardCount == 0 ? 0 : _currentPage.round().clamp(0, _cardCount - 1);

  Future<void> _confirmDelete() async {
    final card = widget.cards[_visibleIndex];

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          'Remove card?',
          style: AppText.sans(
            15,
            weight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        content: Text(
          '${card.name} will be removed from your wallet. Hacks matched to it '
          'will stop showing. You can add it back any time.',
          style: AppText.sans(13, color: AppColors.textDim, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: AppText.sans(13, color: AppColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Remove',
              style: AppText.sans(
                13,
                weight: FontWeight.w500,
                color: AppColors.destructive,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final authState = Provider.of<AuthState>(context, listen: false);
    final result = await authState.deleteCard(card.id);
    if (!mounted) return;
    setState(() => _deleting = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.ok) {
      // The sheet holds its own reference to the list, so close it once the
      // wallet is empty rather than showing an empty carousel.
      if (authState.user.cards.isEmpty) {
        Navigator.pop(context);
      } else {
        // The list shrank under the controller, so settle it back onto a
        // valid page once this frame's rebuild has applied the new count.
        final target = _visibleIndex;
        setState(() => _currentPage = target.toDouble());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(target);
          }
        });
      }
    }
    messenger.showResult(
      result,
      onSuccess: '${card.name} removed.',
      onFailure: 'Could not remove that card. Please try again.',
    );
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cardList.isNotEmpty)
                      IconButton(
                        onPressed: _deleting ? null : _confirmDelete,
                        tooltip: 'Remove this card',
                        icon: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.destructive,
                                ),
                              )
                            : const Icon(
                                PhosphorIconsRegular.trash,
                                color: AppColors.destructive,
                                size: 20,
                              ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vertical Page Controller Carousel — plain swipe, no parallax
          // scale/rotate/opacity animation.
          Expanded(
            flex: 4,
            child: cardList.isEmpty
                ? const SizedBox.shrink()
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _cardCount,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          // Narrow gutter: the plate is the subject of this
                          // screen, so it gets as much width as it can.
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) => SizedBox(
                              width: constraints.maxWidth,
                              child: CardFacePanel(
                                card: cardList[index],
                                height:
                                    constraints.maxWidth /
                                    kCardImageAspectRatio,
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
                          widget.cardHolderName.toUpperCase(),
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
