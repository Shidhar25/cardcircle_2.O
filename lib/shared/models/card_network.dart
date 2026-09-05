/// A card's payment network, resolved from the backend's free-text field.
///
/// `network` arrives in several shapes — `"Visa Signature"`, `"Mastercard"`,
/// `"Visa/Mastercard/RuPay"` — so it is parsed rather than printed raw.
///
/// Label and logo are deliberately separate. Not every network has artwork
/// on S3: `visa`, `mastercard`, `amex`, `diners`, `discover` and `maestro`
/// resolve, but `rupay` returns 403 under every spelling. Generating a URL
/// for a file that is known not to exist just means a request that fails and
/// a mark that silently collapses, so a network without artwork carries a
/// label and no [logoSlug] — which is why the plate shows the type as text
/// as well as a logo.
class CardNetwork {
  /// Display name, e.g. "Mastercard", "RuPay".
  final String label;

  /// Filename stem under `generic/network-logos/`, or null when the network
  /// has no artwork.
  final String? logoSlug;

  const CardNetwork(this.label, this.logoSlug);

  static const String _logoBase =
      'https://cardcirclepublicassets.s3.ap-south-1.amazonaws.com'
      '/generic/network-logos';

  /// Absolute logo URL, or null when this network has no artwork.
  String? get logoUrl => logoSlug == null ? null : '$_logoBase/$logoSlug.webp';

  /// Recognised networks, in match order.
  ///
  /// Order matters for multi-network strings like "Visa/Mastercard/RuPay":
  /// the first match wins, so the most widely accepted network is listed
  /// first and becomes the one shown.
  static const List<(List<String>, String, String?)> _known = [
    (['visa'], 'Visa', 'visa'),
    (['mastercard', 'master card'], 'Mastercard', 'mastercard'),
    (['amex', 'american express'], 'American Express', 'amex'),
    (['rupay'], 'RuPay', null),
    (['diners'], 'Diners Club', 'diners'),
    (['discover'], 'Discover', 'discover'),
    (['maestro'], 'Maestro', 'maestro'),
  ];

  /// Parses [raw], or returns null when nothing is recognisable.
  static CardNetwork? parse(String? raw) {
    if (raw == null) return null;
    final n = raw.toLowerCase();
    if (n.trim().isEmpty) return null;

    for (final (aliases, label, slug) in _known) {
      for (final alias in aliases) {
        if (n.contains(alias)) return CardNetwork(label, slug);
      }
    }
    return null;
  }

  /// Every network named in [raw], for cards issued on more than one.
  static List<CardNetwork> parseAll(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final n = raw.toLowerCase();
    final out = <CardNetwork>[];
    for (final (aliases, label, slug) in _known) {
      if (aliases.any(n.contains)) out.add(CardNetwork(label, slug));
    }
    return out;
  }
}
