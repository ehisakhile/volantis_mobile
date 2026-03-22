import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../features/recordings/data/models/recording_download.dart';
import '../features/recordings/data/services/recordings_downloads_service.dart';
import '../features/recordings/data/models/recording_model.dart';
import 'connectivity_service.dart';

/// Download task for queue management
class DownloadTask {
  final Recording recording;
  final String downloadUrl;
  final Function(double) onProgress;
  final Function(RecordingDownload) onComplete;
  final Function(String) onError;

  DownloadTask({
    required this.recording,
    required this.downloadUrl,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });
}

/// Download manager for handling recording downloads
/// Manages download queue, network awareness, and coordination
class DownloadManager {
  static DownloadManager? _instance;

  final RecordingsDownloadsService _downloadsService;
  final ConnectivityService _connectivityService;
  final Dio _dio;

  final List<DownloadTask> _queue = [];
  DownloadTask? _currentTask;
  bool _isProcessing = false;
  bool _isPaused = false;

  // Stream controllers for UI updates
  final _downloadProgressController =
      StreamController<DownloadProgress>.broadcast();
  final _downloadStatusController =
      StreamController<DownloadStatusUpdate>.broadcast();

  // Max concurrent downloads
  static const int maxConcurrentDownloads = 1;

  DownloadManager._(
    this._downloadsService,
    this._connectivityService,
    this._dio,
  ) {
    _initConnectivityListener();
  }

  static DownloadManager get instance {
    _instance ??= throw Exception(
      'DownloadManager not initialized. Call init() first.',
    );
    return _instance!;
  }

  /// Initialize the download manager
  static Future<DownloadManager> init(Dio dio) async {
    final connectivityService = ConnectivityService.instance;
    final downloadsService = RecordingsDownloadsService.instance;

    _instance = DownloadManager._(downloadsService, connectivityService, dio);

    return _instance!;
  }

  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivityService.statusStream.listen((status) {
      if (status == ConnectivityStatus.wifi ||
          status == ConnectivityStatus.ethernet) {
        // WiFi connected - resume if paused
        if (_isPaused && _queue.isNotEmpty) {
          _isPaused = false;
          _processQueue();
        }
      } else if (status == ConnectivityStatus.mobile) {
        // Mobile data - check preferences
        _checkAndPauseForMobileData();
      } else if (status == ConnectivityStatus.offline) {
        // No connection - pause downloads
        _pauseAll();
      }
    });
  }

  /// Check if should pause for mobile data
  Future<void> _checkAndPauseForMobileData() async {
    final prefs = await _downloadsService.loadPreferences();
    if (prefs.downloadOverWifiOnly && _currentTask != null) {
      _isPaused = true;
      _downloadStatusController.add(
        DownloadStatusUpdate(
          recordingId: _currentTask!.recording.id,
          status: DownloadStatus.paused,
        ),
      );
    }
  }

  /// Stream of download progress
  Stream<DownloadProgress> get downloadProgressStream =>
      _downloadProgressController.stream;

  /// Stream of download status changes
  Stream<DownloadStatusUpdate> get downloadStatusStream =>
      _downloadStatusController.stream;

  /// Check if recording is downloaded
  Future<bool> isDownloaded(int recordingId) async {
    return _downloadsService.isRecordingDownloaded(recordingId);
  }

  /// Get download status
  Future<DownloadStatus> getDownloadStatus(int recordingId) async {
    // Check if in queue
    if (_queue.any((t) => t.recording.id == recordingId)) {
      return DownloadStatus.queued;
    }
    // Check if currently downloading
    if (_currentTask?.recording.id == recordingId) {
      return _isPaused ? DownloadStatus.paused : DownloadStatus.downloading;
    }
    // Check database
    return _downloadsService.getDownloadStatus(recordingId);
  }

  /// Queue a recording for download
  Future<void> queueDownload({
    required Recording recording,
    required String downloadUrl,
    String? companyName,
    String? companySlug,
  }) async {
    // Check if already downloaded or in queue
    final status = await getDownloadStatus(recording.id);
    if (status == DownloadStatus.downloaded ||
        status == DownloadStatus.downloading ||
        status == DownloadStatus.queued) {
      return;
    }

    final task = DownloadTask(
      recording: recording,
      downloadUrl: downloadUrl,
      onProgress: (progress) {
        _downloadProgressController.add(
          DownloadProgress(recordingId: recording.id, progress: progress),
        );
      },
      onComplete: (download) {
        _downloadStatusController.add(
          DownloadStatusUpdate(
            recordingId: recording.id,
            status: DownloadStatus.downloaded,
            download: download,
          ),
        );
        _processNext();
      },
      onError: (error) {
        _downloadStatusController.add(
          DownloadStatusUpdate(
            recordingId: recording.id,
            status: DownloadStatus.failed,
            error: error,
          ),
        );
        _processNext();
      },
    );

    _queue.add(task);
    _downloadStatusController.add(
      DownloadStatusUpdate(
        recordingId: recording.id,
        status: DownloadStatus.queued,
      ),
    );

    // Start processing if not already
    if (!_isProcessing) {
      _processQueue();
    }
  }

  /// Process the download queue
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty || _isPaused) return;

    // Check network
    final status = _connectivityService.currentStatus;
    final prefs = await _downloadsService.loadPreferences();

    // Check WiFi requirement
    if (prefs.downloadOverWifiOnly) {
      final hasWifi =
          status == ConnectivityStatus.wifi ||
          status == ConnectivityStatus.ethernet;
      if (!hasWifi) {
        return; // Wait for WiFi
      }
    }

    _isProcessing = true;
    _currentTask = _queue.removeAt(0);

    try {
      _downloadStatusController.add(
        DownloadStatusUpdate(
          recordingId: _currentTask!.recording.id,
          status: DownloadStatus.downloading,
        ),
      );

      final download = await _downloadsService.startDownload(
        recordingId: _currentTask!.recording.id,
        title: _currentTask!.recording.title,
        description: _currentTask!.recording.description,
        thumbnailUrl: _currentTask!.recording.thumbnailUrl,
        downloadUrl: _currentTask!.downloadUrl,
        fileSizeBytes: _currentTask!.recording.fileSizeBytes,
        companySlug: _currentTask!.recording.companyId.toString(),
        durationSeconds: _currentTask!.recording.durationSeconds,
        onProgress: _currentTask!.onProgress,
      );

      _currentTask!.onComplete(download);
    } catch (e) {
      _currentTask!.onError(e.toString());
    } finally {
      _isProcessing = false;
      _currentTask = null;
    }
  }

  /// Process next item in queue
  void _processNext() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _processQueue();
    });
  }

  /// Pause all downloads
  void _pauseAll() {
    _isPaused = true;
    if (_currentTask != null) {
      _downloadStatusController.add(
        DownloadStatusUpdate(
          recordingId: _currentTask!.recording.id,
          status: DownloadStatus.paused,
        ),
      );
    }
  }

  /// Resume downloads
  void resumeDownloads() {
    if (_isPaused) {
      _isPaused = false;
      _processQueue();
    }
  }

  /// Cancel a specific download
  void cancelDownload(int recordingId) {
    // Remove from queue if queued
    _queue.removeWhere((t) => t.recording.id == recordingId);

    // If currently downloading, it will stop after current progress
    if (_currentTask?.recording.id == recordingId) {
      _downloadStatusController.add(
        DownloadStatusUpdate(
          recordingId: recordingId,
          status: DownloadStatus.notDownloaded,
        ),
      );
      _currentTask = null;
      _isProcessing = false;
    }
  }

  /// Delete a downloaded recording
  Future<void> deleteDownload(int recordingId) async {
    await _downloadsService.deleteDownload(recordingId);
    _downloadStatusController.add(
      DownloadStatusUpdate(
        recordingId: recordingId,
        status: DownloadStatus.notDownloaded,
      ),
    );
  }

  /// Get all downloaded recordings
  Future<List<RecordingDownload>> getDownloadedRecordings() async {
    return _downloadsService.getDownloadedRecordings();
  }

  /// Get download progress for a recording
  double getDownloadProgress(int recordingId) {
    if (_currentTask?.recording.id == recordingId) {
      // Would need to track this - simplified for now
      return 0.0;
    }
    return 0.0;
  }

  /// Get queue count
  int get queueCount => _queue.length;

  /// Check if currently downloading
  bool get isDownloading => _isProcessing && _currentTask != null;

  /// Dispose
  void dispose() {
    _downloadProgressController.close();
    _downloadStatusController.close();
  }
}

/// Download progress event
class DownloadProgress {
  final int recordingId;
  final double progress;

  DownloadProgress({required this.recordingId, required this.progress});
}

/// Download status update event
class DownloadStatusUpdate {
  final int recordingId;
  final DownloadStatus status;
  final RecordingDownload? download;
  final String? error;

  DownloadStatusUpdate({
    required this.recordingId,
    required this.status,
    this.download,
    this.error,
  });
}
