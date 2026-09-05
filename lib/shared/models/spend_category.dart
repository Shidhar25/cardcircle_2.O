import 'package:flutter/material.dart';

/// A spend category from `GET /category/list`.
///
/// The app used to carry three separate hardcoded lists — the Benefits
/// filter pills, the Profile "spend categories" chips, and the Select Tags
/// grid — none of which agreed with the backend. Filtering benefits by the
/// literal string `"Dining"` could never match a backend category named
/// `food_dining`/"Food & Dining", so those pills silently returned nothing.
/// One type, fetched once, keeps them consistent.
@immutable
class SpendCategory {
  /// The id to send back when tagging. This, not the name, is what
  /// `POST /category/tag` expects.
  final String id;

  /// Machine name, e.g. `food_dining`.
  final String name;

  /// Human label, e.g. "Food & Dining".
  final String displayName;

  final String description;

  /// Icon key from the backend (a Lucide name like `utensils`), mapped to a
  /// Material icon at render time.
  final String iconKey;

  /// Brand colour as sent, e.g. `#FF6B6B`.
  final String? colorHex;

  const SpendCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.iconKey,
    required this.colorHex,
  });

  /// Reads one row, tolerating missing fields.
  ///
  /// Returns null when there is no usable id — a category that cannot be
  /// tagged is not worth rendering, and would fail on submit.
  static SpendCategory? tryParse(Map<String, dynamic> json) {
    final id = (json['categoryId'] ?? json['category_id'])?.toString();
    if (id == null || id.isEmpty) return null;

    final name = (json['name'] ?? '').toString();
    final display = (json['displayName'] ?? json['display_name'] ?? '')
        .toString();

    return SpendCategory(
      id: id,
      name: name,
      // Fall back to the machine name rather than rendering an empty chip.
      displayName: display.isNotEmpty ? display : _humanise(name),
      description: (json['description'] ?? '').toString(),
      iconKey: (json['icon'] ?? '').toString(),
      colorHex: json['color'] as String?,
    );
  }

  static String _humanise(String machineName) => machineName
      .split(RegExp(r'[_\-]'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// Whether [text] refers to this category.
  ///
  /// Benefit records identify their category inconsistently — sometimes the
  /// machine name, sometimes the display label — so both are accepted
  /// rather than requiring the feed to be normalised first.
  bool matches(String? text) {
    if (text == null) return false;
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t == name.toLowerCase() ||
        t == displayName.toLowerCase() ||
        t == id.toLowerCase();
  }

  /// The backend sends Lucide icon names; these are their Material
  /// equivalents. An unmapped key falls back to a neutral glyph rather than
  /// leaving a hole in the grid.
  static const Map<String, IconData> _icons = {
    'utensils': Icons.restaurant_rounded,
    'shopping-cart': Icons.shopping_cart_rounded,
    'shopping-bag': Icons.shopping_bag_rounded,
    'car': Icons.directions_car_rounded,
    'film': Icons.movie_creation_rounded,
    'plane': Icons.flight_takeoff_rounded,
    'heart': Icons.favorite_rounded,
    'zap': Icons.bolt_rounded,
    'book': Icons.menu_book_rounded,
    'shield': Icons.security_rounded,
    'trending-up': Icons.trending_up_rounded,
    'file-text': Icons.description_rounded,
    'scissors': Icons.content_cut_rounded,
    'gift': Icons.card_giftcard_rounded,
    'more-horizontal': Icons.more_horiz_rounded,
  };

  IconData get icon => _icons[iconKey] ?? Icons.local_offer_rounded;

  /// Parses `#RRGGBB` (or `RRGGBB`), falling back to [fallback] on anything
  /// malformed — a bad colour must not take the screen down.
  Color color(Color fallback) {
    final hex = colorHex?.replaceFirst('#', '').trim();
    if (hex == null || (hex.length != 6 && hex.length != 8)) return fallback;
    final value = int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
    return value == null ? fallback : Color(value);
  }
}
