import 'package:flutter/material.dart';

class CreditCard {
  /// The saved-card id (`user_card_id`) — what delete and permission calls
  /// address.
  final String id;

  /// The saved-card id in one `GET /user/cards` row, or empty when it has
  /// none.
  ///
  /// Read leniently across spellings because this is the one field the
  /// client cannot work around being wrong about: every endpoint that
  /// addresses a saved card takes it and nothing else. It deliberately does
  /// NOT fall back to the catalog `card_id` — that fallback is what made
  /// sharing and deleting fail, since the server casts this to a uuid and a
  /// catalog id is a Mongo ObjectId.
  static String savedIdFrom(Map<String, dynamic> row) {
    for (final key in const [
      'user_card_id',
      'userCardId',
      'user_card',
      'id',
      '_id',
    ]) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Whether this card can be addressed as a saved card — deleted, or named
  /// in a follower's access list.
  ///
  /// False when `GET /user/cards` sent no saved-card id for it. The endpoints
  /// that take one reject anything else outright (the server casts it to a
  /// uuid), so a card without it must not be offered for either.
  bool get isAddressable => id.trim().isNotEmpty;

  /// The catalog id (`card_id`) this saved card was created from.
  ///
  /// Separate from [id] because benefits list the cards they apply to by
  /// catalog id; matching those against a `user_card_id` never succeeds.
  final String catalogCardId;

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
    this.catalogCardId = '',
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
    'catalogCardId': catalogCardId,
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
    catalogCardId: json['catalogCardId'] as String? ?? '',
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
