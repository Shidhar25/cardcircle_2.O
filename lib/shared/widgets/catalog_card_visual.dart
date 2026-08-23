import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Loads a network image and, if it turns out to be portrait (taller than
/// wide — common for card-specific product shots), rotates it 90° so it
/// displays landscape and fills the slot edge-to-edge like the rest of the
/// deck, instead of being cropped oddly or leaving side gaps.
class _AutoOrientedNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const _AutoOrientedNetworkImage({required this.url, this.fit = BoxFit.cover});

  @override
  State<_AutoOrientedNetworkImage> createState() => _AutoOrientedNetworkImageState();
}

class _AutoOrientedNetworkImageState extends State<_AutoOrientedNetworkImage> {
  bool _isPortrait = false;
  ImageStream? _stream;
  late final ImageStreamListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener(_onImageResolved, onError: (error, stack) {});
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AutoOrientedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stream?.removeListener(_listener);
      _resolve();
    }
  }

  void _resolve() {
    final stream = NetworkImage(widget.url).resolve(const ImageConfiguration());
    _stream = stream;
    stream.addListener(_listener);
  }

  void _onImageResolved(ImageInfo info, bool synchronousCall) {
    final portrait = info.image.height > info.image.width;
    if (!mounted) return;
    if (portrait != _isPortrait) {
      setState(() => _isPortrait = portrait);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      widget.url,
      fit: widget.fit,
      errorBuilder: (context, error, stack) => Container(color: AppColors.card),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.card,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        );
      },
    );

    if (!_isPortrait) {
      return image;
    }

    // Rotate 90° while swapping the box dimensions the image lays out
    // against, so the cover-fitted content fills the original (unswapped)
    // slot completely once rotated back — no letterboxing on the sides.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Transform.rotate(
          angle: math.pi / 2,
          child: SizedBox(
            width: constraints.maxHeight,
            height: constraints.maxWidth,
            child: image,
          ),
        );
      },
    );
  }
}

/// Renders a credit card entry coming from the banks/cards catalog API.
///
/// When `image.is_card_specific` is true, the API-provided image already
/// depicts the exact card, so it is shown as-is. When false, the image is a
/// generic bank card background, so the bank logo and network logo are
/// overlaid on top of it to approximate the real card look.
class CatalogCardVisual extends StatelessWidget {
  final Map<String, dynamic> cardData;
  final bool isSelected;

  const CatalogCardVisual({
    super.key,
    required this.cardData,
    this.isSelected = false,
  });

  String? _asUrl(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map) {
      final url = value['url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> card = (cardData['card'] as Map?)?.cast<String, dynamic>() ?? {};
    final String cardName = card['name'] ?? '';
    final String issuer = card['issuer'] ?? '';

    final Map<String, dynamic> imageInfo = (cardData['image'] as Map?)?.cast<String, dynamic>() ?? {};
    final String? imageUrl = _asUrl(imageInfo['url'] ?? cardData['image']);
    final bool isCardSpecific = imageInfo['is_card_specific'] == true;

    final String? bankLogoUrl = _asUrl(cardData['bank_logo']);
    final String? networkLogoUrl = _asUrl(cardData['network_logo']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base card artwork. Generic bank backgrounds are cropped to
            // fill the slot (BoxFit.cover); card-specific product shots are
            // shown in full (BoxFit.contain, auto-rotated if portrait) so
            // nothing gets cut off or squeezed.
            Container(
              color: AppColors.card,
              child: imageUrl != null
                  ? _AutoOrientedNetworkImage(
                      url: imageUrl,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),

            // Darken slightly for text legibility on generic backgrounds
            if (!isCardSpecific)
              Container(color: Colors.black.withValues(alpha: 0.25)),

            // Bottom scrim for card-specific shots so the name stays
            // legible over the product image without a full darken.
            if (isCardSpecific)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),

            // Bank logo, top-left overlay (only meaningful for generic cards)
            if (!isCardSpecific && bankLogoUrl != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Image.network(
                    bankLogoUrl,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Network logo, bottom-right overlay
            if (!isCardSpecific && networkLogoUrl != null)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Image.network(
                    networkLogoUrl,
                    height: 12,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Card name / issuer label. On generic backgrounds it sits above
            // the network/bank badges; on card-specific shots it sits in the
            // bottom scrim since the artwork itself has no printed name.
            Positioned(
              left: 10,
              right: 10,
              bottom: !isCardSpecific && (bankLogoUrl != null || networkLogoUrl != null) ? 34 : 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cardName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  if (issuer.isNotEmpty)
                    Text(
                      issuer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                ],
              ),
            ),

            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders a bank's logo for the bank filter chips, with a text fallback
/// when the logo is null or empty.
class BankLogoChipContent extends StatelessWidget {
  final String bankName;
  final String? logoUrl;
  final bool isSelected;

  const BankLogoChipContent({
    super.key,
    required this.bankName,
    required this.logoUrl,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    if (!hasLogo) {
      return Text(
        bankName,
        style: TextStyle(
          color: isSelected ? AppColors.darkText : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            logoUrl!,
            height: 18,
            width: 18,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Text(
              bankName,
              style: TextStyle(
                color: isSelected ? AppColors.darkText : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          bankName,
          style: TextStyle(
            color: isSelected ? AppColors.darkText : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
