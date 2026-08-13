import 'package:flutter_test/flutter_test.dart';
import 'package:volantis_live/features/home/data/models/playlist_model.dart';

void main() {
  group('PlaylistItemModel', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': 1,
        'playlist_id': 4,
        'position': 1,
        'is_skipped': false,
        'media_type': 'recording',
        'media_id': 57,
        'title': 'Test Audio',
        'description': 'Test description',
        's3_url': 'https://example.com/audio.mp3',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'duration_seconds': 180,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final item = PlaylistItemModel.fromJson(json);

      expect(item.id, 1);
      expect(item.playlistId, 4);
      expect(item.position, 1);
      expect(item.isSkipped, false);
      expect(item.mediaType, 'recording');
      expect(item.mediaId, 57);
      expect(item.title, 'Test Audio');
      expect(item.description, 'Test description');
      expect(item.mediaUrl, 'https://example.com/audio.mp3');
      expect(item.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(item.durationSeconds, 180);
      expect(item.isAudio, true);
      expect(item.isVideo, false);
    });

    test('fromJson handles video type', () {
      final json = {
        'id': 2,
        'title': 'Test Video',
        'media_type': 'recording',
        's3_url': 'https://example.com/video.mp4',
        'media_subtype': 'video',
      };

      final item = PlaylistItemModel.fromJson(json);

      expect(item.mediaType, 'recording');
      expect(item.isVideo, true);
      expect(item.isAudio, false);
    });

    test('s3_url extension takes precedence over media_subtype', () {
      final json = {
        'id': 3,
        'title': 'MP3 tagged as video',
        'media_type': 'recording',
        's3_url': 'https://example.com/audio.mp3',
        'media_subtype': 'video',
      };

      final item = PlaylistItemModel.fromJson(json);

      expect(item.isAudio, true);
      expect(item.isVideo, false);
    });

    test('streamingUrlAbsolute joins relative paths with base url', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        streamingUrl: '/recordings/stream/57',
      );

      expect(item.streamingUrlAbsolute, 'https://api-dev.volantislive.com/recordings/stream/57');
      expect(item.mediaUrl, 'https://api-dev.volantislive.com/recordings/stream/57');
    });

    test('formattedDuration formats hours correctly', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        durationSeconds: 3723,
      );

      expect(item.formattedDuration, '1:02:03');
    });

    test('formattedDuration formats minutes correctly', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        durationSeconds: 125,
      );

      expect(item.formattedDuration, '2:05');
    });

    test('formattedDuration returns N/A for null duration', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        durationSeconds: null,
      );

      expect(item.formattedDuration, 'N/A');
    });

    test('toJson creates correct map', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        s3Url: 'https://example.com/audio.mp3',
      );

      final json = item.toJson();

      expect(json['id'], 1);
      expect(json['title'], 'Test');
      expect(json['media_type'], 'audio');
      expect(json['s3_url'], 'https://example.com/audio.mp3');
    });
  });

  group('PlaylistModel', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': 1,
        'slug': 'test-playlist',
        'title': 'Test Playlist',
        'description': 'Test description',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'item_count': 2,
        'total_duration_seconds': 3600,
        'is_public': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-02T00:00:00.000Z',
        'items': [
          {
            'id': 1,
            'title': 'Item 1',
            'media_type': 'audio',
            's3_url': 'https://example.com/audio.mp3',
          },
          {
            'id': 2,
            'title': 'Item 2',
            'media_type': 'video',
            's3_url': 'https://example.com/video.mp4',
          },
        ],
      };

      final playlist = PlaylistModel.fromJson(json);

      expect(playlist.id, 1);
      expect(playlist.slug, 'test-playlist');
      expect(playlist.title, 'Test Playlist');
      expect(playlist.description, 'Test description');
      expect(playlist.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(playlist.itemCount, 2);
      expect(playlist.totalDurationSeconds, 3600);
      expect(playlist.isPublic, true);
      expect(playlist.items.length, 2);
      expect(playlist.items[0].title, 'Item 1');
      expect(playlist.items[1].isVideo, true);
    });

    test('fromJson parses the public media endpoint response', () {
      final json = {
        'playlist_id': 4,
        'media': [
          {
            'id': 1,
            'playlist_id': 4,
            'position': 1,
            'is_skipped': false,
            'media_type': 'recording',
            'media_id': 57,
            'title': 'Oceans',
            's3_url': 'https://example.com/video.mp4',
          },
          {
            'id': 2,
            'playlist_id': 4,
            'position': 2,
            'is_skipped': false,
            'media_type': 'recording',
            'media_id': 56,
            'title': 'Testament Of Love',
            's3_url': 'https://example.com/audio.mp3',
          },
        ],
        'total': 4,
      };

      final playlist = PlaylistModel.fromJson(json);

      expect(playlist.id, 4);
      expect(playlist.itemCount, 4);
      expect(playlist.items.length, 2);
      expect(playlist.items[0].isVideo, true);
      expect(playlist.items[1].isAudio, true);
    });

    test('fromJson handles null values gracefully', () {
      final json = <String, dynamic>{
        'id': 1,
        'slug': 'test-playlist',
        'title': 'Test',
        'is_public': true,
      };

      final playlist = PlaylistModel.fromJson(json);

      expect(playlist.description, null);
      expect(playlist.thumbnailUrl, null);
      expect(playlist.totalDurationSeconds, null);
      expect(playlist.items, isEmpty);
    });

    test('copyWith updates items and itemCount', () {
      final playlist = PlaylistModel(
        id: 1,
        slug: 'test',
        title: 'Test',
        itemCount: 0,
        isPublic: true,
      );

      final updated = playlist.copyWith(
        items: [
          PlaylistItemModel(
            id: 1,
            title: 'Item 1',
            s3Url: 'https://example.com/audio.mp3',
          ),
        ],
        itemCount: 1,
      );

      expect(updated.itemCount, 1);
      expect(updated.items.length, 1);
    });

    test('formattedTotalDuration formats hours correctly', () {
      final playlist = PlaylistModel(
        id: 1,
        slug: 'test',
        title: 'Test',
        itemCount: 5,
        totalDurationSeconds: 7200,
        isPublic: true,
      );

      expect(playlist.formattedTotalDuration, '2h 0m');
    });

    test('formattedTotalDuration formats minutes correctly', () {
      final playlist = PlaylistModel(
        id: 1,
        slug: 'test',
        title: 'Test',
        itemCount: 5,
        totalDurationSeconds: 1830,
        isPublic: true,
      );

      expect(playlist.formattedTotalDuration, '30m');
    });

    test('formattedTotalDuration returns empty for null duration', () {
      final playlist = PlaylistModel(
        id: 1,
        slug: 'test',
        title: 'Test',
        itemCount: 5,
        totalDurationSeconds: null,
        isPublic: true,
      );

      expect(playlist.formattedTotalDuration, '');
    });

    test('toJson creates correct map', () {
      final playlist = PlaylistModel(
        id: 1,
        slug: 'test-playlist',
        title: 'Test Playlist',
        itemCount: 1,
        isPublic: true,
        items: [
          PlaylistItemModel(
            id: 1,
            title: 'Item 1',
            mediaType: 'audio',
            s3Url: 'https://example.com/audio.mp3',
          ),
        ],
      );

      final json = playlist.toJson();

      expect(json['id'], 1);
      expect(json['slug'], 'test-playlist');
      expect(json['title'], 'Test Playlist');
      expect(json['is_public'], true);
      expect((json['items'] as List).length, 1);
    });
  });
}
