/// An aggregate rating: the mean score and how many people gave it.
///
/// The count matters as much as the average. "4.8 from 2 people" and "4.8
/// from 900" are different claims, and showing only the number invites the
/// reader to treat them as the same.
class HackRating {
  final double average;
  final int count;

  const HackRating({required this.average, required this.count});

  static const HackRating none = HackRating(average: 0, count: 0);

  /// Whether anyone has rated this at all. Nothing is rendered when not —
  /// an empty aggregate displayed as "0.0" reads as a terrible score rather
  /// than an absent one.
  bool get hasRatings => count > 0;

  /// Reads `{ "average": 3, "count": 3 }`, tolerating ints, strings and a
  /// missing block.
  static HackRating parse(dynamic json) {
    if (json is! Map) return none;

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final count = asInt(json['count']) ?? 0;
    if (count <= 0) return none;

    return HackRating(average: asDouble(json['average']) ?? 0, count: count);
  }

  /// One decimal place — the backend sends whole numbers for a small sample
  /// (`3`), and rendering that as "3" beside a "4.5" reads inconsistently.
  String get display => average.toStringAsFixed(1);

  @override
  String toString() => 'HackRating($display, $count)';

  @override
  bool operator ==(Object other) =>
      other is HackRating && other.average == average && other.count == count;

  @override
  int get hashCode => Object.hash(average, count);
}
