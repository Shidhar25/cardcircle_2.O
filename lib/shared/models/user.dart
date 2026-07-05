import 'credit_card.dart';
import 'badge.dart';

class User {
  final String name;
  final String username;
  final String initials;
  final String level;
  final int levelIndex;
  int points;
  final int pointsToNextLevel;
  final int savings;
  final int streak;
  final List<CreditCard> cards;
  final List<Badge> badges;
  final int friendsCount;
  final int hacksShared;

  User({
    required this.name,
    required this.username,
    required this.initials,
    required this.level,
    required this.levelIndex,
    required this.points,
    required this.pointsToNextLevel,
    required this.savings,
    required this.streak,
    required this.cards,
    required this.badges,
    required this.friendsCount,
    required this.hacksShared,
  });

  User copyWith({
    String? name,
    String? username,
    String? initials,
    String? level,
    int? levelIndex,
    int? points,
    int? pointsToNextLevel,
    int? savings,
    int? streak,
    List<CreditCard>? cards,
    List<Badge>? badges,
    int? friendsCount,
    int? hacksShared,
  }) {
    return User(
      name: name ?? this.name,
      username: username ?? this.username,
      initials: initials ?? this.initials,
      level: level ?? this.level,
      levelIndex: levelIndex ?? this.levelIndex,
      points: points ?? this.points,
      pointsToNextLevel: pointsToNextLevel ?? this.pointsToNextLevel,
      savings: savings ?? this.savings,
      streak: streak ?? this.streak,
      cards: cards ?? this.cards,
      badges: badges ?? this.badges,
      friendsCount: friendsCount ?? this.friendsCount,
      hacksShared: hacksShared ?? this.hacksShared,
    );
  }
}
