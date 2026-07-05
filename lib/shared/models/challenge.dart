class Challenge {
  final String id;
  final String title;
  final String description;
  final int progress;
  final int total;
  final int rewardPoints;
  final int daysLeft;
  bool completed;
  bool claimed;
  final String iconName;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.total,
    required this.rewardPoints,
    required this.daysLeft,
    required this.completed,
    required this.claimed,
    required this.iconName,
  });
}
