import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import '../features/streams/presentation/providers/streams_provider.dart';

/// Service for managing live stream background playback with notifications
class LiveStreamService {
  static LiveStreamService? _instance;
  static LiveStreamService get instance {
    _instance ??= LiveStreamService._();
    return _instance!;
  }

  LiveStreamService._();

  AudioSession? _audioSession;
  bool _isInitialized = false;
  LiveStream? _currentStream;
  bool _isPlaying = false;

  // Stream controller for state updates
  final _stateController = StreamController<LiveStreamState>.broadcast();
  Stream<LiveStreamState> get stateStream => _stateController.stream;

  LiveStream? get currentStream => _currentStream;
  bool get isPlaying => _isPlaying;
  bool get hasActiveStream => _currentStream != null;

  /// Initialize audio session for background playback
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      _isInitialized = true;
      debugPrint('LiveStreamService initialized');
    } catch (e) {
      debugPrint('Error initializing LiveStreamService: $e');
    }
  }

  /// Start playing a new stream
  Future<void> startStream(LiveStream stream) async {
    await init();

    // If same stream, just resume
    if (_currentStream != null && _currentStream!.id == stream.id) {
      _isPlaying = true;
      _notifyState();
      return;
    }

    // Stop current stream if different
    if (_currentStream != null && _currentStream!.id != stream.id) {
      await stopStream();
    }

    _currentStream = stream;
    _isPlaying = true;
    _notifyState();
    
    debugPrint('Started stream: ${stream.title}');
  }

  /// Pause the current stream
  void pauseStream() {
    _isPlaying = false;
    _notifyState();
  }

  /// Resume the current stream
  void resumeStream() {
    if (_currentStream != null) {
      _isPlaying = true;
      _notifyState();
    }
  }

  /// Stop and clear the current stream
  Future<void> stopStream() async {
    _currentStream = null;
    _isPlaying = false;
    _notifyState();
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (_isPlaying) {
      pauseStream();
    } else {
      resumeStream();
    }
  }

  /// Check if a specific stream is currently playing
  bool isStreamPlaying(int streamId) {
    return _currentStream?.id == streamId && _isPlaying;
  }

  void _notifyState() {
    _stateController.add(LiveStreamState(
      stream: _currentStream,
      isPlaying: _isPlaying,
    ));
  }

  void dispose() {
    _stateController.close();
  }
}

/// State class for live stream
class LiveStreamState {
  final LiveStream? stream;
  final bool isPlaying;

  LiveStreamState({this.stream, required this.isPlaying});
}
