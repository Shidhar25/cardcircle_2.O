import 'package:flutter/material.dart';
import '../models/models.dart';

class CardVisual extends StatelessWidget {
  final CreditCard card;
  final bool compact;

  const CardVisual({
    super.key,
    required this.card,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double width = compact ? 150.0 : 290.0;
    final double height = compact ? 95.0 : 175.0;
    final double padding = compact ? 12.0 : 22.0;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 14.0 : 20.0),
        gradient: LinearGradient(
          colors: card.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Shine overlays
          Positioned(
            top: compact ? -25 : -50,
            right: compact ? -15 : -30,
            child: Container(
              width: compact ? 70 : 130,
              height: compact ? 70 : 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: compact ? -20 : -40,
            left: compact ? -10 : -20,
            child: Container(
              width: compact ? 50 : 100,
              height: compact ? 50 : 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // Card content
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.bank,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: compact ? 9 : 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        card.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 11 : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.credit_card_rounded,
                    size: compact ? 18 : 24,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),

              // Chip (only in large view)
              if (!compact)
                Container(
                  width: 38,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 2, width: 22, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(height: 3),
                      Container(height: 2, width: 22, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(height: 3),
                      Container(height: 2, width: 22, color: Colors.white.withOpacity(0.4)),
                    ],
                  ),
                ),

              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '•••• ${card.lastFour}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 10 : 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: compact ? 1 : 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      card.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
