import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/card_network.dart';
import '../models/card_variant.dart';
import 'primitives.dart';

/// Asks which version of a card the user actually holds, as a bottom sheet
/// shown while adding it.
///
/// The catalog groups a product by name — one "Millennia" carrying the Visa
/// Signature, Mastercard and Diners Club cards it was issued as. They are
/// different cards with different benefits, so the one being added has to be
/// named. Every option here is a real catalog row the server sent for this
/// card; nothing is assembled client-side, and the choice resolves to that
/// row's `card_id`.
///
/// A card with a single variant never reaches this sheet — see
/// [CardVariantPickerSheet.show].
class CardVariantPickerSheet extends StatefulWidget {
  final String cardName;
  final List<CardVariantOption> variants;

  /// Pre-selected variant's `card_id`, e.g. the group's `default_variant_id`.
  final String? initialCardId;

  const CardVariantPickerSheet({
    super.key,
    required this.cardName,
    required this.variants,
    this.initialCardId,
  });

  /// Shows the sheet; returns null when the user backs out, in which case
  /// the card is left unselected.
  ///
  /// A question with one possible answer is not worth asking, so a card with
  /// a single variant resolves to it immediately without the sheet.
  static Future<CardVariantOption?> show(
    BuildContext context, {
    required String cardName,
    required List<CardVariantOption> variants,
    String? initialCardId,
  }) {
    if (variants.isEmpty) return Future<CardVariantOption?>.value();
    if (variants.length == 1) {
      return Future<CardVariantOption?>.value(variants.first);
    }
    return showModalBottomSheet<CardVariantOption>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CardVariantPickerSheet(
        cardName: cardName,
        variants: variants,
        initialCardId: initialCardId,
      ),
    );
  }

  @override
  State<CardVariantPickerSheet> createState() => _CardVariantPickerSheetState();
}

class _CardVariantPickerSheetState extends State<CardVariantPickerSheet> {
  CardVariantOption? _choice;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCardId;
    if (initial != null && initial.isNotEmpty) {
      for (final v in widget.variants) {
        if (v.cardId == initial) {
          _choice = v;
          break;
        }
      }
    }
  }

  void _confirm() {
    final choice = _choice;
    if (choice == null) return;
    Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.mdLg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Which one do you hold?',
            style: AppText.sans(
              19,
              weight: FontWeight.w500,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.cardName} comes on '
            '${widget.variants.length} networks',
            style: AppText.sans(12.5, color: AppColors.textDim),
          ),
          const SizedBox(height: AppSpacing.lg),
          // A bank with many editions of one product scrolls inside the
          // sheet rather than pushing the CTA off a short screen.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < widget.variants.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    _VariantTile(
                      variant: widget.variants[i],
                      selected: _choice?.cardId == widget.variants[i].cardId,
                      onTap: () =>
                          setState(() => _choice = widget.variants[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GoldButton(
            label: 'Add card',
            icon: Icons.check,
            enabled: _choice != null,
            onTap: _confirm,
          ),
        ],
      ),
    );
  }
}

/// One variant as a full-width row rather than a pill: these carry a network
/// mark and a card type, which a pill has nowhere to put.
class _VariantTile extends StatelessWidget {
  final CardVariantOption variant;
  final bool selected;
  final VoidCallback onTap;

  const _VariantTile({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final network = CardNetwork.parse(variant.network);
    final logo = network?.logoUrl;

    return OutlinedSurface(
      onTap: onTap,
      background: selected
          ? AppColors.gold.withValues(alpha: 0.07)
          : AppColors.surface,
      borderColor: selected
          ? AppColors.gold.withValues(alpha: 0.55)
          : AppColors.border,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mdLg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 22,
            child: logo == null
                ? null
                // RuPay and anything unrecognised have no artwork on S3, so
                // the label below carries the network on its own.
                : Image.network(
                    logo,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant.label,
                  style: AppText.sans(
                    13.5,
                    weight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                if (variant.cardType.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    variant.cardType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(11, color: AppColors.textFaint),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.border,
                width: 1.5,
              ),
              color: selected ? AppColors.gold : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: AppColors.background)
                : null,
          ),
        ],
      ),
    );
  }
}
