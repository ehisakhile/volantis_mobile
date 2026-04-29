import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:volantis_live/features/creator/data/services/audio_source_manager.dart';
import '../../data/models/creator_stream_model.dart';
import '../../data/services/creator_streaming_service.dart';
import '../../data/services/webrtc_service.dart';
import '../../data/services/stream_recorder.dart';

enum CreatorState { initial, loading, loaded, error, streaming }

enum AudioSourceState { microphone, systemAudio, backgroundAudio }

class StreamingStats {
  final int bitrate;
  final String codec;
  final String iceState;
  final int viewerCount;
  final double audioLevel;

  const StreamingStats({
    this.bitrate = 0,
    this.codec = '—',
    this.iceState = '—',
    this.viewerCount = 0,
    this.audioLevel = 0.0,
  });

  StreamingStats copyWith({
    int? bitrate,
    String? codec,
    String? iceState,
    int? viewerCount,
    double? audioLevel,
  }) {
    return StreamingStats(
      bitrate: bitrate ?? this.bitrate,
      codec: codec ?? this.codec,
      iceState: iceState ?? this.iceState,
      viewerCount: viewerCount ?? this.viewerCount,
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }
}

class CreatorProvider extends ChangeNotifier {
  final CreatorStreamingService _service = CreatorStreamingService();
  final WebRTCService _webrtcService = WebRTCService.instance;
  final StreamRecorder _streamRecorder = StreamRecorder();

  void _log(String message) {
    debugPrint('[CreatorProvider] $message');
  }

  CreatorState _state = CreatorState.initial;
  CreatorStream? _currentStream;
  List<CreatorStream> _pastStreams = [];
  List<ChatMessage> _chatMessages = [];
  StreamStats? _streamStats;
  String? _errorMessage;
  int _streamDuration = 0;
  Timer? _durationTimer;
  Timer? _viewerCountTimer;
  Timer? _chatPollingTimer;

  bool _useMicrophone = true;
  bool _isMuted = false;
  double _microphoneVolume = 100.0;
  double _masterVolume = 100.0;

  String? _selectedMicDeviceId;
  List<AudioDevice> _availableMicDevices = [];

  StreamingStats _streamingStats = const StreamingStats();
  StreamSubscription? _webrtcStateSubscription;
  StreamSubscription? _webrtcStatsSubscription;
  StreamSubscription? _audioLevelSubscription;

  bool _wantsToRecord = false;
  bool _autoUploadRecording = false;

  CreatorState get state => _state;
  CreatorStream? get currentStream => _currentStream;
  List<CreatorStream> get pastStreams => _pastStreams;
  List<ChatMessage> get chatMessages => _chatMessages;
  StreamStats? get streamStats => _streamStats;
  String? get errorMessage => _errorMessage;
  int get streamDuration => _streamDuration;
  bool get isStreaming => _currentStream?.isActive ?? false;

  bool get useMicrophone => _useMicrophone;
  bool get isMuted => _isMuted;
  double get microphoneVolume => _microphoneVolume;
  double get masterVolume => _masterVolume;
  String? get selectedMicDeviceId => _selectedMicDeviceId;
  List<AudioDevice> get availableMicDevices => _availableMicDevices;
  StreamingStats get streamingStats => _streamingStats;

  bool get wantsToRecord => _wantsToRecord;
  bool get autoUploadRecording => _autoUploadRecording;
  StreamRecorder get streamRecorder => _streamRecorder;

  WebRTCService get webrtcService => _webrtcService;

  Future<void> init() async {
    _log('init() - Starting initialization');
    _state = CreatorState.loading;
    notifyListeners();

    try {
      _log('init() - Getting active stream from service');
      _currentStream = await _service.getActiveStream();

      if (_currentStream != null) {
        _log('init() - Active stream found: ${_currentStream!.slug}');
        _state = CreatorState.streaming;
        _setupWebRTCListeners();
        _startTimers();
      } else {
        _log('init() - No active stream, loading past streams');
        await _loadPastStreams();
        _state = CreatorState.loaded;
      }
    } catch (e) {
      _log('init() - Error: $e');
      _errorMessage = e.toString();
      _state = CreatorState.error;
    }
    notifyListeners();
    _log('init() - Initialization complete, state: $_state');
  }

  void _startAudioLevelPolling() {
    // Audio level polling removed - using WebRTC service stats instead
  }

  void _stopAudioLevelPolling() {
    // Audio level polling removed - using WebRTC service stats instead
  }

  void _setupWebRTCListeners() {
    _webrtcService.setStateCallback((state, error) {
      String iceState = '—';
      switch (state) {
        case WebRTCServiceState.idle:
          iceState = 'Idle';
          break;
        case WebRTCServiceState.connecting:
          iceState = 'Connecting';
          break;
        case WebRTCServiceState.connected:
          iceState = 'Connected';
          break;
        case WebRTCServiceState.reconnecting:
          iceState = 'Reconnecting';
          break;
        case WebRTCServiceState.failed:
          iceState = 'Failed';
          if (error != null) {
            _errorMessage = error;
          }
          break;
        case WebRTCServiceState.closed:
          iceState = 'Closed';
          break;
      }

      _streamingStats = _streamingStats.copyWith(iceState: iceState);
      notifyListeners();
    });

    _webrtcService.setStatsCallback((stats) {
      _streamingStats = _streamingStats.copyWith(
        bitrate: stats.bitrate,
        codec: stats.codecName ?? '—',
      );
      notifyListeners();
    });
  }

  Future<void> _loadPastStreams() async {
    try {
      _pastStreams = await _service.getUserStreams();
    } catch (e) {
      // Silently fail for past streams
    }
  }

  Future<bool> startAudioStream({
    required String title,
    String? description,
  }) async {
    _log('startAudioStream() - Starting audio stream: title=$title');
    _state = CreatorState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _log('startAudioStream() - Creating stream via API');
      _currentStream = await _service.startAudioStream(
        title: title,
        description: description,
      );
      _log('startAudioStream() - Stream created: ${_currentStream?.slug}');

      if (_currentStream?.cfWebrtcPublishUrl == null) {
        _log('startAudioStream() - ERROR: No WebRTC publish URL available');
        throw Exception('No WebRTC publish URL available');
      }
      _log(
        'startAudioStream() - WHIP endpoint: ${_currentStream!.cfWebrtcPublishUrl}',
      );

      _log('startAudioStream() - Connecting to WebRTC service');
      await _webrtcService.connect(
        streamSlug: _currentStream!.slug,
        whipEndpoint: _currentStream!.cfWebrtcPublishUrl!,
      );
      _log('startAudioStream() - WebRTC connected successfully');

      if (_wantsToRecord) {
        _log('startAudioStream() - Starting recording');
        await _streamRecorder.startRecording();
      }

      _state = CreatorState.streaming;
      _streamDuration = 0;
      _startTimers();
      notifyListeners();
      _log('startAudioStream() - Stream started successfully');
      return true;
    } catch (e, stackTrace) {
      _log('startAudioStream() - ERROR: $e');
      _log('startAudioStream() - StackTrace: $stackTrace');
      _errorMessage = e.toString();
      _state = CreatorState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> startVideoStream({
    required String title,
    String? description,
  }) async {
    return startAudioStream(title: title, description: description);
  }

  Future<bool> stopStream() async {
    _log('stopStream() - Stopping stream');
    if (_currentStream == null) {
      _log('stopStream() - No current stream to stop');
      return false;
    }

    _state = CreatorState.loading;
    notifyListeners();

    try {
      if (_wantsToRecord) {
        _log('stopStream() - Stopping recording');
        await _streamRecorder.stopRecording();
      }

      _log('stopStream() - Disconnecting WebRTC');
      await _webrtcService.disconnect();
      _log('stopStream() - WebRTC disconnected');

      _log('stopStream() - Notifying API to stop stream');
      _currentStream = await _service.stopStream(_currentStream!.slug);
      _log('stopStream() - Stream stopped via API');

      _stopTimers();
      await _loadPastStreams();
      _state = CreatorState.loaded;
      notifyListeners();
      _log('stopStream() - Stream stopped successfully');
      return true;
    } catch (e, stackTrace) {
      _log('stopStream() - ERROR: $e');
      _log('stopStream() - StackTrace: $stackTrace');
      _errorMessage = e.toString();
      _state = CreatorState.error;
      notifyListeners();
      return false;
    }
  }

  void _startTimers() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _streamDuration++;
      notifyListeners();
    });

    _viewerCountTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshViewerCount();
    });

    _chatPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshChat();
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _viewerCountTimer?.cancel();
    _chatPollingTimer?.cancel();
    _durationTimer = null;
    _viewerCountTimer = null;
    _chatPollingTimer = null;
  }

  Future<void> _refreshViewerCount() async {
    if (_currentStream == null) return;
    try {
      _streamStats = await _service.getViewerCount(
        _currentStream!.slug,
        _currentStream!.companyId,
      );
      _streamingStats = _streamingStats.copyWith(
        viewerCount: _streamStats?.viewerCount ?? 0,
      );
      notifyListeners();
    } catch (e) {
      // Silently fail for viewer count updates
    }
  }

  Future<void> _refreshChat() async {
    if (_currentStream == null) return;
    try {
      _chatMessages = await _service.getChatMessages(_currentStream!.slug);
      notifyListeners();
    } catch (e) {
      // Silently fail for chat updates
    }
  }

  Future<bool> sendChatMessage(String content) async {
    if (_currentStream == null) return false;
    try {
      final message = await _service.sendChatMessage(
        _currentStream!.slug,
        content,
      );
      _chatMessages.insert(0, message);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void setUseMicrophone(bool value) {
    _log('setUseMicrophone() - value: $value, isStreaming: $isStreaming');
    _useMicrophone = value;
    notifyListeners();
  }

  void setMicrophoneVolume(double volume) {
    _log('setMicrophoneVolume() - volume: $volume');
    _microphoneVolume = volume;
    notifyListeners();
  }

  void setMasterVolume(double volume) {
    _log('setMasterVolume() - volume: $volume');
    _masterVolume = volume;
    notifyListeners();
  }

  void setSelectedMicDevice(String? deviceId) {
    _selectedMicDeviceId = deviceId;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_isMuted) {
      await _webrtcService.unmute();
    } else {
      await _webrtcService.mute();
    }
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void promptRecording() {
    _streamRecorder.promptRecording();
    notifyListeners();
  }

  void acceptRecording({bool withAutoUpload = false}) {
    _wantsToRecord = true;
    _autoUploadRecording = withAutoUpload;
    if (withAutoUpload) {
      _streamRecorder.acceptRecordingWithAutoUpload();
    } else {
      _streamRecorder.acceptRecording();
    }
    notifyListeners();
  }

  void declineRecording() {
    _wantsToRecord = false;
    _autoUploadRecording = false;
    _streamRecorder.declineRecording();
    notifyListeners();
  }

  String get formattedDuration {
    final hours = _streamDuration ~/ 3600;
    final minutes = (_streamDuration % 3600) ~/ 60;
    final seconds = _streamDuration % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _log('dispose() - Cleaning up provider');
    _stopTimers();
    _webrtcService.setStateCallback(null);
    _webrtcService.setStatsCallback(null);
    _webrtcStateSubscription?.cancel();
    _webrtcStatsSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    super.dispose();
    _log('dispose() - Provider disposed');
  }
}
