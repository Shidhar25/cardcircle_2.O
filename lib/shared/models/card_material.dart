import 'package:flutter/material.dart';

/// How a plate is textured. Each maps to one of the repeating backgrounds in
/// the premium-card spec.
enum PlateTexture {
  /// Fine brushed lines, ~7° off vertical — reads as machined metal.
  brushed,

  /// Wide concentric rings from an off-plate origin — an engraved guilloche.
  engraved,

  /// Even micro dot grid — a matte, powder-coated finish.
  matte,
}

/// One physical-looking plate finish.
///
/// The whole point of the system: material is chosen by **tier**, never by
/// brand. Hundreds of cards collapsing onto six plates is the feature — it's
/// what makes a wallet read as one shelf rather than a pile of logos. What
/// distinguishes cards is the name, monogram, last four and network, each in
/// a fixed slot.
class CardMaterial {
  final String label;
  final String code;
  final Gradient gradient;
  final PlateTexture texture;

  /// Foreground for text and chrome. The alloy plate is light, so it takes a
  /// dark foreground while every other plate takes near-white.
  final Color foreground;

  const CardMaterial({
    required this.label,
    required this.code,
    required this.gradient,
    required this.texture,
    required this.foreground,
  });

  bool get isLight => foreground.computeLuminance() < 0.5;
}

// CSS `radial-gradient(130% 170% at X% Y%, …)` → an off-corner origin with a
// radius wide enough to keep the darkest stop in the far corner.
RadialGradient _corner(List<Color> colors, List<double> stops, Alignment at) =>
    RadialGradient(center: at, radius: 1.45, colors: colors, stops: stops);

// CSS `linear-gradient(158deg, …)`: direction (sin θ, −cos θ).
const LinearGradient _diagonal158 = LinearGradient(
  begin: Alignment(-0.37, -0.93),
  end: Alignment(0.37, 0.93),
  colors: [Color(0xFF22242C), Color(0xFF191B22), Color(0xFF101118)],
  stops: [0.0, 0.54, 1.0],
);

/// M1 — Metal. Reserved for the top tier.
final CardMaterial kMetal = CardMaterial(
  label: 'Metal',
  code: 'M1',
  gradient: _corner(
    const [Color(0xFF3C3F4C), Color(0xFF23252F), Color(0xFF12131A)],
    const [0.0, 0.44, 1.0],
    const Alignment(-0.76, -0.88),
  ),
  texture: PlateTexture.brushed,
  foreground: const Color(0xFFE9E9ED),
);

/// M2 — Alloy. The one light plate; deliberately rare so it stands out.
final CardMaterial kAlloy = CardMaterial(
  label: 'Alloy',
  code: 'M2',
  gradient: _corner(
    const [Color(0xFFF2EFE6), Color(0xFFD6D1C3), Color(0xFFA9A496)],
    const [0.0, 0.40, 1.0],
    const Alignment(-0.72, -0.92),
  ),
  texture: PlateTexture.brushed,
  foreground: const Color(0xFF2C2E36),
);

/// M3 — Indigo, engraved.
final CardMaterial kIndigo = CardMaterial(
  label: 'Indigo',
  code: 'M3',
  gradient: _corner(
    const [Color(0xFF2A2D5E), Color(0xFF1E2148), Color(0xFF14162E)],
    const [0.0, 0.46, 1.0],
    const Alignment(-0.80, -0.92),
  ),
  texture: PlateTexture.engraved,
  foreground: const Color(0xFFE9E9ED),
);

/// M4 — Violet, engraved.
final CardMaterial kViolet = CardMaterial(
  label: 'Violet',
  code: 'M4',
  gradient: _corner(
    const [Color(0xFF4A4270), Color(0xFF332C56), Color(0xFF201B38)],
    const [0.0, 0.46, 1.0],
    const Alignment(-0.76, -0.88),
  ),
  texture: PlateTexture.engraved,
  foreground: const Color(0xFFE9E9ED),
);

/// M5 — Graphite, matte.
final CardMaterial kGraphite = CardMaterial(
  label: 'Graphite',
  code: 'M5',
  gradient: _diagonal158,
  texture: PlateTexture.matte,
  foreground: const Color(0xFFE9E9ED),
);

/// M6 — Steel, matte. The default plate.
final CardMaterial kSteel = CardMaterial(
  label: 'Steel',
  code: 'M6',
  gradient: const LinearGradient(
    begin: Alignment(-0.37, -0.93),
    end: Alignment(0.37, 0.93),
    colors: [Color(0xFF2B3040), Color(0xFF1F2431), Color(0xFF161A24)],
    stops: [0.0, 0.54, 1.0],
  ),
  texture: PlateTexture.matte,
  foreground: const Color(0xFFE9E9ED),
);

/// Picks a plate from the card's tier signals.
///
/// Reads the product name and type rather than the bank, so an issuer's
/// flagship and its entry card get visibly different plates — which is the
/// distinction a cardholder actually cares about.
CardMaterial cardMaterialFor({String? name, String? cardType}) {
  final s = '${name ?? ''} ${cardType ?? ''}'.toLowerCase();

  bool has(List<String> keys) => keys.any(s.contains);

  // Super-premium / metal flagships.
  if (has([
    'infinia',
    'aurum',
    'magnus burgundy',
    'burgundy',
    'reserve',
    'reserv',
    'elite',
    'emeralde',
    'centurion',
    'metal',
    'private',
    'eterna',
  ])) {
    return kMetal;
  }

  // Premium tier.
  if (has(['platinum', 'signature', 'infinite', 'diners black', 'premier'])) {
    return kAlloy;
  }

  // Travel.
  if (has([
    'travel',
    'miles',
    'marriott',
    'bonvoy',
    'air',
    'indigo',
    'atlas',
  ])) {
    return kIndigo;
  }

  // Lifestyle / shopping / rewards.
  if (has([
    'lit',
    'rewards',
    'shopping',
    'amazon',
    'flipkart',
    'swiggy',
    'zomato',
  ])) {
    return kViolet;
  }

  // Cashback / fuel / everyday value.
  if (has(['cashback', 'cash back', 'fuel', 'moneyback', 'millennia'])) {
    return kGraphite;
  }

  return kSteel;
}
