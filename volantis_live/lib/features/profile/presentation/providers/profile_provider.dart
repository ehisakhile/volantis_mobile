import 'package:flutter/foundation.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/offline_service.dart';
import '../../../recordings/data/services/recordings_downloads_service.dart';

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

      // Get downloads from both services and combine them
      // 1. Get stream/channel downloads from OfflineService
      final streamDownloads = await _offlineService.getAllDownloads();

      // 2. Get recording downloads from RecordingsDownloadsService
      final recordingDownloads = await RecordingsDownloadsService.instance
          .getDownloadedRecordings();

      // Combine both lists - convert recordings to map format for consistency
      final combinedDownloads = <Map<String, dynamic>>[];

      // Add stream downloads
      for (final download in streamDownloads) {
        combinedDownloads.add({
          'id': download['id'],
          'title': download['channel_name'],
          'type': 'stream',
          'local_path': download['local_path'],
          'file_size': download['file_size'],
          'downloaded_at': download['downloaded_at'],
        });
      }

      // Add recording downloads
      for (final download in recordingDownloads) {
        combinedDownloads.add({
          'id': download.id,
          'title': download.title,
          'type': 'recording',
          'local_path': download.localPath,
          'file_size': download.fileSizeBytes,
          'downloaded_at': download.downloadedAt.millisecondsSinceEpoch,
        });
      }

      _downloads = combinedDownloads;

      // Calculate total storage from both sources
      int streamStorage = await _offlineService.getTotalStorageUsed();
      int recordingStorage = await RecordingsDownloadsService.instance
          .getTotalStorageUsed();
      _storageUsed = streamStorage + recordingStorage;
    } catch (e) {
      debugPrint('Error loading profile data: $e');
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
    try {
      // Find the download to determine its type
      final download = _downloads.firstWhere(
        (d) => d['id'] == id,
        orElse: () => {},
      );

      final type = download['type'] as String?;

      if (type == 'recording') {
        // Delete from RecordingsDownloadsService
        await RecordingsDownloadsService.instance.deleteDownload(id);
      } else {
        // Delete from OfflineService (for streams)
        await _offlineService.deleteDownload(id);
      }

      await init();
    } catch (e) {
      debugPrint('Error deleting download: $e');
    }
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      await _offlineService.clearAllDownloads();
      await RecordingsDownloadsService.instance.deleteAllDownloads();
      await init();
    } catch (e) {
      debugPrint('Error clearing downloads: $e');
    }
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
