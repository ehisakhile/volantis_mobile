import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../features/streams/presentation/providers/streams_provider.dart';

/// Callback type for WebRTC cleanup
typedef WebRTCCleanupCallback = Future<void> Function();

/// Callback for WebRTC connection state changes
typedef WebRTCStateCallback =
    void Function(bool isConnected, bool isConnecting, String? error);

/// Service for managing live stream state and audio session
/// Uses audio_session for audio focus management
/// NOTE: Background notification is handled separately - this service manages
/// the stream state and audio focus for the WebRTC player
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
  bool _isMuted = false;
  int? _currentStreamId;

  // WebRTC connection state (persists across widget disposal)
  RTCPeerConnection? _peerConnection;
  MediaStreamTrack? _audioTrack;
  bool _isWebRTCConnected = false;
  bool _isWebRTCConnecting = false;
  String? _webRTCError;
  String? _playbackUrl;

  // WebRTC state callback - for UI updates
  WebRTCStateCallback? _onWebRTCStateChanged;

  // WebRTC cleanup callback - set by the player sheet when WebRTC is active
  WebRTCCleanupCallback? _webrtcCleanupCallback;

  // Stream controller for state updates
  final _stateController = StreamController<LiveStreamState>.broadcast();
  Stream<LiveStreamState> get stateStream => _stateController.stream;

  LiveStream? get currentStream => _currentStream;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  bool get hasActiveStream => _currentStream != null;

  // WebRTC state getters
  bool get isWebRTCConnected => _isWebRTCConnected;
  bool get isWebRTCConnecting => _isWebRTCConnecting;
  String? get webRTCError => _webRTCError;
  String? get playbackUrl => _playbackUrl;
  MediaStreamTrack? get audioTrack => _audioTrack;

  /// Set the WebRTC cleanup callback
  void setWebRTCCleanupCallback(WebRTCCleanupCallback? callback) {
    _webrtcCleanupCallback = callback;
  }

  /// Set the WebRTC state change callback
  void setWebRTCStateCallback(WebRTCStateCallback? callback) {
    _onWebRTCStateChanged = callback;
  }

  /// Update WebRTC state and notify listeners
  void updateWebRTCState({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    String? playbackUrl,
    MediaStreamTrack? audioTrack,
  }) {
    if (isConnected != null) _isWebRTCConnected = isConnected;
    if (isConnecting != null) _isWebRTCConnecting = isConnecting;
    if (error != null) _webRTCError = error;
    if (playbackUrl != null) _playbackUrl = playbackUrl;
    if (audioTrack != null) _audioTrack = audioTrack;

    _onWebRTCStateChanged?.call(
      _isWebRTCConnected,
      _isWebRTCConnecting,
      _webRTCError,
    );
    _notifyStateChange();
  }

  /// Set audio track enabled/disabled (mute/unmute)
  void setAudioTrackEnabled(bool enabled) {
    if (_audioTrack != null) {
      _audioTrack!.enabled = enabled;
      _isMuted = !enabled;
      _notifyStateChange();
      debugPrint('Audio track ${enabled ? 'unmuted' : 'muted'} via service');
    }
  }

  /// Initialize audio session for playback
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      _isInitialized = true;
      debugPrint('LiveStreamService initialized');
    } catch (e) {
      debugPrint('Error initializing LiveStreamService: $e');
    }
  }

  /// Start a live stream - properly closes any existing stream first
  Future<void> startStream(LiveStream stream) async {
    try {
      // If there's already an active stream, clean it up first
      if (_currentStream != null && _currentStreamId != null) {
        await _cleanupCurrentStream();
      }

      _currentStream = stream;
      _currentStreamId = stream.id;
      _isPlaying = true;

      // Request audio focus for playback
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
      }

      _notifyStateChange();
      debugPrint('Started stream: ${stream.title}');
    } catch (e) {
      debugPrint('Error starting stream: $e');
      _notifyStateChange();
    }
  }

  /// Check if a specific stream is currently playing
  bool isStreamPlaying(int streamId) {
    return _currentStreamId == streamId && _isPlaying;
  }

  /// Stop the current stream
  Future<void> stopStream() async {
    try {
      // Clean up WebRTC connection first
      await _cleanupCurrentStream();

      _isPlaying = false;
      _currentStreamId = null;
      _currentStream = null;

      // Release audio focus
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
      }

      _notifyStateChange();
      debugPrint('Stopped stream');
    } catch (e) {
      debugPrint('Error stopping stream: $e');
    }
  }

  /// Internal method to cleanup current stream (WebRTC disconnection)
  Future<void> _cleanupCurrentStream() async {
    // Call WebRTC cleanup if registered
    if (_webrtcCleanupCallback != null) {
      try {
        await _webrtcCleanupCallback!();
        debugPrint('WebRTC cleanup completed');
      } catch (e) {
        debugPrint('Error during WebRTC cleanup: $e');
      }
      _webrtcCleanupCallback = null;
    }

    // Reset state
    _isPlaying = false;
    _currentStreamId = null;
    _currentStream = null;

    // Release audio focus
    if (_audioSession != null) {
      try {
        await _audioSession!.setActive(false);
      } catch (e) {
        debugPrint('Error releasing audio focus: $e');
      }
    }
  }

  /// Switch to a new stream - cleans up old one and starts new
  Future<void> switchStream(LiveStream newStream) async {
    debugPrint(
      'Switching from stream ${_currentStream?.title} to ${newStream.title}',
    );
    await startStream(newStream);
  }

  /// Toggle play/pause (for UI state)
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    _notifyStateChange();
  }

  /// Set mute state
  void setMuted(bool muted) {
    _isMuted = muted;
    _notifyStateChange();
  }

  /// Toggle mute
  void toggleMute() {
    setMuted(!_isMuted);
  }

  /// Update the current stream (for when stream details are fetched)
  void setCurrentStreamDetails(LiveStream stream) {
    _currentStream = stream;
    _notifyStateChange();
  }

  void _notifyStateChange() {
    _stateController.add(
      LiveStreamState(
        stream: _currentStream,
        isPlaying: _isPlaying,
        isMuted: _isMuted,
      ),
    );
  }

  /// Dispose resources - call this when app is closing
  Future<void> dispose() async {
    await _cleanupCurrentStream();
    await _stateController.close();
    _isInitialized = false;
    _currentStream = null;
    _webrtcCleanupCallback = null;
  }
}

/// Live stream state for the state stream
class LiveStreamState {
  final LiveStream? stream;
  final bool isPlaying;
  final bool isMuted;

  LiveStreamState({
    this.stream,
    required this.isPlaying,
    required this.isMuted,
  });
}
