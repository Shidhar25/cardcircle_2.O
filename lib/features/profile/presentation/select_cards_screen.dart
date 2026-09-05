import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/card_material.dart';
import '../../../shared/widgets/card_plate.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 09 — Add cards: back + step indicator, search bar, a flat
/// toggleable list of cards, and a bottom summary bar with the "Enter
/// CardCircle" / "Add" GoldButton CTA.
///
/// This is the last of the three registration steps (profile, categories,
/// cards), and is also reachable from Profile to add another card later —
/// `fromProfile` only changes where the CTA returns to.
class SelectCardsScreen extends StatefulWidget {
  const SelectCardsScreen({super.key});

  @override
  State<SelectCardsScreen> createState() => _SelectCardsScreenState();
}

class _SelectCardsScreenState extends State<SelectCardsScreen> {
  List<Map<String, dynamic>> _banks = [];
  String? _selectedBankId;
  List<Map<String, dynamic>> _availableCards = [];
  bool _fromProfile = false;
  bool _initialized = false;

  final List<Map<String, dynamic>> _selectedCards = [];
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool _loadingBanks = true;
  bool _loadingCards = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _fromProfile = args?['fromProfile'] ?? false;
      _initialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
    _fetchBanks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Cards matching the current query.
  ///
  /// The catalog is fetched one bank at a time, so this filters within the
  /// selected bank rather than pretending to search the whole catalog —
  /// a cross-bank search would need a search parameter on the browse
  /// endpoint.
  List<Map<String, dynamic>> get _visibleCards {
    if (_query.isEmpty) return _availableCards;
    return _availableCards.where((card) {
      final info = (card['card'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = (info['name'] as String?)?.toLowerCase() ?? '';
      final issuer = (info['issuer'] as String?)?.toLowerCase() ?? '';
      final network = (info['network'] as String?)?.toLowerCase() ?? '';
      return name.contains(_query) ||
          issuer.contains(_query) ||
          network.contains(_query);
    }).toList();
  }

  String get _selectedBankName {
    for (final bank in _banks) {
      if (bank['id'] == _selectedBankId) return (bank['name'] as String?) ?? '';
    }
    return '';
  }

  Future<void> _fetchBanks() async {
    final list = await ApiService.getBanks();
    if (mounted) {
      setState(() {
        if (list != null && list.isNotEmpty) {
          _banks = list;
          final first = list.first;
          _selectedBankId = first['id'] as String?;
          final firstName = first['name'] as String?;
          if (firstName != null) {
            _fetchCardsForBank(firstName);
          }
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
    final bankId = card['bank_id'] ?? '';
    final cardInfo = (card['card'] as Map?)?.cast<String, dynamic>() ?? {};
    final cardName = cardInfo['name'] ?? '';

    setState(() {
      if (_isCardSelected(cardId)) {
        _selectedCards.removeWhere((c) => c['card_id'] == cardId);
      } else {
        _selectedCards.add({
          'card_id': cardId,
          'bank_name': bankId,
          'card_name': cardName,
          'nickname': cardName,
          'is_primary': false,
        });
      }
    });
  }

  Future<void> _handleFinish() async {
    if (_saving || _selectedCards.isEmpty) return;

    setState(() => _saving = true);
    final result = await ApiService.addUserCards(_selectedCards);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      AppSnackbar.error(
        context,
        result.display('Could not save your cards. Please try again.'),
      );
      return;
    }

    final authState = Provider.of<AuthState>(context, listen: false);
    await authState.fetchUserCards();
    if (!mounted) return;
    if (_fromProfile) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header: back, step label, progress bar, title/subtitle, search.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.mdLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back works in both entry paths: during
                        // registration it returns to the categories step,
                        // and from Profile it returns to Profile.
                        IconTile(
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 15,
                          onTap: () => Navigator.pop(context),
                        ),
                        if (!_fromProfile)
                          const MonoLabel(
                            'Step 3 of 3',
                            size: 9.5,
                            letterSpacing: 1.6,
                            color: AppColors.textFaint,
                          ),
                      ],
                    ),
                    if (!_fromProfile) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const StepProgressBar(currentStep: 3),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Add your cards',
                      style: AppText.sans(
                        27,
                        weight: FontWeight.w500,
                        color: AppColors.text,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Names only — no numbers, no bank login.',
                      style: AppText.sans(13, color: AppColors.textDim),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.mdLg,
                      ),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 16,
                              color: AppColors.textFaint,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                style: AppText.sans(
                                  13.5,
                                  color: AppColors.text,
                                ),
                                decoration: InputDecoration.collapsed(
                                  hintText: _selectedBankName.isEmpty
                                      ? 'Search cards'
                                      : 'Search $_selectedBankName cards',
                                  hintStyle: AppText.sans(
                                    13.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ),
                            ),
                            if (_query.isNotEmpty)
                              GestureDetector(
                                onTap: _searchController.clear,
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: AppColors.textFaint,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bank filter pills — needed because cards come from a live
              // per-bank catalog API rather than one flat fixture list.
              if (!_loadingBanks && _banks.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    itemCount: _banks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final bank = _banks[index];
                      final bankId = bank['id'] as String?;
                      final bankName = (bank['name'] as String?) ?? '';
                      final isSelected = _selectedBankId == bankId;
                      return FilterPill(
                        label: bankName,
                        selected: isSelected,
                        onTap: () {
                          if (bankId == null) return;
                          setState(() => _selectedBankId = bankId);
                          _fetchCardsForBank(bankName);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),

              // Card list.
              Expanded(
                child: _loadingBanks || _loadingCards
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 2,
                        ),
                      )
                    : (_visibleCards.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xxl,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _query.isEmpty
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.search_off_rounded,
                                      size: 28,
                                      color: AppColors.teal.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      _query.isEmpty
                                          ? "You've added every card from this bank."
                                          : 'No cards match "$_query" in $_selectedBankName.',
                                      textAlign: TextAlign.center,
                                      style: AppText.sans(
                                        13,
                                        color: AppColors.textDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                0,
                                AppSpacing.xl,
                                AppSpacing.mdLg,
                              ),
                              itemCount: _visibleCards.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) => _CardRow(
                                card: _visibleCards[index],
                                isSelected: _isCardSelected(
                                  _visibleCards[index]['id'] ?? '',
                                ),
                                onTap: () => _toggleCard(_visibleCards[index]),
                              ),
                            )),
              ),

              // Bottom summary + CTA.
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.mdLg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                    stops: [0.0, 0.34],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MonoLabel(
                          '${_selectedCards.length} CARD${_selectedCards.length == 1 ? '' : 'S'} ADDED',
                          size: 10,
                          letterSpacing: 1.3,
                          color: AppColors.textFaint,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GoldButton(
                      label: 'Enter CardCircle',
                      icon: Icons.arrow_forward,
                      enabled: _selectedCards.isNotEmpty,
                      loading: _saving,
                      onTap: _handleFinish,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool isSelected;
  final VoidCallback onTap;

  const _CardRow({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cardInfo =
        (card['card'] as Map?)?.cast<String, dynamic>() ?? {};
    final String name = cardInfo['name'] ?? '';
    final String issuer = cardInfo['issuer'] ?? '';
    final String cardType = cardInfo['card_type'] ?? '';
    final String network = cardInfo['network'] ?? '';

    // The catalog already carries every image this row needs; nothing is
    // resolved from bundled assets any more.
    String? url(String key) {
      final v = card[key];
      if (v is Map) {
        final u = v['url'];
        if (u is String && u.isNotEmpty) return u;
      }
      return null;
    }

    final String? imageUrl = url('image');
    final bool isCardSpecific =
        (card['image'] as Map?)?['is_card_specific'] == true;
    final String? bankLogoUrl = url('bank_logo');
    final String? networkLogoUrl = url('network_logo');

    final String bankId = (card['bank_id'] as String?) ?? '';

    return OutlinedSurface(
      onTap: onTap,
      background: isSelected
          ? AppColors.gold.withValues(alpha: 0.07)
          : AppColors.surface,
      borderColor: isSelected
          ? AppColors.gold.withValues(alpha: 0.55)
          : AppColors.border,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mdLg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _CardThumb(
            bankId: bankId,
            bankName: issuer,
            cardName: name,
            cardType: cardType,
            network: network,
            artworkUrl: imageUrl,
            isCardSpecific: isCardSpecific,
            bankLogoUrl: bankLogoUrl,
            networkLogoUrl: networkLogoUrl,
          ),
          const SizedBox(width: AppSpacing.mdLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.sans(
                    13.5,
                    weight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                MonoLabel(
                  issuer,
                  size: 9.5,
                  letterSpacing: 1.1,
                  color: AppColors.textFaint,
                  uppercase: false,
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.gold : AppColors.elevated,
            ),
            child: Icon(
              isSelected ? Icons.check : Icons.add,
              size: 15,
              color: isSelected ? AppColors.background : AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row leading thumbnail — a miniature of the wallet card face.
///
/// Deliberately the same widget the wallet uses, fed the same catalog URLs,
/// so the card you pick here is visibly the same object you then see in Your
/// Cards. It runs in compact mode: at 46px the product name is unreadable,
/// and the row already prints it alongside.
class _CardThumb extends StatelessWidget {
  final String bankId;
  final String bankName;
  final String cardName;
  final String cardType;
  final String network;
  final String? artworkUrl;
  final bool isCardSpecific;
  final String? bankLogoUrl;
  final String? networkLogoUrl;

  const _CardThumb({
    required this.bankId,
    required this.bankName,
    required this.cardName,
    required this.cardType,
    required this.network,
    required this.artworkUrl,
    required this.isCardSpecific,
    required this.bankLogoUrl,
    required this.networkLogoUrl,
  });

  static const double _height = 46;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: _height * kCardImageAspectRatio,
      child: CardPlate(
        artworkUrl: artworkUrl,
        isCardSpecific: isCardSpecific,
        bankLogoUrl: bankLogoUrl,
        name: cardName,
        networkLogoUrl: networkLogoUrl,
        network: network,
        bankId: bankId,
        bankName: bankName,
        material: cardMaterialFor(name: cardName, cardType: cardType),
        compact: true,
        height: _height,
      ),
    );
  }
}
