import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

/// Painter that adds a gritty, fabric-like texture to the canvas.
class GrittyTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    final random = math.Random(42);

    // Fine fabric texture lines
    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint..color = Colors.white.withValues(alpha: 0.01 + random.nextDouble() * 0.02),
      );
    }
    for (double x = 0; x < size.width; x += 2) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint..color = Colors.white.withValues(alpha: 0.01 + random.nextDouble() * 0.02),
      );
    }

    // Micro noise grit
    final gritPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 1500; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      gritPaint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.04);
      canvas.drawCircle(Offset(x, y), 0.5, gritPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CardVisual extends StatelessWidget {
  final CreditCard card;
  final bool compact;
  final bool showTactileTab;
  final String? tabLabel;

  const CardVisual({
    super.key,
    required this.card,
    this.compact = false,
    this.showTactileTab = true,
    this.tabLabel,
  });

  @override
  Widget build(BuildContext context) {
    final double width = compact ? 160.0 : 300.0;
    final double cardHeight = compact ? 105.0 : 190.0;
    final double tabHeight = compact ? 22.0 : 28.0;
    final double tabWidth = compact ? 80.0 : 110.0;
    final double padding = compact ? 12.0 : 20.0;

    final String badgeText = (tabLabel ?? card.category).toUpperCase();

    final cardBody = Container(
      width: width,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: showTactileTab ? Radius.zero : Radius.circular(compact ? 14.0 : 20.0),
          topRight: Radius.circular(compact ? 14.0 : 20.0),
          bottomLeft: Radius.circular(compact ? 14.0 : 20.0),
          bottomRight: Radius.circular(compact ? 14.0 : 20.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: card.gradientColors.first.withValues(alpha: 0.35),
            offset: const Offset(0, 5),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: showTactileTab ? Radius.zero : Radius.circular(compact ? 14.0 : 20.0),
          topRight: Radius.circular(compact ? 14.0 : 20.0),
          bottomLeft: Radius.circular(compact ? 14.0 : 20.0),
          bottomRight: Radius.circular(compact ? 14.0 : 20.0),
        ),
        child: Stack(
          children: [
            // Base Gradient Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: card.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Gritty Micro-Texture Painter Overlay
            Positioned.fill(
              child: CustomPaint(
                painter: GrittyTexturePainter(),
              ),
            ),

            // Inner Glass Edge Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: showTactileTab ? Radius.zero : Radius.circular(compact ? 14.0 : 20.0),
                  topRight: Radius.circular(compact ? 14.0 : 20.0),
                  bottomLeft: Radius.circular(compact ? 14.0 : 20.0),
                  bottomRight: Radius.circular(compact ? 14.0 : 20.0),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: compact ? 8.0 : 16.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row (Bank Name & Contactless Icon)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.bank.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            )
                          ],
                        ),
                      ),
                      Icon(
                        Icons.contactless_rounded,
                        size: compact ? 18 : 24,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          )
                        ],
                      ),
                    ],
                  ),

                  // Metallic Chip (large view only)
                  if (!compact)
                    Container(
                      width: 42,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 26,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.5)),
                              Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.5)),
                              Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.5)),
                            ],
                          )
                        ],
                      ),
                    ),

                  // Bottom Row (Card Number, User Name, Category Badge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '••••  ${card.lastFour}',
                              style: GoogleFonts.spaceMono(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: compact ? 10 : 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: compact ? 2 : 3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  )
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 2 : 6),
                            Text(
                              card.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.syne(
                                color: Colors.white,
                                fontSize: compact ? 10 : 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          card.category.toUpperCase(),
                          style: GoogleFonts.spaceMono(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: compact ? 8 : 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!showTactileTab) {
      return cardBody;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Hanging Tactile Tab Header
        Container(
          height: tabHeight,
          width: tabWidth,
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFC6E038), // Lime Tactile Accent
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            badgeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF1A1A1A),
              fontSize: compact ? 8.5 : 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        cardBody,
      ],
    );
  }
}