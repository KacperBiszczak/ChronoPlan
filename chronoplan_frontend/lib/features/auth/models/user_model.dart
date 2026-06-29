class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? phone;
  final String? bio;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.phone,
    required this.bio,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      phone: json['phone'],
      bio: json['bio'],
    );
  }
}