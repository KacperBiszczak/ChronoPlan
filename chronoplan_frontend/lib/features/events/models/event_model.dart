class EventModel {
  final int id;
  final String title;
  final String? description;
  final DateTime date;
  final int creatorId;

  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;

  final String? googleCalendarEventId;
  final DateTime? googleCalendarSyncedAt;

  final String budgetMode;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.creatorId,
    required this.locationName,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.googleCalendarEventId,
    required this.googleCalendarSyncedAt,
    required this.budgetMode,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']).toLocal(),
      creatorId: json['creatorId'],
      locationName: json['locationName'],
      locationAddress: json['locationAddress'],
      latitude: json['latitude'] == null ? null : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null ? null : (json['longitude'] as num).toDouble(),
      googleCalendarEventId: json['googleCalendarEventId'],
      googleCalendarSyncedAt: json['googleCalendarSyncedAt'] == null
          ? null
          : DateTime.parse(json['googleCalendarSyncedAt']).toLocal(),
      budgetMode: json['budgetMode'] ?? 'SHARED',
    );
  }
}