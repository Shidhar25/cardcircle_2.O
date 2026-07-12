import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/neo_pop_button.dart';

class SelectTagsScreen extends StatefulWidget {
  const SelectTagsScreen({super.key});

  @override
  State<SelectTagsScreen> createState() => _SelectTagsScreenState();
}

class _SelectTagsScreenState extends State<SelectTagsScreen> {
  List<Map<String, dynamic>> _categories = [];
  final Set<String> _selectedCategoryIds = {};
  bool _loading = true;
  bool _saving = false;

  static const Map<String, IconData> _iconMap = {
    'utensils': Icons.restaurant_rounded,
    'shopping-cart': Icons.shopping_cart_rounded,
    'shopping-bag': Icons.shopping_bag_rounded,
    'car': Icons.directions_car_rounded,
    'film': Icons.movie_creation_rounded,
    'plane': Icons.flight_takeoff_rounded,
    'heart': Icons.favorite_rounded,
    'zap': Icons.bolt_rounded,
    'book': Icons.menu_book_rounded,
    'shield': Icons.security_rounded,
    'trending-up': Icons.trending_up_rounded,
    'file-text': Icons.description_rounded,
    'scissors': Icons.content_cut_rounded,
    'gift': Icons.card_giftcard_rounded,
    'more-horizontal': Icons.more_horiz_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final list = await ApiService.getCategories();
    if (mounted) {
      setState(() {
        if (list != null) {
          _categories = list;
        }
        _loading = false;
      });
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppColors.primary;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _handleNext() async {
    if (_saving) return;
    
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category to personalize your feed.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final success = await ApiService.tagCategories(_selectedCategoryIds.toList());
    
    setState(() {
      _saving = false;
    });

    if (mounted) {
      if (success) {
        Navigator.pushNamed(context, '/select-cards');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preferences. Please check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSkip() {
    Navigator.pushNamed(context, '/select-cards');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer to balance Skip button
                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Dot 1 (Completed)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Line 1
                      Container(
                        width: 30,
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Dot 2 (Active)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Line 2
                      Container(
                        width: 30,
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Dot 3 (Inactive)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _handleSkip,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Step 2 of 3 — Personalize',
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'What do you spend on?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Select categories to personalize your hacks and card recommendation views.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final id = cat['categoryId'] ?? '';
                        final name = cat['displayName'] ?? '';
                        final desc = cat['description'] ?? '';
                        final iconKey = cat['icon'] ?? '';
                        final colorHex = cat['color'] ?? '';
                        
                        final color = _parseColor(colorHex);
                        final icon = _iconMap[iconKey] ?? Icons.category_rounded;
                        final isSelected = _selectedCategoryIds.contains(id);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCategoryIds.remove(id);
                              } else {
                                _selectedCategoryIds.add(id);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : AppColors.border,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(icon, color: isSelected ? color : AppColors.mutedForeground, size: 24),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.mutedForeground,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: NeoPopButton.primary(
                onPressed: _selectedCategoryIds.isNotEmpty && !_saving ? _handleNext : null,
                isLoading: _saving,
                enabled: _selectedCategoryIds.isNotEmpty && !_saving,
                depth: 6.0,
                child: const NeoPopButtonText(
                  'Next Step',
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
