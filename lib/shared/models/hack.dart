class Hack {
  final String id;
  final String title;
  final String description;
  final String cardName;
  final String savings;
  int likes;
  final String author;
  final String authorInitials;
  final String authorLevel;
  final bool isLocked;
  final String category;
  final String timestamp;
  bool liked;

  Hack({
    required this.id,
    required this.title,
    required this.description,
    required this.cardName,
    required this.savings,
    required this.likes,
    required this.author,
    required this.authorInitials,
    required this.authorLevel,
    required this.isLocked,
    required this.category,
    required this.timestamp,
    required this.liked,
  });
}
