import 'package:flutter_test/flutter_test.dart';
import 'package:volantis_live/features/home/data/models/playlist_model.dart';

void main() {
  group('PlaylistItemModel', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': 1,
        'title': 'Test Audio',
        'description': 'Test description',
        'media_type': 'audio',
        'media_url': 'https://example.com/audio.mp3',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'duration_seconds': 180,
        'order': 0,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final item = PlaylistItemModel.fromJson(json);

      expect(item.id, 1);
      expect(item.title, 'Test Audio');
      expect(item.description, 'Test description');
      expect(item.mediaType, 'audio');
      expect(item.mediaUrl, 'https://example.com/audio.mp3');
      expect(item.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(item.durationSeconds, 180);
      expect(item.order, 0);
      expect(item.isAudio, true);
      expect(item.isVideo, false);
    });

    test('fromJson handles video type', () {
      final json = {
        'id': 2,
        'title': 'Test Video',
        'media_type': 'video',
        'media_url': 'https://example.com/video.mp4',
        'order': 1,
      };

      final item = PlaylistItemModel.fromJson(json);

      expect(item.mediaType, 'video');
      expect(item.isVideo, true);
      expect(item.isAudio, false);
    });

    test('formattedDuration formats hours correctly', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        order: 0,
        durationSeconds: 3723,
      );

      expect(item.formattedDuration, '1:02:03');
    });

    test('formattedDuration formats minutes correctly', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        order: 0,
        durationSeconds: 125,
      );

      expect(item.formattedDuration, '2:05');
    });

    test('formattedDuration returns N/A for null duration', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        order: 0,
        durationSeconds: null,
      );

      expect(item.formattedDuration, 'N/A');
    });

    test('toJson creates correct map', () {
      final item = PlaylistItemModel(
        id: 1,
        title: 'Test',
        mediaType: 'audio',
        order: 0,
      );

      final json = item.toJson();

      expect(json['id'], 1);
      expect(json['title'], 'Test');
      expect(json['media_type'], 'audio');
      expect(json['order'], 0);
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
        'item_count': 5,
        'total_duration_seconds': 3600,
        'is_public': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-02T00:00:00.000Z',
        'items': [
          {
            'id': 1,
            'title': 'Item 1',
            'media_type': 'audio',
            'order': 0,
          },
          {
            'id': 2,
            'title': 'Item 2',
            'media_type': 'video',
            'order': 1,
          },
        ],
      };

      final playlist = PlaylistModel.fromJson(json);

      expect(playlist.id, 1);
      expect(playlist.slug, 'test-playlist');
      expect(playlist.title, 'Test Playlist');
      expect(playlist.description, 'Test description');
      expect(playlist.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(playlist.itemCount, 5);
      expect(playlist.totalDurationSeconds, 3600);
      expect(playlist.isPublic, true);
      expect(playlist.items.length, 2);
      expect(playlist.items[0].title, 'Item 1');
      expect(playlist.items[1].isVideo, true);
    });

    test('fromJson handles items from item_count when items not provided', () {
      final json = {
        'id': 1,
        'slug': 'test-playlist',
        'title': 'Test Playlist',
        'item_count': 3,
        'is_public': true,
        'items': [],
      };

      final playlist = PlaylistModel.fromJson(json);

      expect(playlist.itemCount, 3);
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
        itemCount: 2,
        isPublic: true,
        items: [
          PlaylistItemModel(
            id: 1,
            title: 'Item 1',
            mediaType: 'audio',
            order: 0,
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