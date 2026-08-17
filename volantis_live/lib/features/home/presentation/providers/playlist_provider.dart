import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:floating/floating.dart';
import 'package:video_player/video_player.dart';
import 'package:volantis_live/services/api_service.dart';
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

/// App-level playback controller for a playlist. Owns both audio (through
/// [AudioManager]) and video (through its own [VideoPlayerController]) so
/// playback survives leaving the playlist screen — a global mini player can
/// keep showing the current item and jump back to the full screen.
class PlaylistPlayerProvider extends ChangeNotifier {
  PlaylistModel? _currentPlaylist;
  int _currentIndex = -1; // -1 means no item selected
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;

  String? _companySlug;
  int? _playlistId;
  String? _companyName;
  String? _companyLogoUrl;
  bool _isPlayerScreenVisible = false;

  VideoPlayerController? _videoController;
  bool _videoEndedHandled = false;

  final Floating _floating = Floating();
  bool _isPipActive = false;

  StreamSubscription<AudioState>? _audioSubscription;

  PlaylistPlayerProvider() {
    _audioSubscription = AudioManager.instance.stateStream.listen(
      _onAudioStateChanged,
    );
  }

  PlaylistModel? get currentPlaylist => _currentPlaylist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get companySlug => _companySlug;
  int? get playlistId => _playlistId;
  String? get companyName => _companyName;
  String? get companyLogoUrl => _companyLogoUrl;

  VideoPlayerController? get videoController => _videoController;

  Floating get floating => _floating;

  /// True while the full playlist player screen is on screen. The global mini
  /// player only shows when playback is active but the screen is not visible.
  bool get isPlayerScreenVisible => _isPlayerScreenVisible;
  bool get showMiniPlayer => currentItem != null && !_isPlayerScreenVisible;

  bool get isPipActive => _isPipActive;

  Future<bool> get isPipAvailable async => await _floating.isPipAvailable;

  PlaylistItemModel? get currentItem {
    if (_currentPlaylist == null ||
        _currentPlaylist!.items.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _currentPlaylist!.items.length) {
      return null;
    }
    return _currentPlaylist!.items[_currentIndex];
  }

  PlaylistItemModel? get nextItem {
    if (_currentPlaylist == null ||
        _currentPlaylist!.items.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex + 1 >= _currentPlaylist!.items.length) {
      return null;
    }
    return _currentPlaylist!.items[_currentIndex + 1];
  }

  bool get hasNext =>
      _currentIndex >= 0 &&
      _currentIndex < (_currentPlaylist?.items.length ?? 0) - 1;

  bool get hasPrevious => _currentIndex > 0;

  void setPlayerScreenVisible(bool visible) {
    if (_isPlayerScreenVisible == visible) return;
    _isPlayerScreenVisible = visible;
    notifyListeners();
  }

  /// Enter native Android PiP mode immediately.
  Future<void> enterPip() async {
    if (_isPipActive) return;
    final canPip = await _floating.isPipAvailable;
    if (!canPip) return;
    await _floating.enable(ImmediatePiP());
    _isPipActive = true;
    notifyListeners();
  }

  /// Enable automatic PiP when the app is minimized (e.g. user presses home).
  Future<void> enableAutoPip() async {
    final canPip = await _floating.isPipAvailable;
    if (!canPip) return;
    await _floating.enable(OnLeavePiP());
  }

  /// Cancel the automatic PiP-on-minimize behavior.
  Future<void> cancelAutoPip() async {
    await _floating.cancelOnLeavePiP();
  }

  /// Called when the OS notifies us that PiP mode has ended.
  void onPipExited() {
    if (!_isPipActive) return;
    _isPipActive = false;
    notifyListeners();
  }

  Future<void> loadPlaylist({
    required String companySlug,
    required String playlistSlug,
  }) async {
    final parsedId = int.tryParse(playlistSlug);

    // Resume: the same playlist is already loaded and being played, so just
    // mark the screen visible again without resetting playback.
    if (_currentPlaylist != null &&
        parsedId != null &&
        _currentPlaylist!.id == parsedId) {
      _companySlug = companySlug;
      _playlistId = parsedId;
      _isPlayerScreenVisible = true;
      if (_companyName == null) unawaited(_loadCompanyInfo(companySlug));
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _stopAudioIfPlaying();
      _disposeVideoController();

      _currentPlaylist = await PlaylistService.instance.getPlaylistDetail(
        companySlug,
        playlistSlug,
      );
      // Reset index to -1 (no item selected) when loading a new playlist
      _currentIndex = -1;
      _companySlug = companySlug;
      _playlistId = _currentPlaylist!.id;
      _companyName = null;
      _companyLogoUrl = null;
      _isPlayerScreenVisible = true;
      _isPlaying = false; // Ensure playing state is false
      unawaited(_loadCompanyInfo(companySlug));
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCompanyInfo(String companySlug) async {
    try {
      final response = await ApiService.instance.get('/$companySlug');
      final company = (response.data as Map<String, dynamic>?)?['company'];
      if (company == null) return;
      _companyName = company['name'];
      _companyLogoUrl = company['logo_url'];
      notifyListeners();
    } catch (_) {
      // Company metadata is optional; ignore failures.
    }
  }

  Future<void> playItem(PlaylistItemModel item) async {
    if (_currentPlaylist == null) return;
    final index = _currentPlaylist!.items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    if (index == _currentIndex && _isItemActuallyLoaded(item)) {
      await togglePlayPause();
      return;
    }

    _currentIndex = index;
    await _playCurrent();
  }

  bool _isItemActuallyLoaded(PlaylistItemModel item) {
    if (item.isVideo) {
      return _videoController != null &&
          _videoController!.dataSource == item.mediaUrl;
    }
    final sourceId = item.mediaId ?? item.id;
    final state = AudioManager.instance.currentState;
    return state.sourceType == AudioSourceType.recording &&
        state.sourceId == sourceId;
  }

  Future<void> _playCurrent() async {
    final item = currentItem;
    if (item == null) return;

    if (item.isVideo) {
      await _stopAudioIfPlaying();
      await _playVideo(item);
      return;
    }

    final video = _videoController;
    if (video != null && video.value.isInitialized && video.value.isPlaying) {
      await video.pause();
    }
    await _playAudio(item);
  }

  Future<void> _playVideo(PlaylistItemModel item) async {
    final url = item.mediaUrl;
    if (url == null || url.isEmpty) {
      _error = 'Playback unavailable for "${item.title}"';
      _isPlaying = false;
      notifyListeners();
      return;
    }

    final existing = _videoController;
    if (existing != null &&
        existing.dataSource == url &&
        existing.value.isInitialized) {
      _isPlaying = true;
      _error = null;
      await existing.play();
      notifyListeners();
      return;
    }

    _disposeVideoController();

    await AudioManager.instance.activateSession();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _videoController = controller;
    controller.addListener(_onVideoStateChanged);
    _isPlaying = true;
    _error = null;
    _videoEndedHandled = false;
    notifyListeners();

    try {
      await controller.initialize();
      if (_videoController != controller) return;
      await controller.play();
      notifyListeners();
    } catch (e) {
      if (_videoController == controller) {
        _isPlaying = false;
        _error = 'Failed to play "${item.title}": $e';
        notifyListeners();
      }
    }
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

  void _onVideoStateChanged() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final playing = controller.value.isPlaying;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      notifyListeners();
    }

    if (controller.value.isCompleted) {
      if (!_videoEndedHandled) {
        _videoEndedHandled = true;
        _onVideoCompleted();
      }
    } else {
      _videoEndedHandled = false;
    }
  }

  void _onVideoCompleted() {
    if (hasNext) {
      unawaited(next());
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> _stopAudioIfPlaying() async {
    if (AudioManager.instance.isRecordingActive) {
      await AudioManager.instance.stop();
    }
  }

  void _disposeVideoController() {
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_onVideoStateChanged);
      controller.dispose();
    }
    _videoController = null;
    _videoEndedHandled = false;
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
      unawaited(next());
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
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
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
    _disposeVideoController();
    _currentPlaylist = null;
    _currentIndex = -1; // Reset to -1
    _isPlaying = false;
    _error = null;
    _companySlug = null;
    _playlistId = null;
    _companyName = null;
    _companyLogoUrl = null;
    notifyListeners();
  }

  void reset() {
    _currentPlaylist = null;
    _currentIndex = -1; // Reset to -1
    _isPlaying = false;
    _isLoading = false;
    _error = null;
    _companySlug = null;
    _playlistId = null;
    _companyName = null;
    _companyLogoUrl = null;
    _disposeVideoController();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _disposeVideoController();
    super.dispose();
  }
}
