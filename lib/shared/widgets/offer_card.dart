import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/models.dart';
import 'neo_pop_button.dart';

class OfferCard extends StatelessWidget {
  final Offer offer;

  const OfferCard({
    super.key,
    required this.offer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      offer.merchant[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.merchant,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Expires in: ${offer.expiresIn}',
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (offer.isHot)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF4757).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.local_fire_department, size: 10, color: Color(0xFFFF4757)),
                      SizedBox(width: 4),
                      Text(
                        'HOT DEAL',
                        style: TextStyle(
                          color: Color(0xFFFF4757),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Promotion Text
          Text(
            offer.discount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.green,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            offer.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Footer info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.credit_card_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                offer.cardName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, size: 12, color: AppColors.gold),
                          const SizedBox(width: 6),
                          Text(
                            offer.cashback,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              NeoPopButton(
                onPressed: () {},
                style: NeoPopButtonStyle.flat,
                color: AppColors.elevated,
                shadowColor: const Color(0xFF050505),
                depth: 3.5,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: const Text(
                  'Claim Deal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
