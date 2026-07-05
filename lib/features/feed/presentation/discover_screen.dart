import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../state/feed_state.dart';
import '../../../shared/widgets/hack_card.dart';
import '../../../shared/widgets/offer_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _activeTab = 'hacks'; // 'hacks' | 'offers'
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = ['All', 'Cashback', 'Rewards', 'Travel', 'Dining', 'Shopping'];

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final feedState = Provider.of<FeedState>(context);

    // Filter hacks
    final filteredHacks = feedState.hacks.where((h) {
      final matchesCat = _selectedCategory == 'All' || h.category == _selectedCategory;
      final matchesSearch = h.title.toLowerCase().contains(_searchQuery) ||
          h.description.toLowerCase().contains(_searchQuery) ||
          h.cardName.toLowerCase().contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    // Filter offers
    final filteredOffers = feedState.offers.where((o) {
      final matchesCat = _selectedCategory == 'All' || o.category == _selectedCategory;
      final matchesSearch = o.merchant.toLowerCase().contains(_searchQuery) ||
          o.description.toLowerCase().contains(_searchQuery) ||
          o.cardName.toLowerCase().contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Row
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
                          hintText: 'Search cards, brands, categories...',
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

            // Tab toggles (Hacks vs Offers)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 'hacks' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Savings Hacks',
                            style: TextStyle(
                              color: _activeTab == 'hacks'
                                  ? AppColors.background
                                  : AppColors.mutedForeground,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 'offers' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Deals & Offers',
                            style: TextStyle(
                              color: _activeTab == 'offers'
                                  ? AppColors.background
                                  : AppColors.mutedForeground,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal categories scroll list
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
            const SizedBox(height: 6),

            // Tab contents
            Expanded(
              child: _activeTab == 'hacks'
                  ? (filteredHacks.isEmpty
                      ? _buildEmptyState('No hacks match your search.')
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filteredHacks.length,
                          itemBuilder: (context, idx) {
                            final hack = filteredHacks[idx];
                            return HackCard(
                              hack: hack,
                              onLike: () => feedState.likeHack(hack.id),
                            );
                          },
                        ))
                  : (filteredOffers.isEmpty
                      ? _buildEmptyState('No offers match your search.')
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filteredOffers.length,
                          itemBuilder: (context, idx) {
                            return OfferCard(offer: filteredOffers[idx]);
                          },
                        )),
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
            style: const TextStyle(color: AppColors.mutedForeground, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
