import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../models/card_material.dart';
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
    this.bankLogoUrl,
    this.networkLogoUrl,
    this.network = '',
    this.bankId = '',
    this.bankName = '',
    this.compact = false,
    this.height = 150,
  });

  /// How far the artwork is pushed past each edge of the plate, in logical
  /// pixels of the plate's width.
  ///
  /// Full-bleed art drawn at exactly the plate's size leaves a hairline of
  /// plate showing along the edges: `cover` rounds the drawn rectangle to
  /// whole device pixels, and the rounded-corner clip antialiases whatever
  /// sits under the curve. Both read as a faint seam around the card.
  ///
  /// Six pixels across the width buries it. The scale is uniform, so the
  /// shorter axis gets `6 / 1.586` — about 3.8px.
  ///
  /// Close to the practical ceiling: this crops the artwork's own edge and
  /// the bank and network marks sit near it, so past roughly 8px they start
  /// losing their outlines — the failure the old 1.2x crop caused.
  ///
  /// Derived from the laid-out width rather than fixed, so the bleed stays
  /// the same thickness on a 320px phone and a tablet instead of scaling
  /// into a visible crop.
  static const double _edgeBleed = 6.0;

  /// Extra overscan at the bottom edge only, on top of [_edgeBleed].
  ///
  /// The bottom seam survived the uniform bleed that cleared the other
  /// three sides, so it gets this much again. Applied as a vertical-only
  /// scale anchored to the top, which is what keeps it off the top edge —
  /// where the bank mark sits and there is least room to spare.
  ///
  /// Costs a vertical stretch of `2 / plate height`, about 0.8% on a phone.
  /// Not visible on artwork with no straight horizontal reference in it.
  static const double _bottomBleed = 2.0;

  /// Corner radius of the plate, as a multiple of the 150px design unit.
  ///
  /// One radius for every plate now. The catalog artwork used to arrive as a
  /// card inset inside a larger canvas, carrying its own rounded corners and
  /// a baked-in drop shadow, so the plate had to be enlarged ~1.2x to crop
  /// the margin away and clipped at the artwork's own rounder radius to stop
  /// a dark sliver of plate showing through each curve.
  ///
  /// The artwork is now exported edge to edge — full bleed, square corners,
  /// no margin and no shadow — so both workarounds are gone: the image is
  /// drawn at its own size, and this clip is what rounds the corner.
  static const double _cornerUnits = 9;

  @override
  Widget build(BuildContext context) {
    final double u = height / 150;
    final Color fg = material.foreground;
    final bool light = material.isLight;
    final bool hasArtwork = artworkUrl?.isNotEmpty ?? false;
    final double radius = _cornerUnits * u;

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
            Positioned.fill(
              child: LayoutBuilder(
                // Two overscans, composed. The outer one is uniform and
                // centred, so it clears all four edges equally; the inner
                // one stretches the vertical axis alone from the top, so
                // its extra lands on the bottom edge and nowhere else.
                builder: (context, constraints) => Transform.scale(
                  scale: 1 + (2 * _edgeBleed) / constraints.maxWidth,
                  child: Transform.scale(
                    scaleY: 1 + _bottomBleed / constraints.maxHeight,
                    alignment: Alignment.topCenter,
                    child: _buildArtworkWidget(artworkUrl!),
                  ),
                ),
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

          // The marks, laid out as a real card lays them out: issuer top
          // left, network bottom right.
          //
          // Drawn over every plate, artwork or not. This used to be gated on
          // the catalog's `is_card_specific` flag on the theory that such
          // art carries its own branding — but the flag is inferred from a
          // URL path, and a card whose artwork is just a background ended up
          // with no marks at all.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 15 * u,
              vertical: 14 * u,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BankMarkSlot(
                  logoUrl: bankLogoUrl,
                  bankId: bankId,
                  bankName: bankName,
                  height: (compact ? 11 : 17) * u,
                  color: fg,
                  // The monogram is a stand-in for a missing logo on a bare
                  // gradient. Over artwork it would be a letterform dropped
                  // on top of a designed face, so artwork simply shows
                  // nothing when there is no logo to show.
                  allowMonogram: !hasArtwork,
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      // The product name belongs to the gradient plate,
                      // which has nothing else on it. Artwork already names
                      // the card in its own type.
                      child: (compact || hasArtwork)
                          ? const SizedBox.shrink()
                          : Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sans(
                                11.5 * u,
                                color: fg,
                                letterSpacing: 0.1,
                                height: 1.25,
                              ),
                            ),
                    ),
                    _NetworkSlot(
                      logoUrl: networkLogoUrl,
                      network: network,
                      u: u,
                      compact: compact,
                      color: fg,
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

  Widget _buildArtworkWidget(String url) {
    final bool isSvg =
        url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg');
    final bool isNetwork =
        url.startsWith('http://') || url.startsWith('https://');

    if (isSvg) {
      if (isNetwork) {
        return SvgPicture.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholderBuilder: (_) => const SizedBox.shrink(),
        );
      } else {
        final String assetPath =
            url.startsWith('assets/') ? url : 'assets/$url';
        return SvgPicture.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        );
      }
    } else {
      if (isNetwork) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
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
        );
      } else {
        final String assetPath =
            url.startsWith('assets/') ? url : 'assets/$url';
        return Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }
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

  /// Whether to fall back to the bank's monogram when there is no logo URL.
  final bool allowMonogram;

  const _BankMarkSlot({
    required this.logoUrl,
    required this.bankId,
    required this.bankName,
    required this.height,
    required this.color,
    this.allowMonogram = true,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl?.isNotEmpty ?? false) {
      return LogoBadge(url: logoUrl!, logoHeight: height);
    }
    if (!allowMonogram) return SizedBox(height: height);
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
    final hasLogo = logoUrl?.isNotEmpty ?? false;
    if (!hasLogo) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: 8 * u),
      // No white chip: a network mark from the API is exported with a
      // transparent background, often white artwork meant to sit directly
      // on a dark card. The chip would paint a white box around it instead
      // of showing it. Bank logos ([LogoBadge]'s default) keep the chip,
      // since those can arrive in any colour.
      child: LogoBadge(
        url: logoUrl!,
        // Larger than the bank mark's 17u/11u — a network mark carries no
        // white chip to fill out its footprint, so at the same height it
        // reads smaller than a bank logo sitting inside one. Sized up to
        // compensate rather than adding a chip back.
        logoHeight: (compact ? 15 : 22) * u,
        background: false,
      ),
    );
  }
}
