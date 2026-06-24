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

  Future<List<ParticipantModel>> getMyInvitations() async {
    final token = await _getToken();

    final response = await _dio.get(
      '/participants/my-invitations',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as List;

    return data.map((item) => ParticipantModel.fromJson(item)).toList();
  }

  Future<ParticipantModel> updateInvitationStatus({
    required int participantId,
    required String status,
  }) async {
    final token = await _getToken();

    final response = await _dio.patch(
      '/participants/$participantId/status',
      data: {
        'status': status,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return ParticipantModel.fromJson(response.data);
  }

  Future<void> deleteParticipant(int participantId) async {
    final token = await _getToken();

    await _dio.delete(
      '/participants/$participantId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  Future<void> leaveEvent(int eventId) async {
    final token = await _getToken();

    await _dio.delete(
      '/participants/event/$eventId/leave',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}