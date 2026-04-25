import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/creator_stream_model.dart';
import '../../data/services/creator_streaming_service.dart';
import '../../data/services/webrtc_service.dart';
import '../../data/services/audio_source_manager.dart';
import '../../data/services/audio_mixer_engine.dart';
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
  final AudioSourceManager _audioSourceManager = AudioSourceManager();
  final AudioMixerEngine _mixerEngine = AudioMixerEngine.instance;
  final StreamRecorder _streamRecorder = StreamRecorder();

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
  Timer? _audioLevelTimer;

  bool _useMicrophone = true;
  bool _useSystemAudio = false;
  bool _mixAudio = false;
  bool _isMuted = false;
  double _microphoneVolume = 100.0;
  double _systemAudioVolume = 100.0;
  double _backgroundAudioVolume = 100.0;
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
  bool get useSystemAudio => _useSystemAudio;
  bool get mixAudio => _mixAudio;
  bool get isMuted => _isMuted;
  double get microphoneVolume => _microphoneVolume;
  double get systemAudioVolume => _systemAudioVolume;
  double get backgroundAudioVolume => _backgroundAudioVolume;
  double get masterVolume => _masterVolume;
  String? get selectedMicDeviceId => _selectedMicDeviceId;
  List<AudioDevice> get availableMicDevices => _availableMicDevices;
  StreamingStats get streamingStats => _streamingStats;

  bool get wantsToRecord => _wantsToRecord;
  bool get autoUploadRecording => _autoUploadRecording;
  StreamRecorder get streamRecorder => _streamRecorder;

  AudioSourceManager get audioSourceManager => _audioSourceManager;
  AudioMixerEngine get mixerEngine => _mixerEngine;
  WebRTCService get webrtcService => _webrtcService;

  Future<void> init() async {
    _state = CreatorState.loading;
    notifyListeners();

    try {
      await _audioSourceManager.initialize();
      await _audioSourceManager.enumerateInputDevices();
      notifyListeners();

      _currentStream = await _service.getActiveStream();
      if (_currentStream != null) {
        _state = CreatorState.streaming;
        _setupWebRTCListeners();
        _startTimers();
      } else {
        await _loadPastStreams();
        _state = CreatorState.loaded;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = CreatorState.error;
    }
    notifyListeners();
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

  void _startAudioLevelPolling() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final level = _mixerEngine.masterAudioLevel;
      _streamingStats = _streamingStats.copyWith(audioLevel: level);
      notifyListeners();
    });
  }

  void _stopAudioLevelPolling() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
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
    _state = CreatorState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentStream = await _service.startAudioStream(
        title: title,
        description: description,
      );

      if (_currentStream?.cfWebrtcPublishUrl == null) {
        throw Exception('No WebRTC publish URL available');
      }

      await _mixerEngine.startMixing();

      if (_useMicrophone) {
        await _audioSourceManager.startMicrophoneCapture();
        await _mixerEngine.setMicrophoneEnabled(true);
      }

      if (_useSystemAudio) {
        await _audioSourceManager.startSystemAudioCapture();
        await _mixerEngine.setSystemAudioEnabled(true);
      }

      _mixerEngine.setMicrophoneVolume(_microphoneVolume);
      _mixerEngine.setSystemAudioVolume(_systemAudioVolume);
      _mixerEngine.setBackgroundMusicVolume(_backgroundAudioVolume);
      _mixerEngine.setMasterVolume(_masterVolume);

      await _webrtcService.connect(
        streamSlug: _currentStream!.slug,
        whipEndpoint: _currentStream!.cfWebrtcPublishUrl!,
      );

      if (_wantsToRecord) {
        await _streamRecorder.startRecording();
      }

      _state = CreatorState.streaming;
      _streamDuration = 0;
      _startTimers();
      _startAudioLevelPolling();
      notifyListeners();
      return true;
    } catch (e) {
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
    if (_currentStream == null) return false;

    _state = CreatorState.loading;
    notifyListeners();

    try {
      if (_wantsToRecord) {
        await _streamRecorder.stopRecording();
      }

      await _webrtcService.disconnect();
      await _mixerEngine.stopMixing();
      await _audioSourceManager.stopAll();
      _stopAudioLevelPolling();

      _currentStream = await _service.stopStream(_currentStream!.slug);
      _stopTimers();
      await _loadPastStreams();
      _state = CreatorState.loaded;
      notifyListeners();
      return true;
    } catch (e) {
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
    _useMicrophone = value;
    if (isStreaming) {
      if (value) {
        _audioSourceManager.startMicrophoneCapture();
        _mixerEngine.setMicrophoneEnabled(true);
      } else {
        _audioSourceManager.stopMicrophoneCapture();
        _mixerEngine.setMicrophoneEnabled(false);
      }
    }
    notifyListeners();
  }

  void setUseSystemAudio(bool value) {
    _useSystemAudio = value;
    if (isStreaming) {
      if (value) {
        _audioSourceManager.startSystemAudioCapture();
        _mixerEngine.setSystemAudioEnabled(true);
      } else {
        _audioSourceManager.stopSystemAudioCapture();
        _mixerEngine.setSystemAudioEnabled(false);
      }
    }
    notifyListeners();
  }

  void setMixAudio(bool value) {
    _mixAudio = value;
    notifyListeners();
  }

  void setMicrophoneVolume(double volume) {
    _microphoneVolume = volume;
    _mixerEngine.setMicrophoneVolume(volume);
    notifyListeners();
  }

  void setSystemAudioVolume(double volume) {
    _systemAudioVolume = volume;
    _mixerEngine.setSystemAudioVolume(volume);
    notifyListeners();
  }

  void setBackgroundAudioVolume(double volume) {
    _backgroundAudioVolume = volume;
    _mixerEngine.setBackgroundMusicVolume(volume);
    notifyListeners();
  }

  void setMasterVolume(double volume) {
    _masterVolume = volume;
    _mixerEngine.setMasterVolume(volume);
    notifyListeners();
  }

  void setSelectedMicDevice(String? deviceId) {
    _selectedMicDeviceId = deviceId;
    if (isStreaming && _useMicrophone) {
      AudioDevice? selectedDevice;
      for (final device in _availableMicDevices) {
        if (device.deviceId == deviceId) {
          selectedDevice = device;
          break;
        }
      }
      if (selectedDevice != null) {
        _audioSourceManager.selectInputDevice(selectedDevice);
      }
    }
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

  Future<void> startBackgroundAudio(String filePath) async {
    await _audioSourceManager.startBackgroundAudio(filePath);
    await _mixerEngine.setBackgroundMusicEnabled(true);
    notifyListeners();
  }

  Future<void> stopBackgroundAudio() async {
    await _audioSourceManager.stopBackgroundAudio();
    await _mixerEngine.setBackgroundMusicEnabled(false);
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
    _stopTimers();
    _stopAudioLevelPolling();
    _webrtcService.setStateCallback(null);
    _webrtcService.setStatsCallback(null);
    _webrtcStateSubscription?.cancel();
    _webrtcStatsSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    super.dispose();
  }
}
