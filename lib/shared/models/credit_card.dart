import 'package:flutter/material.dart';

class CreditCard {
  final String id;
  final String name;
  final String bank;
  final String lastFour;
  final List<Color> gradientColors;
  final String type;
  final String category;

  /// Real card artwork from the backend catalog (`image.url`), used as the
  /// card face instead of the [gradientColors] fallback when present.
  final String? imageUrl;

  /// True when [imageUrl] already depicts the exact card (shown as-is);
  /// false means it's a generic bank background, so [bankLogoUrl] /
  /// [networkLogoUrl] are overlaid on top — same rule the Add Cards catalog
  /// list uses, kept consistent here so "Your Cards" looks the same.
  final bool isCardSpecific;
  final String? bankLogoUrl;
  final String? networkLogoUrl;

  /// Full issuer line (e.g. "Bank of Baroda (Bobcard Limited)"), shown under
  /// the card name on generic (non-card-specific) faces. Falls back to
  /// [bank] when the backend doesn't send a separate issuer string.
  final String issuer;

  /// Backend slug (`hdfc-bank`, `bank-of-baroda`). This is the key into the
  /// curated brand registry, so it drives the card's gradient and logo —
  /// unlike [bank], which is only for display.
  final String bankId;

  /// Raw network string as the backend sends it, e.g. "Visa Signature".
  /// Kept unparsed so display code can decide how much of it to use.
  final String network;

  CreditCard({
    required this.id,
    required this.name,
    required this.bank,
    required this.lastFour,
    required this.gradientColors,
    required this.type,
    required this.category,
    this.imageUrl,
    this.isCardSpecific = false,
    this.bankLogoUrl,
    this.networkLogoUrl,
    String? issuer,
    this.bankId = '',
    this.network = '',
  }) : issuer = issuer ?? bank;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bank': bank,
    'lastFour': lastFour,
    'gradientColors': gradientColors.map((c) => c.toARGB32()).toList(),
    'type': type,
    'category': category,
    'imageUrl': imageUrl,
    'isCardSpecific': isCardSpecific,
    'bankLogoUrl': bankLogoUrl,
    'networkLogoUrl': networkLogoUrl,
    'issuer': issuer,
    'bankId': bankId,
    'network': network,
  };

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
    id: json['id'],
    name: json['name'],
    bank: json['bank'],
    lastFour: json['lastFour'],
    gradientColors: (json['gradientColors'] as List)
        .map((val) => Color(val as int))
        .toList(),
    type: json['type'],
    category: json['category'],
    imageUrl: json['imageUrl'] as String?,
    isCardSpecific: json['isCardSpecific'] as bool? ?? false,
    bankLogoUrl: json['bankLogoUrl'] as String?,
    networkLogoUrl: json['networkLogoUrl'] as String?,
    issuer: json['issuer'] as String?,
    bankId: json['bankId'] as String? ?? '',
    network: json['network'] as String? ?? '',
  );
}
