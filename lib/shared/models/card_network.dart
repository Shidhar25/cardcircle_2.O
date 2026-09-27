/// A card's payment network, resolved from the backend's free-text field.
///
/// `network` arrives in several shapes — `"Visa Signature"`, `"Mastercard"`,
/// `"Visa/Mastercard/RuPay"` — so it is parsed rather than printed raw.
///
/// This class only recognises and labels a network. It does not carry a
/// logo of its own: a network mark is never bundled with the app or built
/// from a guessed S3 path, only ever taken from what the API actually
/// states — a card's own `network_logo.url`, or `/card-networks`' `logo_url`
/// via `ApiService.networkLogoFor`/`cachedNetworkLogo`. [label] is what
/// those lookups match against, since it is spelled the way the API's own
/// `name` field is.
class CardNetwork {
  /// Display name, e.g. "Mastercard", "RuPay".
  final String label;

  const CardNetwork(this.label);

  /// Recognised networks, in match order.
  ///
  /// Order matters for multi-network strings like "Visa/Mastercard/RuPay":
  /// the first match wins, so the most widely accepted network is listed
  /// first and becomes the one shown.
  static const List<(List<String>, String)> _known = [
    (['visa'], 'Visa'),
    (['mastercard', 'master card'], 'Mastercard'),
    (['amex', 'american express'], 'American Express'),
    (['rupay'], 'RuPay'),
    (['diners'], 'Diners Club'),
    (['discover'], 'Discover'),
    (['maestro'], 'Maestro'),
  ];

  /// Parses [raw], or returns null when nothing is recognisable.
  static CardNetwork? parse(String? raw) {
    if (raw == null) return null;
    final n = raw.toLowerCase();
    if (n.trim().isEmpty) return null;

    for (final (aliases, label) in _known) {
      for (final alias in aliases) {
        if (n.contains(alias)) return CardNetwork(label);
      }
    }
    return null;
  }

  /// Every network named in [raw], for cards issued on more than one.
  static List<CardNetwork> parseAll(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final n = raw.toLowerCase();
    final out = <CardNetwork>[];
    for (final (aliases, label) in _known) {
      if (aliases.any(n.contains)) out.add(CardNetwork(label));
    }
    return out;
  }
}
