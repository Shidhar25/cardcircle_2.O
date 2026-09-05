import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/models.dart';
import '../models/card_material.dart';
import 'card_plate.dart';
import 'primitives.dart';

/// Fan-out card stack shared by Home and Profile (CardCircle.html's `stack`
/// block, used identically on both screens): 15px collapsed offset / 208px
/// expanded, `Curves.easeOutCubic` 350ms (FLUTTER_HANDOFF.md §4).
class CardStack extends StatelessWidget {
  final List<CreditCard> cards;
  final bool fanned;

  const CardStack({super.key, required this.cards, required this.fanned});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return OutlinedSurface(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            'No cards added yet.',
            style: AppText.sans(13, color: AppColors.textDim),
          ),
        ),
      );
    }

    final int n = cards.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double faceHeight = constraints.maxWidth / kCardImageAspectRatio;
        final double fanGap = faceHeight + 12;
        final double stackHeight = fanned
            ? faceHeight + (n - 1) * fanGap
            : faceHeight + (n - 1).clamp(0, 2) * 15;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          height: stackHeight,
          child: Stack(
            children: List.generate(n, (i) {
              final card = cards[i];
              final double offset = fanned ? i * fanGap : i * 15.0;
              final double scale = fanned ? 1.0 : (1 - i * 0.045);
              final double opacity = fanned
                  ? 1.0
                  : (i > 2 ? 0.0 : 1 - i * 0.12);

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                key: ValueKey(card.id),
                left: 0,
                right: 0,
                top: offset,
                child: IgnorePointer(
                  ignoring: i != n - 1 && !fanned,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: CardFacePanel(card: card, height: faceHeight),
                    ),
                  ),
                ),
              );
            }).reversed.toList(),
          ),
        );
      },
    );
  }
}

/// One card face.
///
/// Everything visible comes from the backend: the artwork is `image.url`,
/// the issuer mark is `bank_logo.url`, the network mark is
/// `network_logo.url`. Nothing is bundled, so adding a bank server-side is
/// enough for its cards to render correctly.
///
/// The generated material plate ([cardMaterialFor], chosen by tier rather
/// than brand) remains underneath as the fallback for cards the catalog has
/// no image for, and shows through if an image URL fails.
class CardFacePanel extends StatelessWidget {
  final CreditCard card;
  final double height;

  const CardFacePanel({super.key, required this.card, this.height = 196});

  @override
  Widget build(BuildContext context) {
    return CardPlate(
      artworkUrl: card.imageUrl,
      isCardSpecific: card.isCardSpecific,
      bankLogoUrl: card.bankLogoUrl,
      name: card.name,
      networkLogoUrl: card.networkLogoUrl,
      network: card.network,
      bankId: card.bankId,
      bankName: card.bank,
      material: cardMaterialFor(name: card.name, cardType: card.category),
      height: height,
    );
  }
}
