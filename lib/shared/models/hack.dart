import 'credit_card.dart';

class HackStep {
  final String name;
  final String heading;
  final String icon;
  final String description;

  HackStep({
    required this.name,
    required this.heading,
    required this.icon,
    required this.description,
  });

  factory HackStep.fromJson(Map<String, dynamic> json) {
    return HackStep(
      name: json['name']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '💡',
      description: json['description']?.toString() ?? '',
    );
  }
}

class Hack {
  final String id;
  final String name;
  final String heading;
  final List<HackStep> steps;

  /// Catalog card ids this benefit applies to (`card_ids`).
  ///
  /// These are *catalog* ids, not the `user_card_id` of a saved card, so
  /// resolving them to names goes through [CreditCard.catalogCardId].
  final List<String> cardIds;

  final String savings;
  final String category;

  /// Editorial rating, or null when the benefit has not been rated.
  ///
  /// Nullable on purpose: this used to default to 4.8, so every unrated
  /// benefit displayed a confident score nobody had given it.
  final double? rating;
  final String availedby;
  final String circledetail;
  final String image;
  final List<String> thingsToNote;

  int likes;
  bool liked;
  final String author;
  final String authorInitials;
  final bool isLocked;

  Hack({
    required this.id,
    required this.name,
    required this.heading,
    required this.steps,
    required this.cardIds,
    required this.savings,
    required this.category,
    this.rating,
    required this.availedby,
    this.circledetail = '',
    this.image = '',
    required this.thingsToNote,
    this.likes = 124,
    this.liked = false,
    this.author = 'CardCircle Community',
    this.authorInitials = 'CC',
    this.isLocked = false,
  });

  String get title => name.isNotEmpty ? name : heading;
  String get description => heading.isNotEmpty ? heading : name;

  /// Whether this benefit names specific cards at all.
  bool get isCardSpecific => cardIds.isNotEmpty;

  /// The names of [mine] that this benefit applies to.
  ///
  /// Only the user's own cards are named. The catalog id of a benefit means
  /// nothing to a reader, and listing cards they do not hold would be
  /// noise — the useful question on a benefit is "which of my cards does
  /// this work with".
  ///
  /// Empty when nothing matches, which the UI reads as "say nothing" rather
  /// than falling back to a claim like "All Credit Cards".
  List<String> myCardNames(List<CreditCard> mine) {
    if (cardIds.isEmpty) return const [];
    final wanted = cardIds.toSet();
    return mine
        .where((c) => wanted.contains(c.catalogCardId))
        .map((c) => c.name)
        .where((n) => n.isNotEmpty)
        .toList();
  }

  factory Hack.fromJson(Map<String, dynamic> json) {
    final stepsList =
        (json['steps'] as List<dynamic>?)
            ?.map((e) => HackStep.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // The API field is `card_ids`; `cards` is accepted as a fallback for
    // older payloads. Reading only `cards` meant this list was always empty
    // and every benefit claimed to apply to "All Credit Cards".
    final rawCards = json['card_ids'] ?? json['cards'];
    final cardsList = rawCards is List
        ? rawCards.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final notesList =
        (json['things_to_note'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final rawRating = json['rating'];
    final double? parsedRating = rawRating is num
        ? rawRating.toDouble()
        : (rawRating is String ? double.tryParse(rawRating) : null);

    return Hack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      steps: stepsList,
      cardIds: cardsList,
      savings: json['savings']?.toString() ?? '5%',
      category: json['category']?.toString() ?? 'General',
      rating: parsedRating,
      availedby: json['availedby']?.toString() ?? '',
      circledetail: json['circledetail']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      thingsToNote: notesList,
    );
  }
}
