import '../../../core/services/api_client.dart';
import '../models/participant_model.dart';

class ParticipantService {
  final _dio = ApiClient.dio;

  Future<List<ParticipantModel>> getParticipantsByEvent(int eventId) async {
    final response = await _dio.get('/participants/event/$eventId');

    final data = response.data as List;

    return data.map((item) => ParticipantModel.fromJson(item)).toList();
  }

  Future<ParticipantModel> inviteParticipant({
    required int eventId,
    required String email,
  }) async {
    final response = await _dio.post(
      '/participants/invite',
      data: {
        'eventId': eventId,
        'email': email,
      },
    );

    return ParticipantModel.fromJson(response.data);
  }

  Future<List<ParticipantModel>> getMyInvitations() async {
    final response = await _dio.get('/participants/my-invitations');

    final data = response.data as List;

    return data.map((item) => ParticipantModel.fromJson(item)).toList();
  }

  Future<ParticipantModel> updateInvitationStatus({
    required int participantId,
    required String status,
  }) async {
    final response = await _dio.patch(
      '/participants/$participantId/status',
      data: {
        'status': status,
      },
    );

    return ParticipantModel.fromJson(response.data);
  }

  Future<void> deleteParticipant(int participantId) async {
    await _dio.delete('/participants/$participantId');
  }

  Future<void> leaveEvent(int eventId) async {
    await _dio.delete('/participants/event/$eventId/leave');
  }
}