import 'package:dio/dio.dart';

import '../../../../services/api_service.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  final ApiService _apiService = ApiService.instance;

  Future<List<ChatMessageModel>> getMessages(
    String slug, {
    int page = 1,
    int size = 50,
  }) async {
    try {
      final response = await _apiService.get(
        '/livestream-chat/$slug/messages',
        queryParameters: {'page': page, 'size': size},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatMessageModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<ChatMessageModel?> sendMessage(String slug, String content) async {
    try {
      final response = await _apiService.post(
        '/livestream-chat/$slug/messages',
        data: {'content': content},
        options: Options(contentType: Headers.jsonContentType),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessageModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ChatMessageModel?> editMessage(int messageId, String content) async {
    try {
      final response = await _apiService.put(
        '/livestream-chat/messages/$messageId/edit',
        data: {'content': content},
        options: Options(contentType: Headers.jsonContentType),
      );

      if (response.statusCode == 200) {
        return ChatMessageModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteMessage(int messageId) async {
    try {
      final response = await _apiService.delete(
        '/livestream-chat/messages/$messageId',
        options: Options(contentType: Headers.jsonContentType),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}
