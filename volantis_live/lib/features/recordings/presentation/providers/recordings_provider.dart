import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../../data/models/recording_model.dart';
import '../../data/models/recording_download.dart';
import '../../data/services/recordings_service.dart';
import '../../data/services/recordings_downloads_service.dart';
import '../../../../services/download_manager.dart';

/// Provider for managing recordings state and audio playback
class RecordingsProvider extends ChangeNotifier {
  final RecordingsService _service;
  final AudioPlayer _player = AudioPlayer();

  // List state - per company
  List<Recording> recordings = [];
  bool isLoadingList = false;
  bool hasMore = true;
  int _offset = 0;
  static const _limit = 20;

  // Current company slug - always fetch fresh for each channel
  String? _currentCompanySlug;

  // Player state
  Recording? currentRecording;
  bool isPlayerOpen = false;
  bool isFullScreen = true;
  bool isCompleted = false;

  // Position tracking
  Timer? _positionTimer;
  static const _positionInterval = Duration(seconds: 30);

  // Watch history
  List<WatchHistoryItem> watchHistory = [];
  bool isLoadingHistory = false;

  // Error state
  String? errorMessage;

  // Download state
  final Map<int, DownloadStatus> _downloadStatuses = {};
  final Map<int, double> _downloadProgress = {};

  // Stream subscriptions for download updates
  StreamSubscription? _downloadStatusSubscription;
  StreamSubscription? _downloadProgressSubscription;

  RecordingsProvider(this._service) {
    _initAudioSession();
    _player.playerStateStream.listen(_onPlayerState);
    _player.positionStream.listen(_onPosition);
    // Load existing downloads on initialization
    _loadExistingDownloads();
    // Listen to download manager for status updates
    _listenToDownloadUpdates();
  }

  /// Load existing downloads from RecordingsDownloadsService
  Future<void> _loadExistingDownloads() async {
    try {
      final downloadsService = RecordingsDownloadsService.instance;
      final downloads = await downloadsService.getAllDownloads();
      for (final download in downloads) {
        _downloadStatuses[download.recordingId] = download.status;
        _downloadProgress[download.recordingId] = download.downloadProgress;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading existing downloads: $e');
    }
  }

  /// Listen to download manager for real-time status updates
  void _listenToDownloadUpdates() {
    final downloadManager = DownloadManager.instance;
    _downloadStatusSubscription = downloadManager.downloadStatusStream.listen((
      status,
    ) {
      if (status.status == DownloadStatus.downloaded) {
        _downloadStatuses[status.recordingId] = DownloadStatus.downloaded;
        _downloadProgress[status.recordingId] = 1.0;
        notifyListeners();
      } else if (status.status == DownloadStatus.downloading) {
        _downloadStatuses[status.recordingId] = DownloadStatus.downloading;
        _downloadProgress[status.recordingId] =
            status.download?.downloadProgress ?? 0.0;
        notifyListeners();
      } else if (status.status == DownloadStatus.failed) {
        _downloadStatuses[status.recordingId] = DownloadStatus.failed;
        notifyListeners();
      } else if (status.status == DownloadStatus.queued) {
        _downloadStatuses[status.recordingId] = DownloadStatus.queued;
        notifyListeners();
      }
    });

    _downloadProgressSubscription = downloadManager.downloadProgressStream
        .listen((progress) {
          _downloadProgress[progress.recordingId] = progress.progress;
          notifyListeners();
        });
  }

  /// Initialize audio session with background support
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

  /// Load recordings for a specific company - always fetches fresh data
  Future<void> loadRecordings(
    String companySlug, {
    bool refresh = false,
  }) async {
    // Always clear and refresh when loading for a different company
    if (_currentCompanySlug != companySlug) {
      refresh = true;
    }

    if (refresh) {
      recordings = [];
      _offset = 0;
      hasMore = true;
      _currentCompanySlug = companySlug;
    }

    if (isLoadingList || !hasMore) return;

    isLoadingList = true;
    errorMessage = null;
    notifyListeners();

    try {
      final batch = await _service.getRecordings(
        companySlug,
        limit: _limit,
        offset: _offset,
      );
      recordings.addAll(batch);
      _offset += batch.length;
      hasMore = batch.length == _limit;
    } catch (e) {
      errorMessage = 'Failed to load recordings: ${e.toString()}';
      debugPrint(errorMessage);
    } finally {
      isLoadingList = false;
      notifyListeners();
    }
  }

  /// Load watch history
  Future<void> loadWatchHistory({bool refresh = false}) async {
    if (refresh) {
      watchHistory = [];
    }

    if (isLoadingHistory) return;

    isLoadingHistory = true;
    notifyListeners();

    try {
      final history = await _service.getWatchHistory();
      watchHistory = history;
    } catch (e) {
      debugPrint('Failed to load watch history: $e');
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Open and play a recording
  Future<void> openRecording(int id, {int? startPosition}) async {
    // Check if same recording is already playing
    if (currentRecording != null && currentRecording!.id == id) {
      // Same recording - just toggle play/pause
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    try {
      // Stop any current playback before starting new one
      await _player.stop();
      _positionTimer?.cancel();

      // Fetch single recording - this call increments replay_count
      final recording = await _service.getRecording(id);
      currentRecording = recording;
      isPlayerOpen = true;
      isFullScreen = true;
      isCompleted = false;
      errorMessage = null;
      notifyListeners();

      // Build streaming URL
      final url = _service.getStreamingUrl(recording.streamingUrl);

      // Set audio source with background support and MediaItem tag
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: recording.id.toString(),
            title: recording.title,
            artist: recording.description ?? 'Volantis Live',
            artUri: recording.thumbnailUrl != null
                ? Uri.parse(recording.thumbnailUrl!)
                : null,
            duration: recording.durationSeconds != null
                ? Duration(seconds: recording.durationSeconds!)
                : null,
          ),
        ),
      );

      // Seek to start position if provided (from watch history)
      if (startPosition != null && startPosition > 0) {
        await _player.seek(Duration(seconds: startPosition));
      }

      await _player.play();
      _startPositionTimer();
    } catch (e) {
      errorMessage = 'Failed to play recording: ${e.toString()}';
      debugPrint(errorMessage);
      isPlayerOpen = false;
      notifyListeners();
    }
  }

  /// Minimize player to mini-player mode
  void minimize() {
    isFullScreen = false;
    notifyListeners();
  }

  /// Expand player to full-screen mode
  void expand() {
    isFullScreen = true;
    notifyListeners();
  }

  /// Close the player
  void closePlayer() {
    _savePosition();
    _player.stop();
    _positionTimer?.cancel();
    isPlayerOpen = false;
    isFullScreen = true;
    currentRecording = null;
    isCompleted = false;
    notifyListeners();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      _savePosition();
    } else {
      await _player.play();
    }
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) => _player.seek(position);

  /// Skip back by specified seconds
  Future<void> skipBack(int seconds) async {
    final currentDuration = _player.duration ?? Duration.zero;
    var newPosition = _player.position - Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      newPosition = Duration.zero;
    }
    await _player.seek(
      newPosition > currentDuration ? currentDuration : newPosition,
    );
  }

  /// Skip forward by specified seconds
  Future<void> skipForward(int seconds) async {
    final currentDuration = _player.duration ?? Duration.zero;
    final newPosition = _player.position + Duration(seconds: seconds);
    await _player.seek(
      newPosition > currentDuration ? currentDuration : newPosition,
    );
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  /// Mark recording as complete
  Future<void> markComplete() async {
    if (currentRecording == null || isCompleted) return;
    try {
      await _service.markComplete(currentRecording!.id);
      isCompleted = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark complete: $e');
    }
  }

  /// Get replay count for a recording (from cache if available)
  int? getReplayCount(int recordingId) {
    try {
      final recording = recordings.firstWhere((r) => r.id == recordingId);
      return recording.replayCount;
    } catch (_) {
      return null;
    }
  }

  /// Check if a recording is in watch history
  WatchHistoryItem? getWatchHistoryItem(int recordingId) {
    try {
      return watchHistory.firstWhere((item) => item.recordingId == recordingId);
    } catch (_) {
      return null;
    }
  }

  // Download methods

  /// Get download status for a recording
  DownloadStatus getDownloadStatus(int recordingId) {
    return _downloadStatuses[recordingId] ?? DownloadStatus.notDownloaded;
  }

  /// Get download progress for a recording
  double getDownloadProgress(int recordingId) {
    return _downloadProgress[recordingId] ?? 0.0;
  }

  /// Start downloading a recording
  Future<void> downloadRecording(
    Recording recording, {
    required String downloadUrl,
    String? companyName,
    String? companySlug,
    Function(double)? onProgress,
  }) async {
    final recordingId = recording.id;

    // Check if already downloading or downloaded
    final status = getDownloadStatus(recordingId);
    if (status == DownloadStatus.downloading ||
        status == DownloadStatus.downloaded) {
      return;
    }

    _downloadStatuses[recordingId] = DownloadStatus.downloading;
    _downloadProgress[recordingId] = 0.0;
    notifyListeners();

    try {
      // Get download manager
      final downloadManager = DownloadManager.instance;

      await downloadManager.queueDownload(
        recording: recording,
        downloadUrl: downloadUrl,
        companyName: companyName,
        companySlug: companySlug,
      );
    } catch (e) {
      _downloadStatuses[recordingId] = DownloadStatus.failed;
      debugPrint('Failed to start download: $e');
      notifyListeners();
    }
  }

  /// Play a downloaded recording offline
  Future<void> playDownloadedRecording(int recordingId) async {
    try {
      final downloadsService = RecordingsDownloadsService.instance;

      // Check if recording is downloaded
      final isDownloaded = await downloadsService.isRecordingDownloaded(
        recordingId,
      );
      if (!isDownloaded) {
        throw Exception('Recording not downloaded');
      }

      // Get decrypted file path
      final filePath = await downloadsService.getDecryptedFilePath(recordingId);

      // Get download info for the recording
      final download = await downloadsService.getDownload(recordingId);

      // Stop any current playback
      await _player.stop();
      _positionTimer?.cancel();

      currentRecording = Recording(
        id: recordingId,
        companyId: 0,
        title: download?.title ?? 'Downloaded Recording',
        description: download?.description,
        s3Url: filePath,
        streamingUrl: filePath,
        durationSeconds: download?.durationSeconds,
        thumbnailUrl: download?.thumbnailUrl,
        createdAt: download?.downloadedAt ?? DateTime.now(),
      );

      isPlayerOpen = true;
      isFullScreen = true;
      isCompleted = false;
      errorMessage = null;
      notifyListeners();

      // Set audio source from local file
      await _player.setAudioSource(
        AudioSource.file(
          filePath,
          tag: MediaItem(
            id: recordingId.toString(),
            title: download?.title ?? 'Downloaded Recording',
            artist: download?.description ?? 'Volantis Live',
            artUri: download?.thumbnailUrl != null
                ? Uri.parse(download!.thumbnailUrl!)
                : null,
            duration: download?.durationSeconds != null
                ? Duration(seconds: download!.durationSeconds!)
                : null,
          ),
        ),
      );

      // Seek to last position if available
      if (download != null && download.lastPosition > 0) {
        await _player.seek(Duration(seconds: download.lastPosition));
      }

      await _player.play();
      _startPositionTimer();
    } catch (e) {
      errorMessage = 'Failed to play downloaded recording: ${e.toString()}';
      debugPrint(errorMessage);
      notifyListeners();
    }
  }

  /// Cancel a download
  void cancelDownload(int recordingId) {
    final downloadManager = DownloadManager.instance;
    downloadManager.cancelDownload(recordingId);
    _downloadStatuses[recordingId] = DownloadStatus.notDownloaded;
    _downloadProgress[recordingId] = 0.0;
    notifyListeners();
  }

  /// Delete a downloaded recording
  Future<void> deleteDownload(int recordingId) async {
    try {
      final downloadManager = DownloadManager.instance;
      await downloadManager.deleteDownload(recordingId);
      _downloadStatuses[recordingId] = DownloadStatus.notDownloaded;
      _downloadProgress[recordingId] = 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete download: $e');
    }
  }

  // Expose streams to UI
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  /// Get playback progress as percentage (0.0 to 1.0)
  double get progress {
    if (duration == null || duration!.inSeconds == 0) return 0.0;
    return position.inSeconds / duration!.inSeconds;
  }

  /// Check if currently loading
  bool get isLoading => isLoadingList;

  /// Check if player is active
  bool get hasActivePlayer => isPlayerOpen && currentRecording != null;

  // Internal methods
  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(_positionInterval, (_) => _savePosition());
  }

  void _savePosition() {
    if (currentRecording == null) return;
    _service.updatePosition(currentRecording!.id, _player.position.inSeconds);
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      isCompleted = true;
      if (currentRecording != null) {
        _service.markComplete(currentRecording!.id);
      }
      _positionTimer?.cancel();
      notifyListeners();
    }
  }

  void _onPosition(Duration pos) {
    final dur = currentRecording?.durationSeconds;
    if (dur != null && dur > 0 && !isCompleted) {
      // Mark complete if 90% watched
      if (pos.inSeconds >= (dur * 0.9).toInt()) {
        markComplete();
      }
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _downloadStatusSubscription?.cancel();
    _downloadProgressSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
