import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/neo_pop_button.dart';


class CommunityItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int members;
  final bool isJoined;
  final List<Color> gradientColors;

  CommunityItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.members,
    required this.isJoined,
    required this.gradientColors,
  });
}

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Cashback', 'Premium', 'Travel', 'Dining', 'Students'];

  final List<CommunityItem> _allCommunities = [
    CommunityItem(
      id: 'c1',
      name: 'Cashback Collectors',
      description: 'Maximize raw cash returns. Share reward optimizations, dining deals, and utility cashbacks.',
      emoji: '💰',
      members: 14200,
      isJoined: true,
      gradientColors: [const Color(0xFF134E5E), const Color(0xFF71B280)],
    ),
    CommunityItem(
      id: 'c2',
      name: 'Lounge & Luxury Travelers',
      description: 'Lounge access policies, airmiles multipliers, priority passes, and hotel credit stacks.',
      emoji: '✈️',
      members: 8900,
      isJoined: true,
      gradientColors: [const Color(0xFF0F3460), const Color(0xFF533483)],
    ),
    CommunityItem(
      id: 'c3',
      name: 'Premium Metal Cards Club',
      description: 'For owners of Infinia, Magnus, Reserve. Discuss high-net-worth invite-only offerings.',
      emoji: '💳',
      members: 3400,
      isJoined: false,
      gradientColors: [const Color(0xFF7B5B00), const Color(0xFFC89B00)],
    ),
    CommunityItem(
      id: 'c4',
      name: 'Foodies & Diners Club',
      description: 'EazyDiner, Swiggy Dineout, and Zomato Gold credit card discounts compared.',
      emoji: '🍔',
      members: 6700,
      isJoined: false,
      gradientColors: [const Color(0xFF23074D), const Color(0xFF8B2FC9)],
    ),
    CommunityItem(
      id: 'c5',
      name: 'Young Savers (Students)',
      description: 'Entry-level, lifetime-free credit card hacks. Build score early with zero fees.',
      emoji: '🎓',
      members: 11200,
      isJoined: false,
      gradientColors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
    ),
  ];

  late List<CommunityItem> _communities;

  @override
  void initState() {
    super.initState();
    _communities = List.from(_allCommunities);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleJoin(String id) {
    setState(() {
      _communities = _communities.map((c) {
        if (c.id == id) {
          return CommunityItem(
            id: c.id,
            name: c.name,
            description: c.description,
            emoji: c.emoji,
            members: c.members + (c.isJoined ? -1 : 1),
            isJoined: !c.isJoined,
            gradientColors: c.gradientColors,
          );
        }
        return c;
      }).toList();
    });
  }

  String _formatCount(int num) {
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Spotlight community (first joined community)
    final spotlightIndex = _communities.indexWhere((c) => c.isJoined);
    final CommunityItem? featured = spotlightIndex != -1 ? _communities[spotlightIndex] : null;
    final bool showFeatured = featured != null && _searchQuery.isEmpty && _selectedCategory == 'All';

    // Filters list
    final filteredList = _communities.where((c) {
      final matchesSearch = c.name.toLowerCase().contains(_searchQuery) ||
          c.description.toLowerCase().contains(_searchQuery);

      bool matchesCat = true;
      if (_selectedCategory != 'All') {
        if (_selectedCategory == 'Cashback') matchesCat = c.name.contains('Cashback');
        if (_selectedCategory == 'Premium') matchesCat = c.name.contains('Premium');
        if (_selectedCategory == 'Travel') matchesCat = c.name.contains('Travel') || c.name.contains('Luxury');
        if (_selectedCategory == 'Dining') matchesCat = c.name.contains('Foodies') || c.name.contains('Diners');
        if (_selectedCategory == 'Students') matchesCat = c.name.contains('Young') || c.name.contains('Savers');
      }

      // Hide the spotlight from the bottom listing if it's currently featured
      final isSpotlight = featured != null && c.id == featured.id && showFeatured;

      return matchesSearch && matchesCat && !isSpotlight;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 20, color: AppColors.mutedForeground),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Search communities...',
                          hintStyle: TextStyle(color: AppColors.mutedForeground, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: const Icon(Icons.close, size: 18, color: AppColors.mutedForeground),
                      ),
                  ],
                ),
              ),
            ),

            // Horizontal categories row
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: _categories.length,
                itemBuilder: (context, catIdx) {
                  final cat = _categories[catIdx];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.mutedForeground,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Main listing
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // Featured Spotlight Card
                  if (showFeatured) ...[
                    Container(
                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [...featured.gradientColors, AppColors.background],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FEATURED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              featured.emoji,
                              style: const TextStyle(fontSize: 36),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              featured.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              featured.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  '${_formatCount(featured.members)} members',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Colors.white70,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.green),
                                const SizedBox(width: 4),
                                const Text(
                                  'Joined',
                                  style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            NeoPopButton(
                              onPressed: () {},
                              style: NeoPopButtonStyle.flat,
                              color: Colors.white,
                              shadowColor: const Color(0xFF999999),
                              depth: 4.0,
                              fullWidth: false,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              child: const Text(
                                'Open Lounge 💬',
                                style: TextStyle(
                                  color: Color(0xFF050505),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'Explore Communities',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  // Feed list of groups
                  if (filteredList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Column(
                          children: const [
                            Icon(Icons.hourglass_empty_rounded, size: 40, color: AppColors.mutedForeground),
                            SizedBox(height: 12),
                            Text(
                              'No matching communities.',
                              style: TextStyle(color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(filteredList.length, (idx) {
                      final item = filteredList[idx];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.elevated,
                                border: Border.all(color: AppColors.border, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: AppColors.mutedForeground,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(
                                        '${_formatCount(item.members)} members',
                                        style: const TextStyle(
                                          color: AppColors.mutedForeground,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (item.isJoined) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: AppColors.mutedForeground,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.green),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Joined',
                                          style: TextStyle(
                                            color: AppColors.green,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            NeoPopButton(
                              onPressed: () => _toggleJoin(item.id),
                              style: NeoPopButtonStyle.flat,
                              color: item.isJoined ? Colors.transparent : Colors.white,
                              shadowColor: item.isJoined ? Colors.transparent : const Color(0xFF999999),
                              depth: item.isJoined ? 0 : 3.0,
                              fullWidth: false,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Text(
                                item.isJoined ? 'Leave' : 'Join',
                                style: TextStyle(
                                  color: item.isJoined ? AppColors.mutedForeground : const Color(0xFF050505),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
