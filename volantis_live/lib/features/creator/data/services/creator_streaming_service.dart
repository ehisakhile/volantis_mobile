import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../models/creator_stream_model.dart';

class CreatorStreamingService {
  final ApiService _apiService = ApiService.instance;

  Future<CreatorStream> startAudioStream({
    required String title,
    String? description,
    File? thumbnail,
  }) async {
    if (thumbnail != null) {
      final formData = FormData();
      formData.fields.add(MapEntry('title', title));
      if (description != null) {
        formData.fields.add(MapEntry('description', description));
      }
      formData.files.add(
        MapEntry(
          'thumbnail',
          await MultipartFile.fromFile(
            thumbnail.path,
            filename: 'thumbnail.jpg',
          ),
        ),
      );

      final response = await _apiService.post(
        ApiConstants.startAudioStream,
        data: formData,
      );
      return CreatorStream.fromJson(response.data);
    } else {
      final response = await _apiService.post(
        ApiConstants.startAudioStream,
        data: {
          'title': title,
          if (description != null) 'description': description,
        },
      );
      return CreatorStream.fromJson(response.data);
    }
  }

  Future<CreatorStream> startVideoStream({
    required String title,
    String? description,
  }) async {
    final response = await _apiService.post(
      ApiConstants.startVideoStream,
      data: {
        'title': title,
        if (description != null) 'description': description,
      },
    );
    return CreatorStream.fromJson(response.data);
  }

  Future<CreatorStream> stopStream(String slug) async {
    final response = await _apiService.post(
      ApiConstants.getStopStreamEndpoint(slug),
    );
    return CreatorStream.fromJson(response.data);
  }

  Future<List<CreatorStream>> getUserStreams({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiService.get(
      ApiConstants.getUserStreams,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => CreatorStream.fromJson(json)).toList();
  }

  Future<CreatorStream?> getActiveStream() async {
    final streams = await getUserStreams();
    try {
      return streams.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<CreatorStream> getStreamBySlug(String slug) async {
    final response = await _apiService.get(
      ApiConstants.getStreamBySlugEndpoint(slug),
    );
    return CreatorStream.fromJson(response.data);
  }

  Future<String> uploadRecording({
    required String slug,
    required File recording,
    String? description,
    int? durationSeconds,
  }) async {
    final formData = FormData();
    formData.files.add(
      MapEntry(
        'recording',
        await MultipartFile.fromFile(recording.path, filename: 'recording.mp4'),
      ),
    );
    if (description != null) {
      formData.fields.add(MapEntry('description', description));
    }
    if (durationSeconds != null) {
      formData.fields.add(
        MapEntry('duration_seconds', durationSeconds.toString()),
      );
    }

    final response = await _apiService.post(
      ApiConstants.getUploadRecordingEndpoint(slug),
      data: formData,
    );
    return response.data['recording_url'] ?? '';
  }

  Future<StreamStats> getRealtimeStats(String slug) async {
    final response = await _apiService.get(
      ApiConstants.getRealtimeStatsEndpoint(slug),
    );
    return StreamStats.fromJson(response.data);
  }

  Future<StreamStats> getViewerCount(String slug, int companyId) async {
    final response = await _apiService.get(
      ApiConstants.getViewerCountEndpoint(slug, companyId),
    );
    return StreamStats.fromJson(response.data);
  }

  Future<List<ChatMessage>> getChatMessages(
    String slug, {
    int page = 1,
    int size = 50,
  }) async {
    final response = await _apiService.get(
      ApiConstants.getChatMessagesEndpoint(slug, page: page, size: size),
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<ChatMessage> sendChatMessage(String slug, String content) async {
    final response = await _apiService.post(
      ApiConstants.getSendChatMessageEndpoint(slug),
      data: {'content': content},
    );
    return ChatMessage.fromJson(response.data);
  }

  Future<void> editChatMessage(int messageId, String content) async {
    await _apiService.put(
      ApiConstants.getEditChatMessageEndpoint(messageId.toString()),
      data: {'content': content},
    );
  }

  Future<void> deleteChatMessage(int messageId) async {
    await _apiService.delete(
      ApiConstants.getDeleteChatMessageEndpoint(messageId.toString()),
    );
  }
}
