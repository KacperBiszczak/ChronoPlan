import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_client.dart';
import '../models/participant_model.dart';

class ParticipantService {
  final _dio = ApiClient.dio;
  final _storage = const FlutterSecureStorage();

  Future<String> _getToken() async {
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Brak tokenu użytkownika');
    }

    return token;
  }

  Future<List<ParticipantModel>> getParticipantsByEvent(int eventId) async {
    final token = await _getToken();

    final response = await _dio.get(
      '/participants/event/$eventId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as List;

    return data.map((item) => ParticipantModel.fromJson(item)).toList();
  }

  Future<ParticipantModel> inviteParticipant({
    required int eventId,
    required String email,
  }) async {
    final token = await _getToken();

    final response = await _dio.post(
      '/participants/invite',
      data: {
        'eventId': eventId,
        'email': email,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return ParticipantModel.fromJson(response.data);
  }
}