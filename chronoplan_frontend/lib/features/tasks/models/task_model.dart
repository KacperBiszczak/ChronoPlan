class TaskModel {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int eventId;
  final int? assigneeId;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.eventId,
    required this.assigneeId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      eventId: json['eventId'],
      assigneeId: json['assigneeId'],
    );
  }
}