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
    // Increased height from 95/175 to 105/190 to fit the stacked text
    final double height = compact ? 105.0 : 190.0;
    final double padding = compact ? 12.0 : 22.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 14.0 : 20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
          BoxShadow(
            color: card.gradientColors.first.withOpacity(0.3),
            offset: const Offset(0, 5),
            blurRadius: 15,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 14.0 : 20.0),
        child: Stack(
          children: [
            // Base Gradient & Background Image
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: card.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                // ADDED: Background image for the card
                image: DecorationImage(
                  // Replace with your model's image property, e.g., NetworkImage(card.imageUrl)
                  // or AssetImage('assets/images/card_bg.jpg')
                  image: const NetworkImage('https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2400&auto=format&fit=crop'),
                  fit: BoxFit.cover,
                  // Darken the image slightly so the white text remains readable
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
            // Inner Border Overlay (Glass Edge)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 14.0 : 20.0),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.1),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            // Metallic Sweeps
            Positioned(
              top: compact ? -50 : -80,
              left: compact ? -30 : -50,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: compact ? 120 : 200,
                  height: compact ? 200 : 350,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            // Card Content
            // Card Content
            Padding(
              // Use symmetric padding to reduce the top and bottom margins slightly
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: compact ? 8.0 : 16.0, // This gives us back the pixels we need
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row (Name removed, only Bank & Icon remain)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.bank.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            )
                          ],
                        ),
                      ),
                      Icon(
                        Icons.contactless_rounded,
                        size: compact ? 18 : 24,
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          )
                        ],
                      ),
                    ],
                  ),
                  // Chip (only in large view)
                  if (!compact)
                    Container(
                      width: 42,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 26,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.5)),
                              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.5)),
                              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.5)),
                            ],
                          )
                        ],
                      ),
                    ),
                  // Bottom Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Bottom Left: Card Number AND User Name
                      // Wrap in Expanded so it doesn't push the category pill off-screen
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '••••  ${card.lastFour}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: compact ? 11 : 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: compact ? 2 : 3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  )
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 2 : 6),
                            Text(
                              card.name.toUpperCase(),
                              // Add maxLines and overflow to handle very long names
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 10 : 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Add a little buffer space so the text never touches the pill
                      const SizedBox(width: 8),

                      // Bottom Right: Category Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          card.category.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
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
  }
}