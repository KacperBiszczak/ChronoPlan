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

class TaskModel {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int eventId;
  final int? assigneeId;
  final TaskAssigneeModel? assignee;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.eventId,
    required this.assigneeId,
    required this.assignee,
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
    );
  }
}