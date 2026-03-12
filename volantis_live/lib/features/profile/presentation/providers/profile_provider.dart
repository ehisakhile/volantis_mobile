import 'package:flutter/foundation.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/offline_service.dart';

/// Profile provider for managing profile screen state
class ProfileProvider extends ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  final OfflineService _offlineService = OfflineService.instance;
  
  int _totalListeningTime = 0;
  int _listeningStreak = 0;
  List<Map<String, dynamic>> _mostListenedChannels = [];
  List<Map<String, dynamic>> _favoriteGenres = [];
  List<Map<String, dynamic>> _downloads = [];
  int _storageUsed = 0;
  bool _isLoading = false;

  // Settings
  String _audioQuality = 'auto';
  bool _downloadOverWifiOnly = true;
  bool _notificationsEnabled = true;
  bool _darkMode = true;

  // Getters
  int get totalListeningTime => _totalListeningTime;
  int get listeningStreak => _listeningStreak;
  List<Map<String, dynamic>> get mostListenedChannels => _mostListenedChannels;
  List<Map<String, dynamic>> get favoriteGenres => _favoriteGenres;
  List<Map<String, dynamic>> get downloads => _downloads;
  int get storageUsed => _storageUsed;
  bool get isLoading => _isLoading;
  String get audioQuality => _audioQuality;
  bool get downloadOverWifiOnly => _downloadOverWifiOnly;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkMode => _darkMode;

  /// Initialize profile data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _totalListeningTime = await _analyticsService.getTotalListeningTime();
      _listeningStreak = await _analyticsService.getListeningStreak();
      _mostListenedChannels = await _analyticsService.getMostListenedChannels();
      _favoriteGenres = await _analyticsService.getFavoriteGenres();
      _downloads = await _offlineService.getAllDownloads();
      _storageUsed = await _offlineService.getTotalStorageUsed();
    } catch (e) {
      // Handle error silently
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update audio quality
  void setAudioQuality(String quality) {
    _audioQuality = quality;
    notifyListeners();
  }

  /// Update download over WiFi only
  void setDownloadOverWifiOnly(bool value) {
    _downloadOverWifiOnly = value;
    notifyListeners();
  }

  /// Update notifications
  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }

  /// Update dark mode
  void setDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
  }

  /// Delete download
  Future<void> deleteDownload(int id) async {
    await _offlineService.deleteDownload(id);
    await init();
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    await _offlineService.clearAllDownloads();
    await init();
  }

  /// Format storage size
  String formatStorageSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}