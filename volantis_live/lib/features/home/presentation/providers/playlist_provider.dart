import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../../../home/data/models/playlist_model.dart';
import 'package:volantis_live/services/playlist_service.dart';
import 'package:volantis_live/services/audio_manager.dart';

class PlaylistProvider extends ChangeNotifier {
  final PlaylistService _playlistService = PlaylistService.instance;

  List<PlaylistModel> _playlists = [];
  bool _isLoading = false;
  String? _error;

  List<PlaylistModel> get playlists => _playlists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPlaylists(String companySlug) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _playlists = await _playlistService.getCompanyPlaylists(companySlug);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPlaylists(String companySlug) async {
    await loadPlaylists(companySlug);
  }

  void clearPlaylists() {
    _playlists = [];
    _error = null;
    notifyListeners();
  }
}

class PlaylistPlayerProvider extends ChangeNotifier {
  PlaylistModel? _currentPlaylist;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;

  VideoPlayerController? _videoController;

  StreamSubscription<AudioState>? _audioSubscription;

  PlaylistPlayerProvider() {
    _audioSubscription =
        AudioManager.instance.stateStream.listen(_onAudioStateChanged);
  }

  PlaylistModel? get currentPlaylist => _currentPlaylist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PlaylistItemModel? get currentItem {
    if (_currentPlaylist == null ||
        _currentPlaylist!.items.isEmpty ||
        _currentIndex >= _currentPlaylist!.items.length) {
      return null;
    }
    return _currentPlaylist!.items[_currentIndex];
  }

  PlaylistItemModel? get nextItem {
    if (_currentPlaylist == null ||
        _currentPlaylist!.items.isEmpty ||
        _currentIndex + 1 >= _currentPlaylist!.items.length) {
      return null;
    }
    return _currentPlaylist!.items[_currentIndex + 1];
  }

  bool get hasNext => _currentIndex < (_currentPlaylist?.items.length ?? 0) - 1;
  bool get hasPrevious => _currentIndex > 0;

  Future<void> loadPlaylist({
    required String companySlug,
    required String playlistSlug,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPlaylist = await PlaylistService.instance.getPlaylistDetail(
        companySlug,
        playlistSlug,
      );
      _currentIndex = 0;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Attach the controller of the currently rendered video player so the
  /// provider can drive play/pause from list & header controls.
  void attachVideoController(VideoPlayerController? controller) {
    _videoController = controller;
  }

  /// Keep the header/list play indicator in sync with the video player.
  void setVideoPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  Future<void> playItem(PlaylistItemModel item) async {
    if (_currentPlaylist == null) return;
    final index = _currentPlaylist!.items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    if (index == _currentIndex && currentItem != null) {
      await togglePlayPause();
      return;
    }

    _currentIndex = index;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final item = currentItem;
    if (item == null) return;

    if (item.isVideo) {
      _isPlaying = true;
      await _stopAudioIfPlaying();
      notifyListeners();
      return;
    }

    await _playAudio(item);
  }

  Future<void> _playAudio(PlaylistItemModel item) async {
    final url = item.mediaUrl;
    if (url == null || url.isEmpty) {
      _error = 'Playback unavailable for "${item.title}"';
      _isPlaying = false;
      notifyListeners();
      return;
    }

    _isPlaying = true;
    _error = null;
    notifyListeners();

    try {
      await AudioManager.instance.playRecording(
        recordingId: item.mediaId ?? item.id,
        title: item.title,
        artist: item.description ?? 'Volantis Live',
        artworkUrl: item.thumbnailUrl,
        audioUrl: url,
        duration: item.durationSeconds != null
            ? Duration(seconds: item.durationSeconds!)
            : null,
      );
    } catch (e) {
      _isPlaying = false;
      _error = 'Failed to play "${item.title}": $e';
      notifyListeners();
    }
  }

  Future<void> _stopAudioIfPlaying() async {
    if (AudioManager.instance.isRecordingActive) {
      await AudioManager.instance.stop();
    }
  }

  void _onAudioStateChanged(AudioState state) {
    final item = currentItem;
    if (item == null || item.isVideo) return;

    final sourceId = item.mediaId ?? item.id;
    if (state.sourceType != AudioSourceType.recording ||
        state.sourceId != sourceId) {
      return;
    }

    if (state.isCompleted) {
      _isPlaying = false;
      notifyListeners();
      _onAudioCompleted();
      return;
    }

    if (_isPlaying != state.isPlaying) {
      _isPlaying = state.isPlaying;
      notifyListeners();
    }
  }

  void _onAudioCompleted() {
    if (hasNext) {
      next();
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> next() async {
    if (hasNext) {
      _currentIndex++;
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    if (hasPrevious) {
      _currentIndex--;
      await _playCurrent();
    }
  }

  Future<void> togglePlayPause() async {
    final item = currentItem;
    if (item == null) return;

    if (item.isVideo) {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        if (controller.value.isPlaying) {
          await controller.pause();
          _isPlaying = false;
        } else {
          await controller.play();
          _isPlaying = true;
        }
        notifyListeners();
      }
      return;
    }

    await AudioManager.instance.togglePlayPause();
  }

  Future<void> seek(Duration position) async {
    await AudioManager.instance.seek(position);
  }

  Future<void> skipBack(int seconds) async {
    await AudioManager.instance.skipBack(seconds);
  }

  Future<void> skipForward(int seconds) async {
    await AudioManager.instance.skipForward(seconds);
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  Future<void> closePlayer() async {
    await _stopAudioIfPlaying();
    _currentPlaylist = null;
    _currentIndex = 0;
    _isPlaying = false;
    _error = null;
    _videoController = null;
    notifyListeners();
  }

  void reset() {
    _currentPlaylist = null;
    _currentIndex = 0;
    _isPlaying = false;
    _isLoading = false;
    _error = null;
    _videoController = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    super.dispose();
  }
}
