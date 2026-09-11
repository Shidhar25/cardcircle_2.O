import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/network_catalog.dart';
import 'primitives.dart';

/// What the user picked for one card: the network and, when the network has
/// them, the variant. Both are sent as the catalog's canonical names — the
/// backend resolves them again, but sending the exact spelling means the
/// saved card matches what the user saw here.
class NetworkChoice {
  final String network;
  final String? variant;

  const NetworkChoice({required this.network, this.variant});

  /// "Visa · Signature", or just the network when there's no variant.
  String get label => variant == null ? network : '$network · $variant';
}

/// Asks which network and variant a card is on, as a bottom sheet shown
/// while adding that card.
///
/// The catalog is server-owned, so this renders whatever `GET /card-networks`
/// returned rather than a hardcoded list. A network with no variants
/// confirms as soon as it's tapped; one with variants asks for the variant
/// too, since that's the part the card face doesn't tell us.
class NetworkPickerSheet extends StatefulWidget {
  final String cardName;
  final List<NetworkOption> networks;

  /// Pre-selected network name, e.g. what the card catalog already claims.
  final String? initialNetwork;

  const NetworkPickerSheet({
    super.key,
    required this.cardName,
    required this.networks,
    this.initialNetwork,
  });

  /// Shows the sheet; returns null when the user backs out, in which case
  /// the card is left unselected.
  static Future<NetworkChoice?> show(
    BuildContext context, {
    required String cardName,
    required List<NetworkOption> networks,
    String? initialNetwork,
  }) {
    return showModalBottomSheet<NetworkChoice>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NetworkPickerSheet(
        cardName: cardName,
        networks: networks,
        initialNetwork: initialNetwork,
      ),
    );
  }

  @override
  State<NetworkPickerSheet> createState() => _NetworkPickerSheetState();
}

class _NetworkPickerSheetState extends State<NetworkPickerSheet> {
  NetworkOption? _network;
  NetworkVariant? _variant;

  @override
  void initState() {
    super.initState();
    // The catalog card usually names its network already ("Visa Signature"),
    // so pre-select it and leave the user only the variant to answer.
    final hint = widget.initialNetwork?.toLowerCase();
    if (hint != null && hint.isNotEmpty) {
      for (final n in widget.networks) {
        if (hint.contains(n.name.toLowerCase())) {
          _network = n;
          break;
        }
      }
    }
  }

  bool get _complete =>
      _network != null && (_network!.variants.isEmpty || _variant != null);

  void _confirm() {
    final network = _network;
    if (network == null || !_complete) return;
    Navigator.pop(
      context,
      NetworkChoice(network: network.name, variant: _variant?.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variants = _network?.variants ?? const <NetworkVariant>[];

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
            'Which network is it on?',
            style: AppText.sans(
              19,
              weight: FontWeight.w500,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.cardName,
            style: AppText.sans(12.5, color: AppColors.textDim),
          ),
          const SizedBox(height: AppSpacing.lg),
          const MonoLabel(
            'NETWORK',
            size: 9.5,
            letterSpacing: 1.4,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final n in widget.networks)
                FilterPill(
                  label: n.name,
                  selected: _network?.name == n.name,
                  onTap: () => setState(() {
                    _network = n;
                    _variant = null;
                  }),
                ),
            ],
          ),
          if (variants.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const MonoLabel(
              'VARIANT',
              size: 9.5,
              letterSpacing: 1.4,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Scrolls on its own: RuPay alone has enough variants to push
            // the CTA off a short screen.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.28,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final v in variants)
                      FilterPill(
                        label: v.name,
                        selected: _variant?.name == v.name,
                        onTap: () => setState(() => _variant = v),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          GoldButton(
            label: 'Add card',
            icon: Icons.check,
            enabled: _complete,
            onTap: _confirm,
          ),
        ],
      ),
    );
  }
}
