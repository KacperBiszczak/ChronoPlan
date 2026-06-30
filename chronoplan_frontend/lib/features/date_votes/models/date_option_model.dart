class DateOptionModel {
  final int id;
  final DateTime proposedDate;
  final int eventId;
  final List<DateVoteModel> votes;

  DateOptionModel({
    required this.id,
    required this.proposedDate,
    required this.eventId,
    required this.votes,
  });

  factory DateOptionModel.fromJson(Map<String, dynamic> json) {
    final votesData = json['votes'] as List? ?? [];

    return DateOptionModel(
      id: json['id'],
      proposedDate: DateTime.parse(json['proposedDate']).toLocal(),
      eventId: json['eventId'],
      votes: votesData.map((item) => DateVoteModel.fromJson(item)).toList(),
    );
  }
}

class DateVoteModel {
  final int id;
  final String status;
  final int optionId;
  final int userId;
  final DateVoteUserModel? user;

  DateVoteModel({
    required this.id,
    required this.status,
    required this.optionId,
    required this.userId,
    required this.user,
  });

  factory DateVoteModel.fromJson(Map<String, dynamic> json) {
    return DateVoteModel(
      id: json['id'],
      status: json['status'],
      optionId: json['optionId'],
      userId: json['userId'],
      user: json['user'] == null
          ? null
          : DateVoteUserModel.fromJson(json['user']),
    );
  }
}

class DateVoteUserModel {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;

  DateVoteUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory DateVoteUserModel.fromJson(Map<String, dynamic> json) {
    return DateVoteUserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}