import 'package:flutter/foundation.dart';
import '../../../home/data/models/playlist_model.dart';
import 'package:volantis_live/services/playlist_service.dart';

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

  void playItem(PlaylistItemModel item) {
    if (_currentPlaylist == null) return;
    final index = _currentPlaylist!.items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _currentIndex = index;
      _isPlaying = true;
      notifyListeners();
    }
  }

  void next() {
    if (hasNext) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void previous() {
    if (hasPrevious) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void reset() {
    _currentPlaylist = null;
    _currentIndex = 0;
    _isPlaying = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}