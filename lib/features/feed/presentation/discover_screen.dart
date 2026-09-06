import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/config/remote_config.dart';
import '../../../core/theme/app_theme.dart';
import '../state/feed_state.dart';
import '../../auth/state/auth_state.dart';
import '../../profile/state/category_state.dart';
import '../../../shared/models/spend_category.dart';
import '../../../shared/models/hack.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/meta_chip.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/rating_stars.dart';

/// v1 screen 21 — Benefits: search bar, MY BENEFITS / CIRCLE BENEFITS
/// segmented tabs, a horizontal category pill row, and a vertical feed.
///
/// The title, search hint and tab labels read from remote config. The
/// category pills come from `GET /category/list` via [CategoryState] — they
/// used to be a hardcoded list ("Dining", "Online", …) that shared no
/// vocabulary with the backend's categories (`food_dining`, "Food &
/// Dining"), so selecting a pill matched nothing and emptied the feed.
///
/// v1 always has cards (FLUTTER_HANDOFF.md §2), so the "no cards yet" banner
/// and RECOMMENDED tab from the prototype are intentionally not built here.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _tabIndex = 0; // 0 = mine, 1 = circle

  /// The selected category, or null for "All".
  SpendCategory? _category;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  HackFeed get _feed => _tabIndex == 0 ? HackFeed.mine : HackFeed.circle;

  /// How far from the bottom to start fetching the next page. Roughly two
  /// rows, so the next batch is usually in place before the user reaches
  /// the end and the scroll never visibly stalls.
  static const double _prefetchExtent = 400;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase().trim());
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CategoryState>().loadAll();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _prefetchExtent) {
      // FeedState ignores this when a request is already in flight or the
      // list is exhausted, so firing it on every scroll frame is safe.
      context.read<FeedState>().loadNextPage(_feed);
    }
  }

  /// Keeps paging while a filter hides everything that has loaded.
  ///
  /// Filtering happens on the client, so a page of seven can contain no
  /// match and leave the user staring at "nothing here" while twenty more
  /// benefits sit unfetched on the server. Rather than claiming the list is
  /// empty, this walks forward a page at a time until something matches or
  /// the feed runs out.
  void _continueSearchIfNeeded(FeedState feedState, int visibleCount) {
    final filtering = _query.isNotEmpty || _category != null;
    if (!filtering || visibleCount > 0) return;
    if (!feedState.hasMore(_feed)) return;
    if (feedState.isLoadingMore(_feed) || feedState.isLoadingFirstPage(_feed)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FeedState>().loadNextPage(_feed);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<Hack> _filter(List<Hack> source) {
    final selected = _category;
    return source.where((h) {
      // A benefit may name its category by machine name or display label,
      // so matching is delegated to the category itself rather than done
      // with a string equality that only one of those spellings passes.
      final matchesCat = selected == null || selected.matches(h.category);
      final matchesQuery =
          _query.isEmpty ||
          h.title.toLowerCase().contains(_query) ||
          h.description.toLowerCase().contains(_query) ||
          h.category.toLowerCase().contains(_query);
      return matchesCat && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = Provider.of<CategoryState>(context);
    final categories = categoryState.all;
    final feedState = Provider.of<FeedState>(context);
    final feed = _feed;
    final hacks = _filter(feedState.itemsOf(feed));
    final loading = feedState.isLoadingFirstPage(feed);
    final loadingMore = feedState.isLoadingMore(feed);
    final hasMore = feedState.hasMore(feed);
    final error = feedState.errorOf(feed);

    _continueSearchIfNeeded(feedState, hacks.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.text('discover.title'),
                      style: AppText.sans(
                        25,
                        weight: FontWeight.w500,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    OutlinedSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.mdLg,
                      ),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.magnifyingGlass,
                              size: 16,
                              color: AppColors.textFaint,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: AppText.sans(
                                  13.5,
                                  color: AppColors.text,
                                ),
                                decoration: InputDecoration.collapsed(
                                  hintText: config.text('discover.searchHint'),
                                  hintStyle: AppText.sans(
                                    13.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    OutlinedSurface(
                      padding: const EdgeInsets.all(3),
                      child: SegmentedTabs(
                        labels: config.strings('discover.tabLabels'),
                        selectedIndex: _tabIndex,
                        onChanged: (i) {
                          setState(() => _tabIndex = i);
                          // Each tab keeps its own paging, so the newly
                          // shown one may still need its first page.
                          feedState.loadFirstPage(
                            i == 0 ? HackFeed.mine : HackFeed.circle,
                          );
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(0);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    // Hidden entirely until the categories arrive — an
                    // empty strip is less confusing than a lone "All" pill
                    // that looks like the only choice.
                    if (categories.isNotEmpty)
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          // +1 for the leading "All".
                          itemCount: categories.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 7),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return FilterPill(
                                label: 'All',
                                selected: _category == null,
                                onTap: () => setState(() => _category = null),
                              );
                            }
                            final c = categories[index - 1];
                            return FilterPill(
                              label: c.displayName,
                              selected: _category?.id == c.id,
                              onTap: () => setState(() => _category = c),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => feedState.refresh(feed),
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 2,
                          ),
                        )
                      : hacks.isEmpty
                      ? ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 56),
                              child: Column(
                                children: [
                                  if (loadingMore) ...[
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: AppColors.gold,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'Looking through more benefits…',
                                      style: AppText.sans(
                                        13,
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                  ] else ...[
                                    const Icon(
                                      PhosphorIconsRegular.magnifyingGlass,
                                      size: 30,
                                      color: AppColors.textGhost,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      error ??
                                          'Nothing here yet. Try another '
                                              'category.',
                                      textAlign: TextAlign.center,
                                      style: AppText.sans(
                                        13,
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                    if (error != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      TextButton(
                                        onPressed: () => feedState
                                            .loadFirstPage(feed, force: true),
                                        child: Text(
                                          'Retry',
                                          style: AppText.sans(
                                            13,
                                            color: AppColors.gold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.mdLg,
                            AppSpacing.xl,
                            108,
                          ),
                          // One extra row for the footer: the loading
                          // spinner, a retry, or the end-of-list marker.
                          itemCount: hacks.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.mdLg),
                          itemBuilder: (context, index) {
                            if (index == hacks.length) {
                              return _FeedFooter(
                                loading: loadingMore,
                                hasMore: hasMore,
                                error: error,
                                onRetry: () => feedState.loadNextPage(feed),
                              );
                            }
                            final hack = hacks[index];
                            return _HackRow(
                              hack: hack,
                              hue: AvatarHue
                                  .values[index % AvatarHue.values.length],
                              onOpen: () => Navigator.pushNamed(
                                context,
                                '/hack-detail',
                                arguments: hack,
                              ),
                              onLike: () => feedState.likeHack(hack.id),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row below the last benefit: a spinner while the next page loads, a
/// retry when a page failed, and a quiet marker once the feed is exhausted.
///
/// Rendering *something* here matters — an infinite list that simply stops
/// is indistinguishable from one that is still loading.
class _FeedFooter extends StatelessWidget {
  final bool loading;
  final bool hasMore;
  final String? error;
  final VoidCallback onRetry;

  const _FeedFooter({
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: GestureDetector(
            onTap: onRetry,
            child: Column(
              children: [
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: AppText.sans(12, color: AppColors.textFaint),
                ),
                const SizedBox(height: 6),
                Text('Retry', style: AppText.sans(12.5, color: AppColors.gold)),
              ],
            ),
          ),
        ),
      );
    }

    if (hasMore) return const SizedBox(height: AppSpacing.xl);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: MonoLabel(
          "THAT'S EVERYTHING",
          size: 9,
          letterSpacing: 1.6,
          color: AppColors.textGhost,
        ),
      ),
    );
  }
}

class _HackRow extends StatelessWidget {
  final Hack hack;
  final AvatarHue hue;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  const _HackRow({
    required this.hack,
    required this.hue,
    required this.onOpen,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final myCardNames = hack.myCardNames(
      Provider.of<AuthState>(context, listen: false).user.cards,
    );

    return OutlinedSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.mdLg,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                AvatarBubble(initials: hack.authorInitials, size: 32, hue: hue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hack.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(
                          12.5,
                          weight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // The rating, leading with the circle's score when
                      // there is one. This line used to read
                      // "VERIFIED · RECENTLY" — two hardcoded constants
                      // identical on every row, telling the reader nothing.
                      RatingBadge(
                        rating: hack.headlineRating,
                        fromCircle: hack.headlineIsCircle,
                        size: 9.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Categories run to "Forex / International"; without a cap
                // the chip grows past the card edge and pushes the author
                // block out with it.
                Container(
                  constraints: const BoxConstraints(maxWidth: 110),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    color: AppColors.elevated,
                  ),
                  child: MonoLabel(
                    hack.category,
                    size: 8.5,
                    letterSpacing: 1.2,
                    color: AppColors.textDim,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.mdLg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A benefit with no `name` falls back to its heading,
                  // which is a full sentence — capped so one long entry
                  // cannot make a card several screens tall.
                  Text(
                    hack.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      15.5,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                      height: 1.34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    hack.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      12.5,
                      color: AppColors.textDim,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            // The savings chip used to be unconstrained while a Spacer
            // fought a sibling Flexible for the leftovers. `savings` is
            // often a whole sentence ("3.5% saved on every international
            // transaction, with no cap"), so the row overflowed on nearly
            // every real benefit. The two info chips now share the space
            // that the fixed-width like button leaves.
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: MetaChip(
                          icon: PhosphorIconsRegular.trendUp,
                          iconColor: AppColors.teal,
                          background: AppColors.tealSurface,
                          label: hack.savings,
                          labelColor: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // Which of the reader's own cards this works with.
                      // Hidden entirely when none match, rather than
                      // claiming "All Credit Cards" as it used to.
                      if (myCardNames.isNotEmpty)
                        Flexible(
                          child: MetaChip(
                            icon: PhosphorIconsRegular.creditCard,
                            iconColor: AppColors.gold,
                            background: AppColors.elevated,
                            label: myCardNames.join(', '),
                            labelColor: const Color(0xFFB2B6CA),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: onLike,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5.6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      color: hack.liked
                          ? AppColors.gold.withValues(alpha: 0.14)
                          : AppColors.elevated,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hack.liked
                              ? PhosphorIconsFill.heart
                              : PhosphorIconsRegular.heart,
                          size: 13,
                          color: hack.liked
                              ? AppColors.gold
                              : AppColors.textDim,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${hack.likes}',
                          style: AppText.mono(
                            9.5,
                            ls: 0,
                            c: hack.liked ? AppColors.gold : AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
