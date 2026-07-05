import 'package:flutter/material.dart';

class CreditCard {
  final String id;
  final String name;
  final String bank;
  final String lastFour;
  final List<Color> gradientColors;
  final String type;
  final String category;

  CreditCard({
    required this.id,
    required this.name,
    required this.bank,
    required this.lastFour,
    required this.gradientColors,
    required this.type,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bank': bank,
        'lastFour': lastFour,
        'gradientColors': gradientColors.map((c) => c.value).toList(),
        'type': type,
        'category': category,
      };

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id'],
        name: json['name'],
        bank: json['bank'],
        lastFour: json['lastFour'],
        gradientColors: (json['gradientColors'] as List)
            .map((val) => Color(val as int))
            .toList(),
        type: json['type'],
        category: json['category'],
      );
}
