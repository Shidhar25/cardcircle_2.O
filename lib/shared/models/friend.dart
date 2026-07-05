import 'package:flutter/material.dart';

class Friend {
  final String id;
  final String name;
  final String username;
  final String initials;
  final int cardsCount;
  final String savings;
  final String level;
  bool isFollowing;
  final List<String> commonCards;
  final List<Color> gradientColors;

  Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.initials,
    required this.cardsCount,
    required this.savings,
    required this.level,
    required this.isFollowing,
    required this.commonCards,
    required this.gradientColors,
  });
}
