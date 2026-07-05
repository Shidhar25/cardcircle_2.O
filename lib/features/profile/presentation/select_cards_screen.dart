import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';

class SelectCardsScreen extends StatefulWidget {
  const SelectCardsScreen({super.key});

  @override
  State<SelectCardsScreen> createState() => _SelectCardsScreenState();
}

class _SelectCardsScreenState extends State<SelectCardsScreen> {
  List<String> _banks = [];
  String? _selectedBank;
  List<Map<String, dynamic>> _availableCards = [];
  bool _fromProfile = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _fromProfile = args?['fromProfile'] ?? false;
      _initialized = true;
    }
  }
  
  // Track selected cards as maps of { 'card_id': id, 'bank_name': bank, 'card_name': name }
  final List<Map<String, dynamic>> _selectedCards = [];

  bool _loadingBanks = true;
  bool _loadingCards = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    final list = await ApiService.getBanks();
    if (mounted) {
      setState(() {
        if (list != null && list.isNotEmpty) {
          _banks = list;
          _selectedBank = list.first;
          _fetchCardsForBank(list.first);
        }
        _loadingBanks = false;
      });
    }
  }

  Future<void> _fetchCardsForBank(String bankName) async {
    setState(() {
      _loadingCards = true;
      _availableCards = [];
    });
    final list = await ApiService.getCardsByBank(bankName);
    if (mounted) {
      setState(() {
        if (list != null) {
          _availableCards = list;
        }
        _loadingCards = false;
      });
    }
  }

  bool _isCardSelected(String cardId) {
    return _selectedCards.any((c) => c['card_id'] == cardId);
  }

  void _toggleCard(Map<String, dynamic> card) {
    final cardId = card['id'] ?? '';
    final bankName = card['bank'] ?? '';
    final cardName = card['card_name'] ?? '';

    setState(() {
      if (_isCardSelected(cardId)) {
        _selectedCards.removeWhere((c) => c['card_id'] == cardId);
      } else {
        _selectedCards.add({
          'card_id': cardId,
          'bank_name': bankName,
          'card_name': cardName,
          'nickname': cardName,
          'is_primary': false,
        });
      }
    });
  }

  Future<void> _handleFinish() async {
    if (_saving) return;

    if (_selectedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one card to finalize your wallet setup.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final success = await ApiService.addUserCards(_selectedCards);
    
    setState(() {
      _saving = false;
    });

    if (mounted) {
      if (success) {
        final authState = Provider.of<AuthState>(context, listen: false);
        await authState.fetchUserCards();
        if (mounted) {
          if (_fromProfile) {
            Navigator.pop(context);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save cards. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSkip() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
                  if (_fromProfile)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48), // Spacer to balance Skip button
                  
                  if (!_fromProfile)
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
                        // Dot 2 (Completed)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Line 2
                        Container(
                          width: 30,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Dot 3 (Active)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),

                  if (!_fromProfile)
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
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!_fromProfile) ...[
              const Text(
                'Step 3 of 3 — Cards Setup',
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Select your credit cards',
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
                'Add the cards you currently carry. We will show you hacks and saving recommendations for them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bank Selector
            if (!_loadingBanks && _banks.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _banks.length,
                  itemBuilder: (context, index) {
                    final bank = _banks[index];
                    final isSelected = _selectedBank == bank;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          bank,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedBank = bank;
                            });
                            _fetchCardsForBank(bank);
                          }
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            // Cards Grid View
            Expanded(
              child: _loadingBanks || _loadingCards
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : (_availableCards.isEmpty
                      ? const Center(
                          child: Text(
                            'No cards available for this bank.',
                            style: TextStyle(color: AppColors.mutedForeground),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: _availableCards.length,
                          itemBuilder: (context, index) {
                            final card = _availableCards[index];
                            final id = card['id'] ?? '';
                            final cardName = card['card_name'] ?? '';
                            final network = card['network'] ?? '';
                            final isSelected = _isCardSelected(id);

                            return GestureDetector(
                              onTap: () => _toggleCard(card),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
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
                                        Text(
                                          network.toUpperCase(),
                                          style: TextStyle(
                                            color: isSelected ? AppColors.primary : AppColors.mutedForeground,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      cardName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
            const SizedBox(height: 16),
            // Finish Setup Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: _selectedCards.isNotEmpty && !_saving
                      ? const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: _selectedCards.isNotEmpty && !_saving ? null : const Color(0xFF21262D),
                ),
                child: ElevatedButton(
                  onPressed: _selectedCards.isNotEmpty && !_saving ? _handleFinish : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 19),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Finish Setup',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
