import '../../../core/services/api_client.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final _dio = ApiClient.dio;

  Future<List<ChatMessageModel>> getMessagesByEvent(int eventId) async {
    final response = await _dio.get('/chat/event/$eventId');

    final data = response.data as List;

    return data.map((item) => ChatMessageModel.fromJson(item)).toList();
  }

  Future<ChatMessageModel> sendMessage({
    required int eventId,
    required String content,
  }) async {
    final response = await _dio.post(
      '/chat/messages',
      data: {
        'eventId': eventId,
        'content': content,
      },
    );

    return ChatMessageModel.fromJson(response.data);
  }
}