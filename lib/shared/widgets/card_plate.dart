import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/card_material.dart';
import '../models/card_network.dart';
import 'bank_mark.dart';

/// Paints a plate's surface finish. These are the details that sell the card
/// as a physical object rather than a coloured rectangle — without them the
/// gradients read as flat UI panels.
class PlateTexturePainter extends CustomPainter {
  final PlateTexture texture;
  final bool lightPlate;

  const PlateTexturePainter({required this.texture, required this.lightPlate});

  @override
  void paint(Canvas canvas, Size size) {
    switch (texture) {
      case PlateTexture.brushed:
        _brushed(canvas, size);
      case PlateTexture.engraved:
        _engraved(canvas, size);
      case PlateTexture.matte:
        _matte(canvas, size);
    }
  }

  /// Fine lines ~7° off vertical, every 3px — machined metal grain.
  void _brushed(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = lightPlate
          ? Colors.black.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.03);

    // 97deg in CSS is 7° past horizontal-right, so the bands themselves sit
    // near-vertical. Extra horizontal travel covers the shear at the edges.
    const shear = 0.12;
    final dx = size.height * shear;
    for (double x = -dx; x < size.width + dx; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x + dx, size.height), paint);
    }

    if (lightPlate) {
      final highlight = Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.5);
      for (double x = -dx + 1.5; x < size.width + dx; x += 3) {
        canvas.drawLine(Offset(x, 0), Offset(x + dx, size.height), highlight);
      }
    }
  }

  /// Concentric hairlines from an origin outside the plate — guilloche.
  void _engraved(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFFB4BEFF).withValues(alpha: 0.16);

    final origin = Offset(size.width * 1.16, size.height * 1.26);
    final maxRadius = math.sqrt(
      math.pow(origin.dx, 2) + math.pow(origin.dy, 2),
    );
    for (double r = 9; r < maxRadius; r += 9.5) {
      canvas.drawCircle(origin, r, paint);
    }
  }

  /// Even micro-dot grid — a matte, powder-coated surface.
  void _matte(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE9E9ED).withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 4) {
      for (double x = 0; x < size.width; x += 4) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PlateTexturePainter old) =>
      old.texture != texture || old.lightPlate != lightPlate;
}

/// A premium card plate, rendered from metadata — no card artwork.
///
/// Every card shares one geometry so the wallet reads as a single set:
///
///     ┌─────────────────────────────┐
///     │ [bank logo]                 │
///     │                             │
///     │ Product name                │
///     │ [network]                   │
///     └─────────────────────────────┘
///
/// The material supplies the plate's colour and finish but is never labelled
/// on the face — it's a visual tier cue, not a spec sheet.
class CardPlate extends StatelessWidget {
  /// The card's own artwork from the catalog (`image.url`). When present it
  /// becomes the face; the generated material plate is only the fallback for
  /// cards the backend has no image for.
  final String? artworkUrl;

  /// True when [artworkUrl] depicts this exact card. A card-specific image
  /// already carries the bank's and network's branding, so overlaying the
  /// marks again would double them up.
  final bool isCardSpecific;

  final String? bankLogoUrl;
  final String name;
  final String? networkLogoUrl;

  /// The raw `network` string from the backend. Rendered as a short type
  /// label beside the logo — networks without artwork (RuPay) would
  /// otherwise show nothing at all.
  final String network;

  /// Identify the issuer when no logo URL resolves — a monogram beats an
  /// empty corner.
  final String bankId;
  final String bankName;

  final CardMaterial material;

  /// Hides the product name, for thumbnail-sized plates where it would be
  /// unreadable anyway.
  final bool compact;

  /// Plate height; all metrics scale from the spec's 150px reference so the
  /// plate looks identical at any size.
  final double height;

  const CardPlate({
    super.key,
    required this.name,
    required this.material,
    this.artworkUrl,
    this.isCardSpecific = false,
    this.bankLogoUrl,
    this.networkLogoUrl,
    this.network = '',
    this.bankId = '',
    this.bankName = '',
    this.compact = false,
    this.height = 150,
  });

  /// Whether the issuer and network marks are drawn over the face.
  ///
  /// Card-specific artwork is a picture of that exact card, which already
  /// carries the issuer's branding and the network mark in its own design.
  /// Overlaying ours prints both a second time, in the wrong place. Generic
  /// bank backgrounds carry no branding, so there the marks are the only
  /// thing identifying the card.
  bool get _showMarks => !(isCardSpecific && (artworkUrl?.isNotEmpty ?? false));

  /// How much to enlarge card artwork so it fills the plate.
  ///
  /// Every image the catalog serves — generic bank backgrounds *and*
  /// card-specific art — is the same 1000x630 canvas with the card inset
  /// and a drop shadow baked in around it. Measured:
  ///
  /// ```
  /// generic/bank-generic-cards/…   content 880x554  needs 1.137
  /// credit-card-images/…/gold      content 879x556  needs 1.138
  /// generic/bank-card-bg/…         content 838x556  needs 1.193
  /// ```
  ///
  /// Drawn at `BoxFit.cover` that renders a card inside a card: a visible
  /// gap and a second shadow sitting inside the plate's own rounded edge.
  ///
  /// One factor covers the widest inset measured, plus 1% overscan against
  /// the artwork's antialiased edge. It is deliberately uniform rather than
  /// per-image: the alpha bounding box is only knowable by decoding the
  /// image, which is far too costly to do per frame. The cost is that art
  /// with a tighter inset loses a few percent at the edges — acceptable,
  /// and invisible next to the gap it replaces.
  ///
  /// If the artwork is ever re-exported without the margin, this becomes
  /// 1.0 and can be deleted.
  static const double _artZoom = 1.193 * 1.01;

  /// Corner radius of the plate, as a multiple of the 150px design unit.
  ///
  /// The artwork carries its own rounded corners — about 4.3% of the card's
  /// width, which works out slightly rounder than the plate's own 9u. Clip
  /// the art with the tighter radius and each corner shows a dark sliver of
  /// plate through the curve. Matching the artwork's radius makes the two
  /// curves coincide; plates with no artwork keep the house 9u.
  static const double _artworkCornerUnits = 10.3;
  static const double _plateCornerUnits = 9;

  @override
  Widget build(BuildContext context) {
    final double u = height / 150;
    final Color fg = material.foreground;
    final bool light = material.isLight;
    final bool hasArtwork = artworkUrl?.isNotEmpty ?? false;
    final double radius =
        (hasArtwork ? _artworkCornerUnits : _plateCornerUnits) * u;

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: material.gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 22 * u,
            spreadRadius: -10 * u,
            offset: Offset(0, 10 * u),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasArtwork)
            Transform.scale(
              scale: _artZoom,
              // The plate already clips, so the enlarged margin is simply
              // cropped away rather than overflowing the card.
              child: Image.network(
                artworkUrl!,
                // Cover, not fill: a card-specific photo at some other
                // ratio is cropped evenly rather than stretched.
                fit: BoxFit.cover,
                alignment: Alignment.center,
                // The source is ~1000px wide drawn at a third of that, and
                // the zoom above enlarges it further; high filtering keeps
                // that crisp rather than mushy.
                filterQuality: FilterQuality.high,
                // The gradient plate underneath stays visible on failure,
                // so a dead URL degrades to a valid-looking card, not a
                // hole.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                frameBuilder: (context, child, frame, wasSyncLoaded) {
                  if (wasSyncLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
              ),
            )
          else ...[
            CustomPaint(
              painter: PlateTexturePainter(
                texture: material.texture,
                lightPlate: light,
              ),
            ),

            // Raking sheen across the plate.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1.0, -0.35),
                  end: const Alignment(1.0, 0.35),
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: light ? 0.5 : 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.26, 0.44, 0.64],
                ),
              ),
            ),
          ],

          // Artwork is arbitrary, so the chrome needs a scrim to stay
          // legible — but only where the chrome actually is. Kept light at
          // the top and clear through the middle so the card art reads.
          if (hasArtwork)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.52),
                  ],
                  stops: const [0.0, 0.22, 0.58, 1.0],
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15 * u, vertical: 14 * u),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bank mark, top left.
                if (_showMarks)
                  _BankMarkSlot(
                    logoUrl: bankLogoUrl,
                    bankId: bankId,
                    bankName: bankName,
                    height: (compact ? 11 : 17) * u,
                    color: hasArtwork ? Colors.white : fg,
                  )
                else
                  const SizedBox.shrink(),

                // Name bottom left, network bottom right — the arrangement
                // on a real card face.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: compact
                          ? const SizedBox.shrink()
                          : Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sans(
                                11.5 * u,
                                color: hasArtwork ? Colors.white : fg,
                                letterSpacing: 0.1,
                                height: 1.25,
                              ),
                            ),
                    ),
                    if (_showMarks)
                      _NetworkSlot(
                        logoUrl: networkLogoUrl,
                        network: network,
                        u: u,
                        compact: compact,
                        color: hasArtwork ? Colors.white : fg,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Bevel: a lit top edge and a shadowed bottom, as on a real plate.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.012, 0.988, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top-left issuer mark: the logo the backend sent, or the bank's
/// monogram when there is no URL.
class _BankMarkSlot extends StatelessWidget {
  final String? logoUrl;
  final String bankId;
  final String bankName;
  final double height;
  final Color color;

  const _BankMarkSlot({
    required this.logoUrl,
    required this.bankId,
    required this.bankName,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl?.isNotEmpty ?? false) {
      return LogoBadge(url: logoUrl!, logoHeight: height);
    }
    return BankMark(
      bankId: bankId,
      bankName: bankName,
      size: height,
      color: color,
    );
  }
}

/// The bottom-right network mark: the logo where one exists, and the network
/// type as text alongside it.
///
/// The label is not decoration. RuPay has no logo on S3, so a logo-only slot
/// left those cards with nothing identifying the network at all.
class _NetworkSlot extends StatelessWidget {
  final String? logoUrl;
  final String network;
  final double u;
  final bool compact;
  final Color color;

  const _NetworkSlot({
    required this.logoUrl,
    required this.network,
    required this.u,
    required this.compact,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = CardNetwork.parse(network);
    final hasLogo = logoUrl?.isNotEmpty ?? false;
    if (!hasLogo && parsed == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: 8 * u),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasLogo)
            LogoBadge(url: logoUrl!, logoHeight: (compact ? 8 : 12) * u),
          // Suppressed on thumbnails, where it would be a smudge.
          if (!compact && parsed != null) ...[
            if (hasLogo) SizedBox(height: 4 * u),
            Text(
              parsed.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppText.mono(
                7.5 * u,
                ls: 1.1,
                w: FontWeight.w700,
                c: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
