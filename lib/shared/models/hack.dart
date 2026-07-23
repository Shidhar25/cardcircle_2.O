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
  final List<String> cards;
  final String savings;
  final String category;
  final double rating;
  final String availedby;
  final String circledetail;
  final String image;
  final List<String> thingsToNote;
  
  // Legacy / UI Helpers
  int likes;
  bool liked;
  final String author;
  final String authorInitials;
  final String authorLevel;
  final bool isLocked;
  final String timestamp;

  Hack({
    required this.id,
    required this.name,
    required this.heading,
    required this.steps,
    required this.cards,
    required this.savings,
    required this.category,
    required this.rating,
    required this.availedby,
    this.circledetail = '',
    this.image = '',
    required this.thingsToNote,
    this.likes = 124,
    this.liked = false,
    this.author = 'CardCircle Community',
    this.authorInitials = 'CC',
    this.authorLevel = 'Verified',
    this.isLocked = false,
    this.timestamp = 'Recently',
  });

  String get title => name.isNotEmpty ? name : heading;
  String get description => heading.isNotEmpty ? heading : name;
  String get cardName => cards.isNotEmpty ? cards.join(', ') : 'All Credit Cards';

  factory Hack.fromJson(Map<String, dynamic> json) {
    final stepsList = (json['steps'] as List<dynamic>?)
            ?.map((e) => HackStep.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final cardsList = (json['cards'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final notesList = (json['things_to_note'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    double parsedRating = 4.8;
    if (json['rating'] != null) {
      parsedRating = (json['rating'] as num).toDouble();
    }

    return Hack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      steps: stepsList,
      cards: cardsList,
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
