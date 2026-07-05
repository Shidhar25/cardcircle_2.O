import 'package:flutter/material.dart';

class Badge {
  final String id;
  final String name;
  final String iconName;
  final String description;
  final bool earned;
  final String rarity; // 'common' | 'rare' | 'epic' | 'legendary'
  final Color color;

  Badge({
    required this.id,
    required this.name,
    required this.iconName,
    required this.description,
    required this.earned,
    required this.rarity,
    required this.color,
  });
}
