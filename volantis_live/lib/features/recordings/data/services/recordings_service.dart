import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/recording_model.dart';

/// Service for handling recordings API calls
class RecordingsService {
  Dio _dio;
  final String? _authToken;

  RecordingsService(this._dio, {String? authToken}) : _authToken = authToken;

  /// Update the Dio instance (used to sync with ApiService)
  void updateDio(Dio newDio) {
    _dio = newDio;
  }

  Options get _authOptions => Options(
    headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : {},
  );

  /// 1. List recordings with pagination
  /// GET /recordings/public/company/{companySlug}
  Future<List<Recording>> getRecordings(
    String companySlug, {
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/recordings/public/company/$companySlug',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (res.data as List)
        .map((j) => Recording.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// 2. Fetch single recording (increments replay count)
  /// GET /recordings/public/{id}
  Future<Recording> getRecording(int id) async {
    final res = await _dio.get('${ApiConstants.baseUrl}/recordings/public/$id');
    return Recording.fromJson(res.data as Map<String, dynamic>);
  }

  /// 3. Get replay stats (no side effect)
  /// GET /recordings/public/{id}/stats
  Future<Map<String, dynamic>> getStats(int id) async {
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/recordings/public/$id/stats',
    );
    return res.data as Map<String, dynamic>;
  }

  /// 4. Stream audio URL helper
  /// Returns the full streaming URL for a recording
  String getStreamingUrl(String streamingUrl) {
    if (streamingUrl.startsWith('http')) {
      return streamingUrl;
    }
    return '${ApiConstants.baseUrl}$streamingUrl';
  }

  /// 5. Update position (auth required)
  /// POST /recordings/{id}/position?position_seconds={seconds}
  Future<void> updatePosition(int id, int positionSeconds) async {
    if (_authToken == null) return;
    await _dio.post(
      '${ApiConstants.baseUrl}/recordings/$id/position',
      queryParameters: {'position_seconds': positionSeconds},
      options: _authOptions,
    );
  }

  /// 6. Mark complete (auth required)
  /// POST /recordings/{id}/complete
  Future<void> markComplete(int id) async {
    if (_authToken == null) return;
    await _dio.post(
      '${ApiConstants.baseUrl}/recordings/$id/complete',
      options: _authOptions,
    );
  }

  /// 7. Get watch history (auth required)
  /// GET /recordings/my/watch-history
  Future<List<WatchHistoryItem>> getWatchHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/recordings/my/watch-history',
      queryParameters: {'limit': limit, 'offset': offset},
      options: _authOptions,
    );
    final data = res.data as Map<String, dynamic>;
    final list = data['watch_history'] as List;
    return list
        .map((j) => WatchHistoryItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// 8. Get watched recordings (auth required)
  /// GET /recordings/my/watched
  Future<List<WatchHistoryItem>> getWatched({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/recordings/my/watched',
      queryParameters: {'limit': limit, 'offset': offset},
      options: _authOptions,
    );
    final data = res.data as Map<String, dynamic>;
    final list = data['watched'] as List;
    return list
        .map((j) => WatchHistoryItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
