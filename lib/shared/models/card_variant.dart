/// One issued version of a catalog card.
///
/// `GET /cards` groups a bank's catalog by product: "HDFC Millennia" is one
/// group carrying the versions it was actually issued as — Visa Signature,
/// Mastercard, Diners Club. Each of those is a real catalog row with its own
/// [cardId], which is what a saved card has to point at. The group itself has
/// no id worth saving: nobody holds "a Millennia", they hold the Visa one.
///
/// [label] and [value] are server-rendered ("Visa: Signature" / "visa:signature")
/// so the wording can change without a release.
class CardVariantOption {
  final String cardId;
  final String bankId;
  final String network;

  /// The tier within the network — "Signature", "Infinite". Null for a
  /// network the bank doesn't split, which is most of them.
  final String? networkVariant;

  /// The product edition, when the group covers more than one.
  final String? cardVariant;

  final String cardType;

  /// Server-rendered choice label, e.g. "Visa: Signature".
  final String label;

  /// Server-rendered stable key, e.g. "visa:signature".
  final String value;

  final String? image;

  const CardVariantOption({
    required this.cardId,
    required this.label,
    required this.value,
    this.bankId = '',
    this.network = '',
    this.networkVariant,
    this.cardVariant,
    this.cardType = '',
    this.image,
  });

  static String? _text(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }

  /// Returns null for a variant with no [cardId] — one that can't be saved
  /// is worse than one that isn't offered.
  static CardVariantOption? fromJson(Map<String, dynamic> json) {
    final cardId = _text(json['card_id'] ?? json['id']);
    if (cardId == null) return null;

    final network = _text(json['network']) ?? '';
    final networkVariant = _text(json['network_variant']);

    // The server labels every variant, but a payload that predates that
    // still has to render as something a person can choose between.
    final fallback = [network, networkVariant]
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .join(': ');

    return CardVariantOption(
      cardId: cardId,
      bankId: _text(json['bank_id']) ?? '',
      network: network,
      networkVariant: networkVariant,
      cardVariant: _text(json['card_variant']),
      cardType: _text(json['card_type']) ?? '',
      label: _text(json['label']) ?? (fallback.isEmpty ? 'Standard' : fallback),
      value:
          _text(json['value']) ??
          (fallback.isEmpty ? cardId : fallback.toLowerCase()),
      image: _text(json['image'] ?? json['image_url']),
    );
  }

  static List<CardVariantOption> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((v) => fromJson(v.cast<String, dynamic>()))
        .nonNulls
        .toList();
  }
}
