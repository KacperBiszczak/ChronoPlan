class ParticipantUserModel {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;

  ParticipantUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory ParticipantUserModel.fromJson(Map<String, dynamic> json) {
    return ParticipantUserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class ParticipantEventModel {
  final int id;
  final String title;
  final String? description;
  final DateTime date;
  final ParticipantUserModel? creator;

  ParticipantEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.creator,
  });

  factory ParticipantEventModel.fromJson(Map<String, dynamic> json) {
    return ParticipantEventModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']).toLocal(),
      creator: json['creator'] != null
          ? ParticipantUserModel.fromJson(json['creator'])
          : null,
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
  final ParticipantEventModel? event;

  ParticipantModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.role,
    required this.status,
    required this.user,
    required this.event,
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
      event: json['event'] != null
          ? ParticipantEventModel.fromJson(json['event'])
          : null,
    );
  }
}