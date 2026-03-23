import 'package:flutter/foundation.dart';
import '../../../recordings/data/models/recording_download.dart';
import '../../../recordings/presentation/providers/recordings_provider.dart';
import '../../../../services/download_manager.dart';
import '../../../../services/encryption_service.dart';
import '../../../recordings/data/services/recordings_downloads_service.dart';

/// Active download task model
class ActiveDownloadTask {
  final int recordingId;
  final String title;
  final String? thumbnailUrl;
  final double progress;
  final DownloadStatus status;

  ActiveDownloadTask({
    required this.recordingId,
    required this.title,
    this.thumbnailUrl,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
  });

  ActiveDownloadTask copyWith({
    int? recordingId,
    String? title,
    String? thumbnailUrl,
    double? progress,
    DownloadStatus? status,
  }) {
    return ActiveDownloadTask(
      recordingId: recordingId ?? this.recordingId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

/// Provider for managing downloads screen state
class DownloadsProvider extends ChangeNotifier {
  final RecordingsDownloadsService _downloadsService;
  final DownloadManager _downloadManager;
  final RecordingsProvider? _recordingsProvider;

  List<RecordingDownload> _downloads = [];
  List<ActiveDownloadTask> _activeDownloads = [];
  int _totalStorageUsed = 0;
  bool _isLoading = false;

  DownloadsProvider(
    this._downloadsService,
    this._downloadManager, [
    this._recordingsProvider,
  ]) {
    _initListeners();
  }

  void _initListeners() {
    // Listen to download progress
    _downloadManager.downloadProgressStream.listen((progress) {
      _updateActiveDownloadProgress(progress);
    });

    // Listen to download status changes
    _downloadManager.downloadStatusStream.listen((status) {
      _handleDownloadStatusUpdate(status);
    });
  }

  void _updateActiveDownloadProgress(DownloadProgress progress) {
    final index = _activeDownloads.indexWhere(
      (d) => d.recordingId == progress.recordingId,
    );
    if (index >= 0) {
      _activeDownloads[index] = _activeDownloads[index].copyWith(
        progress: progress.progress,
      );
      notifyListeners();
    }
  }

  void _handleDownloadStatusUpdate(DownloadStatusUpdate status) {
    if (status.status == DownloadStatus.downloaded) {
      // Remove from active and reload downloads
      _activeDownloads.removeWhere((d) => d.recordingId == status.recordingId);
      loadDownloads();
    } else if (status.status == DownloadStatus.downloading) {
      // Add to active if not present, or update existing
      final existingIndex = _activeDownloads.indexWhere(
        (d) => d.recordingId == status.recordingId,
      );
      if (existingIndex >= 0) {
        // Update existing with new progress
        _activeDownloads[existingIndex] = _activeDownloads[existingIndex]
            .copyWith(
              progress:
                  status.download?.downloadProgress ??
                  _activeDownloads[existingIndex].progress,
              title:
                  status.download?.title ??
                  _activeDownloads[existingIndex].title,
              thumbnailUrl:
                  status.download?.thumbnailUrl ??
                  _activeDownloads[existingIndex].thumbnailUrl,
            );
      } else {
        _activeDownloads.add(
          ActiveDownloadTask(
            recordingId: status.recordingId,
            title: status.download?.title ?? 'Downloading...',
            thumbnailUrl: status.download?.thumbnailUrl,
            progress: status.download?.downloadProgress ?? 0.0,
          ),
        );
      }
      notifyListeners();
    } else if (status.status == DownloadStatus.failed ||
        status.status == DownloadStatus.notDownloaded) {
      _activeDownloads.removeWhere((d) => d.recordingId == status.recordingId);
      notifyListeners();
    } else if (status.status == DownloadStatus.queued) {
      if (!_activeDownloads.any((d) => d.recordingId == status.recordingId)) {
        _activeDownloads.add(
          ActiveDownloadTask(
            recordingId: status.recordingId,
            title: status.download?.title ?? 'Queued...',
            thumbnailUrl: status.download?.thumbnailUrl,
            progress: 0.0,
            status: DownloadStatus.queued,
          ),
        );
        notifyListeners();
      }
    }
  }

  // Getters
  List<RecordingDownload> get downloads => _downloads;
  List<ActiveDownloadTask> get activeDownloads => _activeDownloads;
  int get totalStorageUsed => _totalStorageUsed;
  bool get isLoading => _isLoading;

  /// Load all downloads
  Future<void> loadDownloads() async {
    _isLoading = true;
    notifyListeners();

    try {
      _downloads = await _downloadsService.getDownloadedRecordings();
      _totalStorageUsed = await _downloadsService.getTotalStorageUsed();
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Delete a single download
  Future<void> deleteDownload(int recordingId) async {
    try {
      await _downloadManager.deleteDownload(recordingId);
      await loadDownloads();
    } catch (e) {
      debugPrint('Error deleting download: $e');
    }
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      await _downloadsService.deleteAllDownloads();
      await loadDownloads();
    } catch (e) {
      debugPrint('Error clearing downloads: $e');
    }
  }

  /// Cancel an active download
  void cancelDownload(int recordingId) {
    _downloadManager.cancelDownload(recordingId);
    _activeDownloads.removeWhere((d) => d.recordingId == recordingId);
    notifyListeners();
  }

  /// Play a downloaded recording
  Future<void> playDownloaded(int recordingId) async {
    if (_recordingsProvider != null) {
      await _recordingsProvider!.playDownloadedRecording(recordingId);
    } else {
      // Fallback: try to play directly using the downloads service
      try {
        final downloadsService = RecordingsDownloadsService.instance;
        final isDownloaded = await downloadsService.isRecordingDownloaded(
          recordingId,
        );
        if (!isDownloaded) {
          debugPrint('Recording not downloaded: $recordingId');
          return;
        }

        final filePath = await downloadsService.getDecryptedFilePath(
          recordingId,
        );
        debugPrint('Would play downloaded file: $filePath');
        // Note: Full playback requires RecordingsProvider - notify user
        debugPrint('Please use the recordings provider to play this download');
      } catch (e) {
        debugPrint('Error playing downloaded recording: $e');
      }
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
