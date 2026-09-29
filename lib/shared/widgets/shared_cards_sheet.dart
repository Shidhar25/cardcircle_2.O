import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/services/api_service.dart';
import '../../core/services/contact_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'app_snackbar.dart';
import 'primitives.dart';

/// The cards a person you follow has shared with you, each with a call and
/// a WhatsApp button to ask them about it.
///
/// Lives on Circle's Following tab ("Cards" button) — the person is
/// already known here, unlike the Add Cards catalog's "who holds this
/// card?" search, so no lookup of *who* to contact is needed, only *how*.
/// The phone number and WhatsApp link still come from
/// `GET /follow/cards/{cardId}/review-requesters` rather than the shared-
/// cards list itself: that endpoint is what the backend actually gates on
/// `follow_card_permissions.is_allowed`, so a card this person shares but
/// has not (yet) allowed contact about would correctly come back empty
/// instead of this sheet inventing a phone number from somewhere it
/// shouldn't.
class SharedCardsSheet {
  const SharedCardsSheet._();

  static Future<void> show(
    BuildContext context, {
    required String followId,
    required String userId,
    required String name,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SharedCardsSheetBody(
        followId: followId,
        userId: userId,
        name: name,
      ),
    );
  }
}

class _SharedCardsSheetBody extends StatefulWidget {
  final String followId;
  final String userId;
  final String name;

  const _SharedCardsSheetBody({
    required this.followId,
    required this.userId,
    required this.name,
  });

  @override
  State<_SharedCardsSheetBody> createState() => _SharedCardsSheetBodyState();
}

class _SharedCardsSheetBodyState extends State<_SharedCardsSheetBody> {
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _cards = const [];

  /// Card ids currently resolving contact info for a call or a message, so
  /// that row can show a spinner and a second tap is ignored rather than
  /// firing a duplicate lookup.
  final Set<String> _resolvingIds = {};

  /// One lookup per card, not one per tap — `review-requesters` is the same
  /// answer for Call and Message on the same card, and re-fetching it for
  /// each icon a person presses would be a second round trip for
  /// information already in hand.
  final Map<String, Map<String, dynamic>?> _contactCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ApiService.getSharedCards(widget.followId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list == null) {
        _loadError = "Could not load ${widget.name}'s cards.";
      } else {
        _cards = list;
      }
    });
  }

  static String? _cardIdOf(Map<String, dynamic> card) {
    for (final key in ['card_id', 'catalog_card_id', 'id']) {
      final v = card[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  /// The review-requesters row for [widget.userId] on [cardId], from cache
  /// when this card's icons were already tapped once this sheet.
  ///
  /// The endpoint can list more than one holder of the same card, so this
  /// matches by `user_id` rather than assuming the first row is the person
  /// this sheet is about — and returns null, not a stranger's contact,
  /// when this exact person is not (or no longer) in the list.
  Future<Map<String, dynamic>?> _resolveContact(String cardId) async {
    if (_contactCache.containsKey(cardId)) return _contactCache[cardId];

    final list = await ApiService.getReviewRequesters(cardId);
    Map<String, dynamic>? match;
    if (list != null) {
      for (final row in list) {
        if ((row['user_id'] ?? '').toString() == widget.userId) {
          match = row;
          break;
        }
      }
    }
    _contactCache[cardId] = match;
    return match;
  }

  Future<void> _handleCall(Map<String, dynamic> card) async {
    final cardId = _cardIdOf(card);
    if (cardId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _resolvingIds.add(cardId));
    final contact = await _resolveContact(cardId);
    if (!mounted) return;
    setState(() => _resolvingIds.remove(cardId));

    final phone = (contact?['phone_number'] ?? '').toString();
    if (phone.isEmpty) {
      messenger.showError(
        "${widget.name} hasn't made this card's contact info available.",
      );
      return;
    }

    final opened = await ContactLauncher.call(phone);
    if (!opened && mounted) messenger.showError('Could not open the phone dialer.');
  }

  Future<void> _handleMessage(Map<String, dynamic> card) async {
    final cardId = _cardIdOf(card);
    if (cardId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _resolvingIds.add(cardId));
    final contact = await _resolveContact(cardId);
    if (!mounted) return;
    setState(() => _resolvingIds.remove(cardId));

    final url = (contact?['whatsapp_url'] ?? '').toString();
    if (url.isEmpty) {
      messenger.showError(
        "${widget.name} hasn't made this card's contact info available.",
      );
      return;
    }

    final opened = await ContactLauncher.whatsapp(url);
    if (!opened && mounted) messenger.showError('Could not open WhatsApp.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(
              '${widget.name.toUpperCase()} SHARES',
              size: 10,
              letterSpacing: 2,
              color: AppColors.textDim,
            ),
            const SizedBox(height: AppSpacing.lg),
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
      );
    }

    if (_loadError != null) {
      return Text(_loadError!, style: AppText.sans(13, color: AppColors.textDim));
    }

    if (_cards.isEmpty) {
      return Text(
        '${widget.name} has not shared any cards with you.',
        style: AppText.sans(13, color: AppColors.textDim),
      );
    }

    return Column(
      children: [
        for (final card in _cards)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SharedCardRow(
              name: (card['card_name'] ?? 'Card').toString(),
              busy: () {
                final id = _cardIdOf(card);
                return id != null && _resolvingIds.contains(id);
              }(),
              onCall: () => _handleCall(card),
              onMessage: () => _handleMessage(card),
            ),
          ),
      ],
    );
  }
}

class _SharedCardRow extends StatelessWidget {
  final String name;
  final bool busy;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  const _SharedCardRow({
    required this.name,
    required this.busy,
    required this.onCall,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          PhosphorIconsRegular.creditCard,
          size: 16,
          color: AppColors.gold,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(name, style: AppText.sans(13.5, color: AppColors.text)),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppColors.gold,
              ),
            ),
          )
        else ...[
          _IconAction(icon: PhosphorIconsFill.phone, onTap: onCall),
          const SizedBox(width: AppSpacing.sm),
          _IconAction(icon: PhosphorIconsFill.whatsappLogo, onTap: onMessage),
        ],
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
          ),
          child: Icon(icon, size: 15, color: AppColors.gold),
        ),
      ),
    );
  }
}
