import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../state/category_state.dart';
import '../../../shared/widgets/neo_pop_button.dart';
import '../../../shared/widgets/gritty_background.dart';

class SelectTagsScreen extends StatefulWidget {
  const SelectTagsScreen({super.key});

  @override
  State<SelectTagsScreen> createState() => _SelectTagsScreenState();
}

class _SelectTagsScreenState extends State<SelectTagsScreen> {
  final Set<String> _selectedCategoryIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The catalogue is shared with Benefits and Profile, so it is fetched
    // once into CategoryState rather than separately per screen. The icon
    // map and colour parser that used to live here moved onto
    // [SpendCategory] for the same reason.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CategoryState>().loadAll();
    });
  }

  Future<void> _handleNext() async {
    if (_saving) return;

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one category to personalize your feed.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final result = await ApiService.tagCategories(
      _selectedCategoryIds.toList(),
    );

    setState(() {
      _saving = false;
    });

    if (!mounted) return;
    if (result.ok) {
      // Reflect the new selection immediately, so Profile's chips are right
      // without waiting for a refetch.
      final categoryState = context.read<CategoryState>();
      categoryState.setMine(
        categoryState.all.where((c) => _selectedCategoryIds.contains(c.id)),
      );
      Navigator.pushNamed(context, '/select-cards');
      return;
    }
    AppSnackbar.error(
      context,
      result.display('Could not save your preferences. Please try again.'),
    );
  }

  void _handleSkip() {
    Navigator.pushNamed(context, '/select-cards');
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = Provider.of<CategoryState>(context);
    final categories = categoryState.all;
    final loading = categoryState.isLoading && categories.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconTile(
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 15,
                          onTap: () => Navigator.pop(context),
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
                    const SizedBox(height: 12),
                    const StepProgressBar(currentStep: 2),
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
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : categories.isEmpty
                    // Reached only when the fetch failed: saying so beats an
                    // empty grid that looks like there is nothing to pick.
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Could not load categories.',
                                style: TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    categoryState.loadAll(force: true),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.35,
                            ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final id = cat.id;
                          final name = cat.displayName;
                          final desc = cat.description;

                          final color = cat.color(AppColors.primary);
                          final icon = cat.icon;
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(
                                        icon,
                                        color: isSelected
                                            ? color
                                            : AppColors.mutedForeground,
                                        size: 24,
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: color,
                                          size: 20,
                                        ),
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
                  onPressed: _selectedCategoryIds.isNotEmpty && !_saving
                      ? _handleNext
                      : null,
                  isLoading: _saving,
                  enabled: _selectedCategoryIds.isNotEmpty && !_saving,
                  depth: 6.0,
                  child: NeoPopButtonText(
                    'Next Step',
                    color: _selectedCategoryIds.isNotEmpty && !_saving
                        ? AppColors.darkText
                        : Colors.black,
                    icon: Icons.arrow_forward_rounded,
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
