class ProfileData {
  final String name;
  final String username;
  final String dob;
  final String email;
  final String phone;
  final int avatarColorIndex;
  final String initials;

  ProfileData({
    required this.name,
    required this.username,
    required this.dob,
    required this.email,
    required this.phone,
    required this.avatarColorIndex,
    required this.initials,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'dob': dob,
    'email': email,
    'phone': phone,
    'avatarColorIndex': avatarColorIndex,
    'initials': initials,
  };

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
    name: json['name'],
    username: json['username'],
    dob: json['dob'],
    email: json['email'],
    phone: json['phone'],
    avatarColorIndex: json['avatarColorIndex'],
    initials: json['initials'],
  );
}
