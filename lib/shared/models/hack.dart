import 'circle_availability.dart';
import 'credit_card.dart';
import 'feedback_question.dart';
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

  /// Whether this reader still owes feedback on *this* benefit, embedded by
  /// the list endpoints alongside the ratings.
  ///
  /// Null means the payload carried no `feedback_prompt` at all — a hack
  /// reached outside a list, or an older backend — not "nothing to ask".
  /// The distinction matters: null is the only case where the standalone
  /// endpoint still needs calling, and collapsing it to
  /// [FeedbackPrompt.none] would silently stop ever asking on those paths.
  final FeedbackPrompt? feedbackPrompt;

  /// Friends who hold a card this benefit works on.
  ///
  /// Defaults to [CircleAvailability.none] rather than null: a payload
  /// without the field means "nobody to show", and every reader would have
  /// had to null-check for a state that renders the same as empty.
  final CircleAvailability circleAvailability;

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
    this.feedbackPrompt,
    this.circleAvailability = CircleAvailability.none,
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

  /// Returns a copy with the feedback prompt spent.
  ///
  /// The embedded prompt came from a list fetched before the reader
  /// answered, so it still says "ask". Re-entering from that same list
  /// would ask again, and the server would reject the duplicate answers.
  Hack withFeedbackAnswered() => _copyWith(feedbackPrompt: FeedbackPrompt.none);

  /// Returns a copy carrying freshly submitted ratings.
  Hack withRatings({
    required HackRating platform,
    required HackRating circle,
    required int? mine,
  }) => _copyWith(
    platformRating: platform,
    circleRating: circle,
    myRating: mine,
    clearMyRatingWhenNull: true,
  );

  /// Field-by-field copy. Private because every caller should go through a
  /// named helper that says *why* the copy exists.
  Hack _copyWith({
    HackRating? platformRating,
    HackRating? circleRating,
    int? myRating,
    bool clearMyRatingWhenNull = false,
    FeedbackPrompt? feedbackPrompt,
  }) => Hack(
    id: id,
    name: name,
    heading: heading,
    steps: steps,
    cardIds: cardIds,
    savings: savings,
    category: category,
    platformRating: platformRating ?? this.platformRating,
    circleRating: circleRating ?? this.circleRating,
    myRating: clearMyRatingWhenNull ? myRating : (myRating ?? this.myRating),
    feedbackPrompt: feedbackPrompt ?? this.feedbackPrompt,
    circleAvailability: circleAvailability,
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
      feedbackPrompt: json.containsKey('feedback_prompt')
          ? FeedbackPrompt.parse(
              (json['feedback_prompt'] as Map?)?.cast<String, dynamic>(),
            )
          : null,
      circleAvailability: CircleAvailability.parse(json['circle_availability']),
      availedby: json['availedby']?.toString() ?? '',
      circledetail: json['circledetail']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      thingsToNote: notesList,
    );
  }
}
