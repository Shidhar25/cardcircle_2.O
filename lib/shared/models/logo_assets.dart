/// The bundled bank marks.
///
/// Scoped to bank logos only. Network marks (Visa, Mastercard, RuPay, …)
/// used to be bundled here too, keyed off the free-text `network` field or
/// `network_logo.card_network_type` — that set has been removed. A network
/// mark now comes only from what the API actually states: a card's own
/// `network_logo.url`, or `/card-networks`' `logo_url` via
/// `ApiService.networkLogoFor` / `cachedNetworkLogo`. When the API has
/// nothing for a network, the plate shows none — no local stand-in.
///
/// A bank mark stays bundled because it is our own artwork, shipped with
/// the app rather than fetched, so it cannot 404 and renders instantly on
/// first paint. `/banks`' own logo remains the primary source
/// (`ApiService.bankLogoFor`); this is only the fallback, and only for
/// `axis-bank` today — see [bank].
class LogoAssets {
  static const String _dir = 'assets/logos/';

  /// The one bundled bank mark.
  static const String axis = '${_dir}Axis_Bank_Logo.png';

  /// True for a path this class handed out.
  static bool isBundled(String? url) => url != null && url.startsWith(_dir);

  /// The issuer mark for a bank slug, or null when none is bundled.
  ///
  /// Deliberately keyed on the slug and nothing else. `/banks` currently
  /// answers `au-small-finance-bank` with the *Axis* logo URL, and mapping
  /// that slug here would bake the server's mistake into the app.
  static String? bank(String? bankId) {
    switch (bankId) {
      case 'axis-bank':
        return axis;
      default:
        return null;
    }
  }
}
