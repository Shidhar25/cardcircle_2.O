/// The payment-network catalog served by `GET /card-networks`.
///
/// Distinct from [CardNetwork] in `card_network.dart`: that one *parses* the
/// free-text `network` string a catalog card already carries, to decide which
/// logo to draw. This one is the server-owned list the user picks from when
/// adding a card, so networks and variants can change without a release.
class NetworkOption {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  final List<NetworkVariant> variants;

  const NetworkOption({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.variants = const [],
  });

  static NetworkOption? fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final rawVariants = json['variants'];
    final logo = (json['logo_url'] as String?)?.trim();
    return NetworkOption(
      id: (json['network_id'] ?? json['id'] ?? '').toString(),
      name: name,
      code: (json['code'] as String?)?.trim() ?? '',
      logoUrl: (logo == null || logo.isEmpty) ? null : logo,
      variants: rawVariants is List
          ? rawVariants
                .whereType<Map>()
                .map((v) => NetworkVariant.fromJson(v.cast<String, dynamic>()))
                .nonNulls
                .toList()
          : const [],
    );
  }
}

class NetworkVariant {
  final String name;
  final String code;

  const NetworkVariant({required this.name, required this.code});

  static NetworkVariant? fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return NetworkVariant(
      name: name,
      code: (json['code'] as String?)?.trim() ?? '',
    );
  }
}
