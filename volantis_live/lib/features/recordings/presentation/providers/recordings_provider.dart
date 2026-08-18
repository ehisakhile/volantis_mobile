import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../services/audio_manager.dart';
import '../../data/models/recording_model.dart';
import '../../data/models/recording_download.dart';
import '../../data/services/recordings_service.dart';
import '../../data/services/recordings_downloads_service.dart';
import '../../../../services/download_manager.dart';
import '../../../home/data/models/playlist_model.dart';
import '../../../home/presentation/providers/playlist_provider.dart';

class RecordingsProvider extends ChangeNotifier {
  final RecordingsService _service;
  final PlaylistPlayerProvider? _playlistPlayerProvider;

  List<Recording> recordings = [];
  bool isLoadingList = false;
  bool hasMore = true;
  int _offset = 0;
  static const _limit = 20;

  String? _currentCompanySlug;

  Recording? currentRecording;
  bool isPlayerOpen = false;
  bool isFullScreen = true;
  bool isCompleted = false;

  Timer? _positionTimer;

  List<WatchHistoryItem> watchHistory = [];
  bool isLoadingHistory = false;

  String? errorMessage;

  final Map<int, DownloadStatus> _downloadStatuses = {};
  final Map<int, double> _downloadProgress = {};

  StreamSubscription? _downloadStatusSubscription;
  StreamSubscription? _downloadProgressSubscription;
  StreamSubscription<AudioState>? _audioManagerSubscription;

  RecordingsProvider(this._service, [this._playlistPlayerProvider]) {
    _initialize();
  }

  void _initialize() {
    _initAudioSession();
    _loadExistingDownloads();
    _listenToDownloadUpdates();
    _syncFromAudioManager();

    _audioManagerSubscription =
        AudioManager.instance.stateStream.listen(_onAudioStateChanged);
  }

  void _onAudioStateChanged(AudioState state) {
    if (state.sourceType == AudioSourceType.recording) {
      if (!state.isPlaying && currentRecording != null) {
        _onPlaybackInterrupted();
      }
      if (state.isPlaying && isCompleted) {
        isCompleted = false;
      }
    }
    notifyListeners();
  }

  void _onPlaybackInterrupted() {
    if (currentRecording != null) {
      _savePosition();
    }
  }

  void _syncFromAudioManager() {
    final state = AudioManager.instance.currentState;
    if (state.sourceType == AudioSourceType.recording &&
        state.sourceId != null) {
      _findAndSetCurrentRecording(state.sourceId!);
    }
  }

  void _findAndSetCurrentRecording(int recordingId) {
    try {
      final recording = recordings.firstWhere((r) => r.id == recordingId);
      currentRecording = recording;
      isPlayerOpen = true;
    } catch (_) {
      debugPrint('Recording not found in list: $recordingId');
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

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

  void _listenToDownloadUpdates() {
    final downloadManager = DownloadManager.instance;
    _downloadStatusSubscription =
        downloadManager.downloadStatusStream.listen((status) {
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
      } else if (status.status == DownloadStatus.notDownloaded) {
        _downloadStatuses[status.recordingId] = DownloadStatus.notDownloaded;
        _downloadProgress[status.recordingId] = 0.0;
        notifyListeners();
      } else if (status.status == DownloadStatus.queued) {
        _downloadStatuses[status.recordingId] = DownloadStatus.queued;
        notifyListeners();
      }
    });

    _downloadProgressSubscription =
        downloadManager.downloadProgressStream.listen((progress) {
      _downloadProgress[progress.recordingId] = progress.progress;
      notifyListeners();
    });
  }

  Future<void> loadRecordings(
    String companySlug, {
    bool refresh = false,
  }) async {
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

  Future<void> openRecording(int id, {int? startPosition}) async {
    debugPrint('[RecordingsProvider] openRecording($id)');

    bool isSameRecording = currentRecording?.id == id;

    if (isSameRecording && AudioManager.instance.isRecordingActive) {
      await AudioManager.instance.togglePlayPause();
      return;
    }

    try {
      // Fully stop any active playlist playback first — the playlist provider
      // owns its own VideoPlayerController which AudioManager.stop() won't
      // dispose, so we must call closePlayer() to release it.
      await _playlistPlayerProvider?.closePlayer();

      await AudioManager.instance.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      final recording = await _service.getRecording(id);
      currentRecording = recording;
      isPlayerOpen = true;
      isFullScreen = true;
      isCompleted = false;
      errorMessage = null;
      notifyListeners();

      // Route video recordings through PlaylistPlayerProvider for PiP support
      if (recording.isVideo && _playlistPlayerProvider != null) {
        await _playVideoRecording(recording, startPosition: startPosition);
        return;
      }

      final url = _service.getStreamingUrl(recording.streamingUrl);

      await AudioManager.instance.playRecording(
        recordingId: recording.id,
        title: recording.title,
        artist: recording.description ?? 'Volantis Live',
        artworkUrl: recording.thumbnailUrl,
        audioUrl: url,
        duration: recording.durationSeconds != null
            ? Duration(seconds: recording.durationSeconds!)
            : null,
        startPosition: startPosition != null
            ? Duration(seconds: startPosition)
            : null,
      );
    } catch (e) {
      errorMessage = 'Failed to play recording: ${e.toString()}';
      debugPrint(errorMessage);
      isPlayerOpen = false;
      notifyListeners();
    }
  }

  Future<void> _playVideoRecording(
    Recording recording, {
    int? startPosition,
  }) async {
    final playlist = PlaylistModel(
      id: -recording.id,
      slug: 'recording-${recording.id}',
      title: recording.title,
      description: recording.description,
      itemCount: 1,
      isPublic: true,
      items: [
        PlaylistItemModel(
          id: recording.id,
          title: recording.title,
          description: recording.description,
          thumbnailUrl: recording.thumbnailUrl,
          s3Url: recording.s3Url,
          streamingUrl: recording.streamingUrl,
          durationSeconds: recording.durationSeconds,
          mediaType: 'recording',
        ),
      ],
    );

    final startIndex = 0;
    await _playlistPlayerProvider!.loadStandalonePlaylist(
      playlist: playlist,
      startIndex: startIndex,
    );

    // Close the recordings player sheet since we're now on playlist player screen
    isPlayerOpen = false;
    currentRecording = null;
    notifyListeners();
  }

  void minimize() {
    isFullScreen = false;
    notifyListeners();
  }

  void expand() {
    isFullScreen = true;
    notifyListeners();
  }

  void closePlayer() {
    _savePosition();
    AudioManager.instance.stop();
    isPlayerOpen = false;
    isFullScreen = true;
    currentRecording = null;
    isCompleted = false;
    notifyListeners();
  }

  Future<void> stopAndClose() async {
    _savePosition();
    await AudioManager.instance.stop();
    isPlayerOpen = false;
    isFullScreen = true;
    currentRecording = null;
    isCompleted = false;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
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

  Future<void> setSpeed(double speed) async {
    await AudioManager.instance.setSpeed(speed);
  }

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

  int? getReplayCount(int recordingId) {
    try {
      final recording = recordings.firstWhere((r) => r.id == recordingId);
      return recording.replayCount;
    } catch (_) {
      return null;
    }
  }

  WatchHistoryItem? getWatchHistoryItem(int recordingId) {
    try {
      return watchHistory.firstWhere((item) => item.recordingId == recordingId);
    } catch (_) {
      return null;
    }
  }

  DownloadStatus getDownloadStatus(int recordingId) {
    return _downloadStatuses[recordingId] ?? DownloadStatus.notDownloaded;
  }

  double getDownloadProgress(int recordingId) {
    return _downloadProgress[recordingId] ?? 0.0;
  }

  Future<void> downloadRecording(
    Recording recording, {
    required String downloadUrl,
    String? companyName,
    String? companySlug,
    Function(double)? onProgress,
  }) async {
    final recordingId = recording.id;

    final status = getDownloadStatus(recordingId);
    if (status == DownloadStatus.downloading ||
        status == DownloadStatus.downloaded) {
      return;
    }

    _downloadStatuses[recordingId] = DownloadStatus.downloading;
    _downloadProgress[recordingId] = 0.0;
    notifyListeners();

    try {
      final downloadManager = DownloadManager.instance;

      await downloadManager.queueDownload(
        recording: recording,
        downloadUrl: downloadUrl,
        companyName: companyName,
        companySlug: companySlug,
        fileType: recording.isVideo ? 'video' : 'audio',
      );
    } catch (e) {
      _downloadStatuses[recordingId] = DownloadStatus.failed;
      debugPrint('Failed to start download: $e');
      notifyListeners();
    }
  }

  Future<void> playDownloadedRecording(int recordingId) async {
    try {
      await _playlistPlayerProvider?.closePlayer();

      await AudioManager.instance.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      final downloadsService = RecordingsDownloadsService.instance;

      final isDownloaded = await downloadsService.isRecordingDownloaded(
        recordingId,
      );
      if (!isDownloaded) {
        throw Exception('Recording not downloaded');
      }

      final filePath =
          await downloadsService.getDecryptedFilePath(recordingId);
      final download = await downloadsService.getDownload(recordingId);

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

      // Route video downloads through PlaylistPlayerProvider for PiP support
      if (currentRecording!.isVideo && _playlistPlayerProvider != null) {
        await _playVideoRecording(currentRecording!, startPosition: download?.lastPosition);
        return;
      }

      isPlayerOpen = true;
      isFullScreen = true;
      isCompleted = false;
      errorMessage = null;
      notifyListeners();

      await AudioManager.instance.playRecording(
        recordingId: recordingId,
        title: download?.title ?? 'Downloaded Recording',
        artist: download?.description ?? 'Volantis Live',
        artworkUrl: download?.thumbnailUrl,
        audioUrl: filePath,
        duration: download?.durationSeconds != null
            ? Duration(seconds: download!.durationSeconds!)
            : null,
        startPosition: download?.lastPosition != null &&
                download!.lastPosition > 0
            ? Duration(seconds: download.lastPosition)
            : null,
      );
    } catch (e) {
      errorMessage = 'Failed to play downloaded recording: ${e.toString()}';
      debugPrint(errorMessage);
      notifyListeners();
    }
  }

  void cancelDownload(int recordingId) {
    final downloadManager = DownloadManager.instance;
    downloadManager.cancelDownload(recordingId);
    _downloadStatuses[recordingId] = DownloadStatus.notDownloaded;
    _downloadProgress[recordingId] = 0.0;
    notifyListeners();
  }

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

  Stream<Duration> get positionStream =>
      AudioManager.instance.positionStream.map((d) => d ?? Duration.zero);
  Stream<Duration?> get durationStream => AudioManager.instance.durationStream;
  Stream<double> get speedStream => AudioManager.instance.speedStream;

  Stream<PlayerState> get playerStateStream =>
      AudioManager.instance.stateStream.map((state) {
        final processingState = state.isConnecting
            ? ProcessingState.loading
            : state.isPlaying
                ? ProcessingState.ready
                : ProcessingState.idle;
        final playing = state.isPlaying && state.sourceType == AudioSourceType.recording;
        return PlayerState(playing, processingState);
      });

  bool get isPlaying =>
      AudioManager.instance.isPlaying &&
      AudioManager.instance.currentSourceType == AudioSourceType.recording;

  PlayerState get playerState {
    final state = AudioManager.instance.currentState;
    final processingState = state.isConnecting
        ? ProcessingState.loading
        : state.isPlaying
            ? ProcessingState.ready
            : ProcessingState.idle;
    final playing =
        state.isPlaying && state.sourceType == AudioSourceType.recording;
    return PlayerState(playing, processingState);
  }

  Duration get position => AudioManager.instance.position;
  Duration? get duration => AudioManager.instance.duration;

  double get progress => AudioManager.instance.progress;
  bool get isLoading => isLoadingList;
  bool get hasActivePlayer => isPlayerOpen && currentRecording != null;

  void _savePosition() {
    if (currentRecording == null) return;
    _service.updatePosition(currentRecording!.id, position.inSeconds);
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _downloadStatusSubscription?.cancel();
    _downloadProgressSubscription?.cancel();
    _audioManagerSubscription?.cancel();
    super.dispose();
  }
}