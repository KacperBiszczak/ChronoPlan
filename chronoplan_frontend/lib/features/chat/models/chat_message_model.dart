class ChatMessageModel {
  final int id;
  final String content;
  final int eventId;
  final int authorId;
  final ChatAuthorModel author;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.content,
    required this.eventId,
    required this.authorId,
    required this.author,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      content: json['content'],
      eventId: json['eventId'],
      authorId: json['authorId'],
      author: ChatAuthorModel.fromJson(json['author']),
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
    );
  }
}

class ChatAuthorModel {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;

  ChatAuthorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory ChatAuthorModel.fromJson(Map<String, dynamic> json) {
    return ChatAuthorModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}