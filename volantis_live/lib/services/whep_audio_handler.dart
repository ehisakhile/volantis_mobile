import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum _AudioPlaybackMode { liveStream, recording }

class WhepAudioHandler extends BaseAudioHandler {
  RTCPeerConnection? _pc;
  bool _isPlaying = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  String? _streamUrl;
  Timer? _reconnectTimer;
  String? _lastError;
  MediaStreamTrack? _audioTrack;
  _AudioPlaybackMode _playbackMode = _AudioPlaybackMode.liveStream;
  Future<void> Function()? _externalPlay;
  Future<void> Function()? _externalPause;
  Future<void> Function()? _externalStop;

  static const _iceServerUrls = [
    'stun:stun.cloudflare.com:3478',
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];

  Map<String, dynamic> get _iceConfig => {
    'iceServers': _iceServerUrls.map((url) => {'urls': url}).toList(),
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  // ── NOTIFICATION FIX #1 ─────────────────────────────────────────────────────
  // Emit an idle playbackState immediately on construction.
  // audio_service needs at least one state emission to register the handler
  // as active before any notification can be shown.
  WhepAudioHandler() {
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.idle),
    );
  }

  Future<void> initStream({
    required String streamUrl,
    required String title,
    required String artist,
    String? artworkUrl,
  }) async {
    _streamUrl = streamUrl;

    // ── NOTIFICATION FIX #2 ───────────────────────────────────────────────────
    // mediaItem MUST be populated before playbackState flips to playing:true.
    // audio_service reads mediaItem to build the notification content.
    // If it's null when playing flips, the notification either won't appear
    // or will show completely blank.
    mediaItem.add(
      MediaItem(
        id: streamUrl,
        title: title,
        artist: artist,
        artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
        duration: null, // null = live / unknown duration
        extras: const {'isLive': true},
      ),
    );

    // Prime the state to "ready" (not playing) so the foreground service
    // is warmed up but notification not yet visible.
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.ready),
    );
  }

  void updateMetadata({
    required String title,
    required String artist,
    String? artworkUrl,
  }) {
    final current = mediaItem.value;
    if (current == null) return;
    mediaItem.add(
      current.copyWith(
        title: title,
        artist: artist,
        artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_playbackMode == _AudioPlaybackMode.recording) {
      if (_externalPlay != null) await _externalPlay!();
      playbackState.add(_buildState(playing: true));
      return;
    }

    if (_isPlaying || _isConnecting || _isDisposed) return;
    if (_streamUrl == null) return;
    await _connect();
  }

  @override
  Future<void> pause() async {
    if (_playbackMode == _AudioPlaybackMode.recording) {
      if (_externalPause != null) await _externalPause!();
      playbackState.add(_buildState(playing: false));
      return;
    }

    _reconnectTimer?.cancel();
    await _disconnect();
    _isPlaying = false;
    if (!_isDisposed) playbackState.add(_buildState(playing: false));
  }

  @override
  Future<void> stop() async {
    if (_playbackMode == _AudioPlaybackMode.recording) {
      if (_externalStop != null) await _externalStop!();
      _playbackMode = _AudioPlaybackMode.liveStream;
      playbackState.add(
        _buildState(playing: false, processingState: AudioProcessingState.idle),
      );
      return;
    }

    _isDisposed = false; // allow re-use after stop
    _reconnectTimer?.cancel();
    await _disconnect();
    _isPlaying = false;
    _lastError = null;
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.idle),
    );
    await super.stop(); // removes the notification
  }

  Future<void> _connect() async {
    if (_isConnecting || _isDisposed) return;
    _isConnecting = true;
    _lastError = null;

    playbackState.add(
      _buildState(
        playing: false,
        processingState: AudioProcessingState.loading,
      ),
    );

    try {
      await _cleanupPeerConnection();

      developer.log('WHEP: Creating peer connection...');
      _pc = await createPeerConnection(_iceConfig);

      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // Register onTrack before createOffer to avoid missing the first event
      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          _audioTrack = event.track;
          developer.log('WHEP: Audio track received');
        }
      };

      // ── NOTIFICATION FIX #3 ───────────────────────────────────────────────
      // onConnectionState is the correct trigger for flipping playing:true,
      // which causes audio_service to start the foreground service and show
      // the notification. Never flip playing:true before this fires.
      _pc!.onConnectionState = (RTCPeerConnectionState state) {
        developer.log('WHEP connection state: $state');
        if (_isDisposed) return;

        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            if (!_isPlaying) {
              _isPlaying = true;
              _isConnecting = false;
              playbackState.add(_buildState(playing: true));
              developer.log(
                'WHEP: playing:true emitted — notification should appear',
              );
            }
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _isPlaying = false;
            playbackState.add(
              _buildState(
                playing: false,
                processingState: AudioProcessingState.buffering,
              ),
            );
            _scheduleReconnect();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _isConnecting = false;
            _isPlaying = false;
            _lastError = 'Connection failed';
            playbackState.add(
              _buildState(
                playing: false,
                processingState: AudioProcessingState.error,
              ),
            );
            _scheduleReconnect();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _isPlaying = false;
            break;
          default:
            break;
        }
      };

      // ── NOTIFICATION FIX #4 ───────────────────────────────────────────────
      // onConnectionState is unreliable on some Android flutter_webrtc builds.
      // Mirror Connected/Failed via ICE state as a fallback so the notification
      // always appears even when onConnectionState doesn't fire.
      _pc!.onIceConnectionState = (RTCIceConnectionState state) {
        developer.log('WHEP ICE state: $state');
        if (_isDisposed) return;

        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            if (!_isPlaying) {
              _isPlaying = true;
              _isConnecting = false;
              playbackState.add(_buildState(playing: true));
              developer.log('WHEP: ICE fallback — notification triggered');
            }
            break;
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            if (!_isPlaying) {
              _isConnecting = false;
              _lastError = 'ICE negotiation failed';
              playbackState.add(
                _buildState(
                  playing: false,
                  processingState: AudioProcessingState.error,
                ),
              );
              _scheduleReconnect();
            }
            break;
          default:
            break;
        }
      };

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      final sdpBody = _normaliseSdp(offer.sdp ?? '');
      developer.log('WHEP: Sending offer to $_streamUrl');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final response = await dio.post<String>(
        _streamUrl!,
        data: sdpBody,
        options: Options(
          headers: {'Content-Type': 'application/sdp'},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('WHEP error: ${response.statusCode}');
      }

      final answerSdp = response.data ?? '';
      if (answerSdp.isEmpty) throw Exception('Empty SDP answer from server');

      await _pc!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );

      _isConnecting = false;
      developer.log('WHEP: SDP exchange complete, waiting for ICE...');
    } catch (e, st) {
      _isConnecting = false;
      _isPlaying = false;
      _lastError = e.toString();
      developer.log('WHEP connection error: $_lastError\n$st', name: 'WHEP');
      if (!_isDisposed) {
        playbackState.add(
          _buildState(
            playing: false,
            processingState: AudioProcessingState.error,
          ),
        );
        _scheduleReconnect();
      }
    }
  }

  String _normaliseSdp(String sdp) {
    final unified = sdp.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final crlf = unified.split('\n').join('\r\n');
    return crlf.endsWith('\r\n') ? crlf : '$crlf\r\n';
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed && !_isPlaying && !_isConnecting && _streamUrl != null) {
        developer.log('WHEP: Attempting reconnect...');
        play();
      }
    });
  }

  Future<void> _disconnect() async {
    _reconnectTimer?.cancel();
    _audioTrack = null;
    await _cleanupPeerConnection();
    _isConnecting = false;
  }

  Future<void> _cleanupPeerConnection() async {
    if (_pc != null) {
      _pc!.onConnectionState = null;
      _pc!.onIceConnectionState = null;
      _pc!.onTrack = null;
      await _pc!.close();
      _pc = null;
    }
  }

  void registerExternalPlaybackControls({
    Future<void> Function()? play,
    Future<void> Function()? pause,
    Future<void> Function()? stop,
  }) {
    _externalPlay = play;
    _externalPause = pause;
    _externalStop = stop;
  }

  void unregisterExternalPlaybackControls() {
    _externalPlay = null;
    _externalPause = null;
    _externalStop = null;
  }

  void updateRecordingMediaItem(MediaItem item, {bool playing = false}) {
    _playbackMode = _AudioPlaybackMode.recording;
    mediaItem.add(item);
    playbackState.add(
      _buildState(
        playing: playing,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  void updateRecordingPlaybackState(bool playing) {
    if (_playbackMode != _AudioPlaybackMode.recording) return;
    playbackState.add(
      _buildState(
        playing: playing,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  void resetToLiveStreamMode() {
    _playbackMode = _AudioPlaybackMode.liveStream;
    mediaItem.add(null);
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.idle),
    );
  }

  @override
  Future<void> onStart(Map<String, dynamic>? extras) async {
    developer.log('WHEP: onStart called, extras: $extras');
    if (!_isDisposed && _streamUrl != null) {
      await _connect();
    }
  }

  @override
  Future<void> onStop() async {
    developer.log('WHEP: onStop called');
    await stop();
  }

  PlaybackState _buildState({
    bool playing = false,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    return PlaybackState(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1],
      processingState: processingState,
      playing: playing,
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    await _cleanupPeerConnection();
    developer.log('WHEP: Handler disposed');
  }

  bool get isConnected => _isPlaying;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  MediaStreamTrack? get audioTrack => _audioTrack;

  void setMuted(bool muted) {
    if (_audioTrack != null) {
      _audioTrack!.enabled = !muted;
      developer.log('WHEP: Audio ${muted ? 'muted' : 'unmuted'}');
    }
  }
}
