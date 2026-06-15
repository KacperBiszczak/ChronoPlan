class EventModel {
  final int id;
  final String title;
  final String? description;
  final DateTime date;
  final int creatorId;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.creatorId,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      creatorId: json['creatorId'],
    );
  }
}