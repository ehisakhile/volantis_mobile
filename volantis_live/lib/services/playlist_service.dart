import 'package:dio/dio.dart';
import 'package:volantis_live/core/constants/api_constants.dart';
import 'package:volantis_live/features/home/data/models/playlist_model.dart';
import 'package:volantis_live/services/api_service.dart';

class PlaylistService {
  static PlaylistService? _instance;
  final ApiService _apiService = ApiService.instance;

  PlaylistService._();

  static PlaylistService get instance {
    _instance ??= PlaylistService._();
    return _instance!;
  }

  Future<List<PlaylistModel>> getCompanyPlaylists(String companySlug) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getCompanyPlaylistsEndpoint(companySlug),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => PlaylistModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final playlists = data['playlists'] as List<dynamic>? ?? [];
        return playlists
            .map((json) => PlaylistModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      print('PlaylistService: Error loading playlists - ${e.message}');
      rethrow;
    }
  }

  Future<PlaylistModel> getPlaylistDetail(
    String companySlug,
    String playlistSlug, {
    bool includeItems = true,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getPlaylistDetailEndpoint(companySlug, playlistSlug),
        queryParameters: {'include_items': includeItems},
      );

      final playlist =
          PlaylistModel.fromJson(response.data as Map<String, dynamic>);

      if (includeItems && playlist.items.isEmpty) {
        try {
          final items = await getPlaylistMedia(playlist.id);
          return playlist.copyWith(items: items, itemCount: items.length);
        } catch (e) {
          print('PlaylistService: Error loading media items - $e');
        }
      }

      return playlist;
    } on DioException catch (e) {
      print('PlaylistService: Error loading playlist detail - ${e.message}');
      rethrow;
    }
  }

  Future<List<PlaylistItemModel>> getPlaylistItems(
    String companySlug,
    String playlistSlug,
  ) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getPlaylistItemsEndpoint(companySlug, playlistSlug),
      );
      return _parseMediaResponse(response.data);
    } on DioException catch (e) {
      print('PlaylistService: Error loading playlist items - ${e.message}');
      rethrow;
    }
  }

  /// Fetch the media items of a playlist via
  /// `GET /playlists/public/{playlistId}/media`.
  Future<List<PlaylistItemModel>> getPlaylistMedia(int playlistId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getPlaylistMediaEndpoint(playlistId),
      );
      return _parseMediaResponse(response.data);
    } on DioException catch (e) {
      print('PlaylistService: Error loading playlist media - ${e.message}');
      rethrow;
    }
  }

  List<PlaylistItemModel> _parseMediaResponse(dynamic data) {
    final List<dynamic> media;
    if (data is List) {
      media = data;
    } else if (data is Map<String, dynamic>) {
      media = data['media'] as List<dynamic>? ?? [];
    } else {
      return [];
    }
    return media
        .map((json) => PlaylistItemModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PlaylistModel> createPlaylist({
    required String companySlug,
    required String title,
    String? description,
    bool isPublic = true,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.createPlaylist,
        data: {
          'company_slug': companySlug,
          'title': title,
          'description': description,
          'is_public': isPublic,
        },
      );

      return PlaylistModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('PlaylistService: Error creating playlist - ${e.message}');
      rethrow;
    }
  }

  Future<PlaylistModel> updatePlaylist({
    required int playlistId,
    String? title,
    String? description,
    bool? isPublic,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (isPublic != null) data['is_public'] = isPublic;

      final response = await _apiService.put(
        ApiConstants.updatePlaylistEndpoint(playlistId.toString()),
        data: data,
      );

      return PlaylistModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('PlaylistService: Error updating playlist - ${e.message}');
      rethrow;
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _apiService.delete(
        ApiConstants.deletePlaylistEndpoint(playlistId.toString()),
      );
    } on DioException catch (e) {
      print('PlaylistService: Error deleting playlist - ${e.message}');
      rethrow;
    }
  }

  Future<PlaylistItemModel> addItemToPlaylist({
    required int playlistId,
    required String title,
    String? description,
    required String mediaType,
    required String mediaUrl,
    String? thumbnailUrl,
    int? durationSeconds,
  }) async {
    try {
      final response = await _apiService.post(
        '/creator/playlists/$playlistId/items',
        data: {
          'title': title,
          'description': description,
          'media_type': mediaType,
          'media_url': mediaUrl,
          'thumbnail_url': thumbnailUrl,
          'duration_seconds': durationSeconds,
        },
      );

      return PlaylistItemModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('PlaylistService: Error adding item to playlist - ${e.message}');
      rethrow;
    }
  }

  Future<void> removeItemFromPlaylist({
    required int playlistId,
    required int itemId,
  }) async {
    try {
      await _apiService.delete(
        '/creator/playlists/$playlistId/items/$itemId',
      );
    } on DioException catch (e) {
      print('PlaylistService: Error removing item from playlist - ${e.message}');
      rethrow;
    }
  }

  Future<void> reorderPlaylistItems({
    required int playlistId,
    required List<int> itemIds,
  }) async {
    try {
      await _apiService.put(
        '/creator/playlists/$playlistId/reorder',
        data: {'item_ids': itemIds},
      );
    } on DioException catch (e) {
      print('PlaylistService: Error reordering playlist items - ${e.message}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadMedia({
    required String filePath,
    required String mediaType,
    Function(int, int)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'media_type': mediaType,
      });

      final response = await _apiService.uploadFile(
        mediaType == 'video'
            ? ApiConstants.creatorUploadVideo
            : ApiConstants.creatorUploadAudio,
        formData: formData,
        onSendProgress: onProgress,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('PlaylistService: Error uploading media - ${e.message}');
      rethrow;
    }
  }
}