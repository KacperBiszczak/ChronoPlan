class TaskAssigneeModel {
  final int id;
  final String name;
  final String email;

  TaskAssigneeModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory TaskAssigneeModel.fromJson(Map<String, dynamic> json) {
    return TaskAssigneeModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

class TaskEventModel {
  final int id;
  final String title;
  final String? description;
  final DateTime date;

  TaskEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
  });

  factory TaskEventModel.fromJson(Map<String, dynamic> json) {
    return TaskEventModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']).toLocal(),
    );
  }
}

class TaskModel {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int eventId;
  final int? assigneeId;
  final TaskAssigneeModel? assignee;
  final TaskEventModel? event;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.eventId,
    required this.assigneeId,
    required this.assignee,
    required this.event,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      eventId: json['eventId'],
      assigneeId: json['assigneeId'],
      assignee: json['assignee'] != null
          ? TaskAssigneeModel.fromJson(json['assignee'])
          : null,
      event: json['event'] != null
          ? TaskEventModel.fromJson(json['event'])
          : null,
    );
  }
}