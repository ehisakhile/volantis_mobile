import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'audio_manager.dart';
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

  bool _isInitialized = false;
  LiveStreamData? _currentStream;

  MediaStreamTrack? _audioTrack;
  bool _isWebRTCConnected = false;
  bool _isWebRTCConnecting = false;
  String? _webRTCError;
  String? _playbackUrl;

  WebRTCStateCallback? _onWebRTCStateChanged;
  WebRTCCleanupCallback? _webrtcCleanupCallback;

  final _stateController = StreamController<LiveStreamState>.broadcast();
  Stream<LiveStreamState> get stateStream => _stateController.stream;

  StreamSubscription<AudioState>? _audioManagerSubscription;

  WhepAudioHandler? get audioHandler => AudioManager.instance.whepHandler;
  Stream<PlaybackState>? get playbackState =>
      AudioManager.instance.stateStream.map((state) {
        return PlaybackState(
          controls: state.isPlaying
              ? [MediaControl.pause, MediaControl.stop]
              : [MediaControl.play, MediaControl.stop],
          processingState: state.isConnecting
              ? AudioProcessingState.loading
              : state.isPlaying
                  ? AudioProcessingState.ready
                  : AudioProcessingState.idle,
          playing: state.isPlaying,
        );
      });

  LiveStreamData? get currentStream => _currentStream;
  bool get isPlaying =>
      AudioManager.instance.isPlaying &&
      AudioManager.instance.currentSourceType == AudioSourceType.liveStream;
  bool get isMuted => AudioManager.instance.isMuted;
  bool get hasActiveStream =>
      AudioManager.instance.currentSourceType == AudioSourceType.liveStream;

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
    AudioManager.instance.setMuted(!enabled);
    if (_audioTrack != null) {
      _audioTrack!.enabled = enabled;
    }
    _notifyStateChange();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    _audioManagerSubscription =
        AudioManager.instance.stateStream.listen((state) {
      _notifyStateChange();
    });

    _isInitialized = true;
    debugPrint('LiveStreamService initialized with AudioManager');
  }

  Future<void> startStream(LiveStreamData stream) async {
    debugPrint('{AUDIOS} Starting stream via AudioManager: ${stream.title}');

    try {
      String whepUrl =
          stream.whepUrl ??
          stream.playbackUrl ??
          _generateFakeStreamUrl(stream.id);

      await AudioManager.instance.playLiveStream(
        streamUrl: whepUrl,
        title: stream.title,
        artist: stream.companyName,
        artworkUrl: stream.thumbnailUrl,
        streamId: stream.id,
      );

      _currentStream = stream;
      _notifyStateChange();
      debugPrint('Started stream: ${stream.title}');
    } catch (e) {
      debugPrint('Error starting stream: $e');
      _notifyStateChange();
    }
  }

  bool isStreamPlaying(int streamId) {
    return AudioManager.instance.currentSourceType ==
            AudioSourceType.liveStream &&
        AudioManager.instance.currentState.sourceId == streamId;
  }

  Future<void> stopStream() async {
    try {
      await _cleanupCurrentStream();
      await AudioManager.instance.stop();
      _currentStream = null;
      _notifyStateChange();
      debugPrint('Stream stopped via AudioManager');
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
  }

  Future<void> switchStream(LiveStreamData newStream) async {
    debugPrint(
        'Switching from stream ${_currentStream?.title} to ${newStream.title}');
    await startStream(newStream);
  }

  void togglePlayPause() {
    AudioManager.instance.togglePlayPause();
    _notifyStateChange();
  }

  void setMuted(bool muted) {
    AudioManager.instance.setMuted(muted);
    _notifyStateChange();
  }

  void toggleMute() {
    AudioManager.instance.toggleMute();
    _notifyStateChange();
  }

  void setCurrentStreamDetails(LiveStreamData stream) {
    _currentStream = stream;
    _notifyStateChange();
  }

  void _notifyStateChange() {
    _stateController.add(
      LiveStreamState(
        liveStream: _currentStream,
        isPlaying: isPlaying,
        isMuted: isMuted,
      ),
    );
  }

  Future<void> dispose() async {
    _audioManagerSubscription?.cancel();
    await _cleanupCurrentStream();
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
  final LiveStreamData? liveStream;
  final bool isPlaying;
  final bool isMuted;

  LiveStreamState({
    this.liveStream,
    required this.isPlaying,
    required this.isMuted,
  });
}

class LiveStreamData {
  final int id;
  final String title;
  final String slug;
  final int companyId;
  final String companySlug;
  final String companyName;
  final String? companyLogoUrl;
  final bool isLive;
  final int viewerCount;
  final int totalViews;
  final String? thumbnailUrl;
  final DateTime? startedAt;
  final String? whepUrl;
  final String? playbackUrl;
  final String? streamType;

  const LiveStreamData({
    required this.id,
    required this.title,
    required this.slug,
    required this.companyId,
    required this.companySlug,
    required this.companyName,
    this.companyLogoUrl,
    required this.isLive,
    required this.viewerCount,
    this.totalViews = 0,
    this.thumbnailUrl,
    this.startedAt,
    this.whepUrl,
    this.playbackUrl,
    this.streamType,
  });

  bool get isVideoStream => streamType == 'video';

  factory LiveStreamData.fromLiveStream(dynamic liveStream) {
    return LiveStreamData(
      id: liveStream.id,
      title: liveStream.title,
      slug: liveStream.slug,
      companyId: liveStream.companyId,
      companySlug: liveStream.companySlug,
      companyName: liveStream.companyName,
      companyLogoUrl: liveStream.companyLogoUrl,
      isLive: liveStream.isLive,
      viewerCount: liveStream.viewerCount,
      totalViews: liveStream.totalViews,
      thumbnailUrl: liveStream.thumbnailUrl,
      startedAt: liveStream.startedAt,
      whepUrl: liveStream.whepUrl,
      playbackUrl: liveStream.playbackUrl,
      streamType: liveStream.streamType,
    );
  }
}