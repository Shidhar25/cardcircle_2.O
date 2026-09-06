import 'credit_card.dart';
import 'hack_rating.dart';

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

  /// How everyone on CardCircle rates this benefit.
  final HackRating platformRating;

  /// How the people this user follows rate it.
  ///
  /// Kept separate from [platformRating] rather than blended: the whole
  /// premise of the app is that your circle's opinion carries more weight
  /// than a global average, and averaging the two would erase exactly that
  /// signal.
  final HackRating circleRating;

  /// This user's own score, 1-5, or null when they have not rated it.
  final int? myRating;
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
    this.platformRating = HackRating.none,
    this.circleRating = HackRating.none,
    this.myRating,
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

  /// The rating worth leading with.
  ///
  /// Your circle's score wins when anyone in it has rated, because that is
  /// the opinion the app exists to surface; otherwise the platform average
  /// stands in.
  HackRating get headlineRating =>
      circleRating.hasRatings ? circleRating : platformRating;

  /// Whether [headlineRating] came from the user's circle.
  bool get headlineIsCircle => circleRating.hasRatings;

  /// Returns a copy carrying freshly submitted ratings.
  Hack withRatings({
    required HackRating platform,
    required HackRating circle,
    required int? mine,
  }) => Hack(
    id: id,
    name: name,
    heading: heading,
    steps: steps,
    cardIds: cardIds,
    savings: savings,
    category: category,
    platformRating: platform,
    circleRating: circle,
    myRating: mine,
    availedby: availedby,
    circledetail: circledetail,
    image: image,
    thingsToNote: thingsToNote,
    likes: likes,
    liked: liked,
    author: author,
    authorInitials: authorInitials,
    isLocked: isLocked,
  );

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

    final rawMine = json['my_rating'];
    final int? myRating = rawMine is num
        ? rawMine.toInt()
        : (rawMine is String ? int.tryParse(rawMine) : null);

    return Hack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      steps: stepsList,
      cardIds: cardsList,
      savings: json['savings']?.toString() ?? '5%',
      category: json['category']?.toString() ?? 'General',
      platformRating: HackRating.parse(json['platform_rating']),
      circleRating: HackRating.parse(json['circle_rating']),
      myRating: myRating,
      availedby: json['availedby']?.toString() ?? '',
      circledetail: json['circledetail']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      thingsToNote: notesList,
    );
  }
}
