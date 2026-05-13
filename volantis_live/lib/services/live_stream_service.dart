import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../features/streams/presentation/providers/streams_provider.dart';
import 'whep_audio_handler.dart';

typedef WebRTCCleanupCallback = Future<void> Function();
typedef WebRTCStateCallback =
    void Function(bool isConnected, bool isConnecting, String? error);

class LiveStreamService {
  static LiveStreamService? _instance;
  static LiveStreamService get instance {
    _instance ??= LiveStreamService._();
    return _instance!;
  }

  LiveStreamService._();

  AudioSession? _audioSession;
  bool _isInitialized = false;
  bool _isStreamActive = false;
  bool _hasAudioFocus = false;
  LiveStream? _currentStream;
  bool _isPlaying = false;
  bool _isMuted = false;
  int? _currentStreamId;

  RTCPeerConnection? _peerConnection;
  MediaStreamTrack? _audioTrack;
  bool _isWebRTCConnected = false;
  bool _isWebRTCConnecting = false;
  String? _webRTCError;
  String? _playbackUrl;

  WhepAudioHandler? _audioHandler;

  WebRTCStateCallback? _onWebRTCStateChanged;
  WebRTCCleanupCallback? _webrtcCleanupCallback;

  final _stateController = StreamController<LiveStreamState>.broadcast();
  Stream<LiveStreamState> get stateStream => _stateController.stream;

  WhepAudioHandler? get audioHandler => _audioHandler;
  Stream<PlaybackState>? get playbackState => _audioHandler?.playbackState;

  LiveStream? get currentStream => _currentStream;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  bool get hasActiveStream => _currentStream != null;

  bool get isWebRTCConnected => _isWebRTCConnected;
  bool get isWebRTCConnecting => _isWebRTCConnecting;
  String? get webRTCError => _webRTCError;
  String? get playbackUrl => _playbackUrl;
  MediaStreamTrack? get audioTrack => _audioTrack;

  void setWebRTCCleanupCallback(WebRTCCleanupCallback? callback) {
    _webrtcCleanupCallback = callback;
  }

  void setWebRTCStateCallback(WebRTCStateCallback? callback) {
    _onWebRTCStateChanged = callback;
  }

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

  void setAudioTrackEnabled(bool enabled) {
    if (_audioTrack != null) {
      _audioTrack!.enabled = enabled;
      _isMuted = !enabled;
      _notifyStateChange();
      debugPrint('Audio track ${enabled ? 'unmuted' : 'muted'} via service');
    }
  }

  Future<void> init({WhepAudioHandler? audioHandler}) async {
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
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      _audioHandler = audioHandler;

      _isInitialized = true;
      debugPrint('LiveStreamService initialized with background support');
    } catch (e) {
      debugPrint('Error initializing LiveStreamService: $e');
    }
  }

  Future<void> startStream(LiveStream stream) async {
    print(
      '{AUDIOS} Attempting to start stream: ${stream.title} (ID: ${stream.id})',
    );

    try {
      if (_currentStream != null && _currentStreamId != null) {
        await _cleanupCurrentStream();
      }

      _currentStream = stream;
      _currentStreamId = stream.id;
      _isPlaying = true;
      _isStreamActive = true;

      String whepUrl =
          stream.whepUrl ??
          stream.playbackUrl ??
          _generateFakeStreamUrl(stream.id);

      if (_audioHandler != null) {
        await _audioHandler!.initStream(
          streamUrl: whepUrl,
          title: stream.title,
          artist: stream.companyName,
          artworkUrl: stream.thumbnailUrl,
        );
        debugPrint('Audio handler updated with stream metadata');
        await _audioHandler!.play();
        debugPrint('Audio handler play() called - notification should appear');
      }

      if (_audioSession != null) {
        await _audioSession!.setActive(true);
        debugPrint('Audio session activated for background playback');
      }

      _notifyStateChange();
      debugPrint('Started stream: ${stream.title}');
    } catch (e) {
      debugPrint('Error starting stream: $e');
      _notifyStateChange();
    }
  }

  bool isStreamPlaying(int streamId) {
    return _currentStreamId == streamId && _isPlaying;
  }

  Future<void> stopStream() async {
    try {
      await _cleanupCurrentStream();

      _isPlaying = false;
      _isStreamActive = false;
      _currentStreamId = null;
      _currentStream = null;

      _audioHandler?.stop();

      if (_audioSession != null) {
        await _audioSession!.setActive(false);
        debugPrint('Audio session deactivated');
      }

      _notifyStateChange();
      debugPrint('Stopped stream');
    } catch (e) {
      debugPrint('Error stopping stream: $e');
    }
  }

  Future<void> _cleanupCurrentStream() async {
    if (_webrtcCleanupCallback != null) {
      try {
        await _webrtcCleanupCallback!();
        debugPrint('WebRTC cleanup completed');
      } catch (e) {
        debugPrint('Error during WebRTC cleanup: $e');
      }
      _webrtcCleanupCallback = null;
    }

    _isPlaying = false;
    _isStreamActive = false;
    _currentStreamId = null;
    _currentStream = null;
  }

  Future<void> switchStream(LiveStream newStream) async {
    debugPrint(
      'Switching from stream ${_currentStream?.title} to ${newStream.title}',
    );
    await startStream(newStream);
  }

  void togglePlayPause() {
    if (_isPlaying) {
      _audioHandler?.pause();
    } else {
      _audioHandler?.play();
    }
    _isPlaying = !_isPlaying;

    if (_audioSession != null) {
      _audioSession!.setActive(true);
    }

    _notifyStateChange();
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    _audioHandler?.setMuted(muted);
    _notifyStateChange();
  }

  void toggleMute() {
    setMuted(!_isMuted);
  }

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

  Future<void> dispose() async {
    await _cleanupCurrentStream();
    _audioHandler = null;
    if (_audioSession != null) {
      await _audioSession!.setActive(false);
    }
    await _stateController.close();
    _isInitialized = false;
    _currentStream = null;
    _webrtcCleanupCallback = null;
  }

  String _generateFakeStreamUrl(int streamId) {
    final randomPart = DateTime.now().millisecondsSinceEpoch.toString();
    return 'https://fake-stream.local/$streamId/$randomPart.mp3';
  }
}

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
