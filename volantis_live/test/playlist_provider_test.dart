import 'package:flutter_test/flutter_test.dart';
import 'package:volantis_live/features/home/data/models/playlist_model.dart';
import 'package:volantis_live/features/home/presentation/providers/playlist_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlaylistModel testPlaylist;

  setUp(() {
    testPlaylist = PlaylistModel(
      id: 1,
      slug: 'test',
      title: 'Test',
      itemCount: 3,
      isPublic: true,
      items: [
        PlaylistItemModel(
          id: 1,
          title: 'Item 1',
          s3Url: 'https://example.com/audio.mp3',
        ),
        PlaylistItemModel(
          id: 2,
          title: 'Item 2',
          s3Url: 'https://example.com/audio2.mp3',
        ),
        PlaylistItemModel(
          id: 3,
          title: 'Item 3',
          s3Url: 'https://example.com/video.mp4',
        ),
      ],
    );
  });

  group('PlaylistProvider', () {
    late PlaylistProvider provider;

    setUp(() {
      provider = PlaylistProvider();
    });

    test('initial state is correct', () {
      expect(provider.playlists, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, null);
    });

    test('clearPlaylists resets state', () {
      provider.clearPlaylists();

      expect(provider.playlists, isEmpty);
      expect(provider.error, null);
    });
  });

  group('PlaylistPlayerProvider', () {
    late PlaylistPlayerProvider provider;

    setUp(() {
      provider = PlaylistPlayerProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state is correct', () {
      expect(provider.currentPlaylist, null);
      expect(provider.currentIndex, -1);
      expect(provider.isPlaying, false);
      expect(provider.isLoading, false);
      expect(provider.error, null);
      expect(provider.currentItem, null);
      expect(provider.nextItem, null);
      expect(provider.hasNext, false);
      expect(provider.hasPrevious, false);
    });

    test('currentItem returns null when playlist is null', () {
      expect(provider.currentItem, null);
    });

    test('playItem does nothing when no playlist is loaded', () async {
      await provider.playItem(testPlaylist.items[0]);

      expect(provider.currentIndex, -1);
      expect(provider.isPlaying, false);
    });

    test('togglePlayPause is a no-op without a current item', () async {
      expect(provider.isPlaying, false);

      await provider.togglePlayPause();
      expect(provider.isPlaying, false);

      await provider.togglePlayPause();
      expect(provider.isPlaying, false);
    });

    test('setPlaying sets isPlaying state', () {
      provider.setPlaying(true);
      expect(provider.isPlaying, true);

      provider.setPlaying(false);
      expect(provider.isPlaying, false);
    });

    test('reset clears all state', () {
      provider.setPlaying(true);

      provider.reset();

      expect(provider.currentPlaylist, null);
      expect(provider.currentIndex, -1);
      expect(provider.isPlaying, false);
      expect(provider.isLoading, false);
      expect(provider.error, null);
    });

    test('hasNext returns false for empty playlist', () {
      expect(provider.hasNext, false);
    });

    test('hasPrevious returns false when at index 0', () {
      expect(provider.hasPrevious, false);
    });
  });

  group('PlaylistProvider integration logic', () {
    test('PlaylistModel items are accessible', () {
      final playlist = PlaylistModel(
        id: 1,
        slug: 'test',
        title: 'Test',
        itemCount: 3,
        isPublic: true,
        items: [
          PlaylistItemModel(
            id: 1,
            title: 'Item 1',
            s3Url: 'https://example.com/audio.mp3',
          ),
          PlaylistItemModel(
            id: 2,
            title: 'Item 2',
            s3Url: 'https://example.com/audio2.mp3',
          ),
          PlaylistItemModel(
            id: 3,
            title: 'Item 3',
            s3Url: 'https://example.com/video.mp4',
          ),
        ],
      );

      expect(playlist.items.length, 3);
      expect(playlist.items[0].isAudio, true);
      expect(playlist.items[2].isVideo, true);
    });

    test('PlaylistItemModel formattedDuration works', () {
      expect(
        PlaylistItemModel(
          id: 1,
          title: 'Test',
          mediaType: 'audio',
          durationSeconds: null,
        ).formattedDuration,
        'N/A',
      );
      expect(
        PlaylistItemModel(
          id: 1,
          title: 'Test',
          mediaType: 'audio',
          durationSeconds: 90,
        ).formattedDuration,
        '1:30',
      );
      expect(
        PlaylistItemModel(
          id: 1,
          title: 'Test',
          mediaType: 'audio',
          durationSeconds: 3661,
        ).formattedDuration,
        '1:01:01',
      );
    });
  });
}
