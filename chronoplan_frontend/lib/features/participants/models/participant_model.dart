class ParticipantUserModel {
  final int id;
  final String name;
  final String email;

  ParticipantUserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory ParticipantUserModel.fromJson(Map<String, dynamic> json) {
    return ParticipantUserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

class ParticipantModel {
  final int id;
  final int eventId;
  final int userId;
  final String role;
  final String status;
  final ParticipantUserModel? user;

  ParticipantModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.role,
    required this.status,
    required this.user,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'],
      eventId: json['eventId'],
      userId: json['userId'],
      role: json['role'],
      status: json['status'],
      user: json['user'] != null
          ? ParticipantUserModel.fromJson(json['user'])
          : null,
    );
  }
}