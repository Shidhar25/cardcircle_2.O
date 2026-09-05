import 'credit_card.dart';

class User {
  final String name;
  final String username;
  final String initials;
  final String level;
  final int levelIndex;
  int points;
  final int pointsToNextLevel;
  final int streak;
  final List<CreditCard> cards;
  final int friendsCount;
  final int hacksShared;
  final int followersCount;
  final int followingCount;

  User({
    required this.name,
    required this.username,
    required this.initials,
    required this.level,
    required this.levelIndex,
    required this.points,
    required this.pointsToNextLevel,
    required this.streak,
    required this.cards,
    required this.friendsCount,
    required this.hacksShared,
    required this.followersCount,
    required this.followingCount,
  });

  User copyWith({
    String? name,
    String? username,
    String? initials,
    String? level,
    int? levelIndex,
    int? points,
    int? pointsToNextLevel,
    int? streak,
    List<CreditCard>? cards,
    int? friendsCount,
    int? hacksShared,
    int? followersCount,
    int? followingCount,
  }) {
    return User(
      name: name ?? this.name,
      username: username ?? this.username,
      initials: initials ?? this.initials,
      level: level ?? this.level,
      levelIndex: levelIndex ?? this.levelIndex,
      points: points ?? this.points,
      pointsToNextLevel: pointsToNextLevel ?? this.pointsToNextLevel,
      streak: streak ?? this.streak,
      cards: cards ?? this.cards,
      friendsCount: friendsCount ?? this.friendsCount,
      hacksShared: hacksShared ?? this.hacksShared,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
