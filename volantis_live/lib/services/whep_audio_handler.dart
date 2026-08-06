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
  Timer? _statsTimer;
  String? _lastError;
  MediaStreamTrack? _audioTrack;
  MediaStream? _remoteStream;
  _AudioPlaybackMode _playbackMode = _AudioPlaybackMode.liveStream;
  Future<void> Function()? _externalPlay;
  Future<void> Function()? _externalPause;
  Future<void> Function()? _externalStop;
  void Function(bool isPlaying, bool isConnecting)? onStateChanged;
  
  final RTCVideoRenderer _audioRenderer = RTCVideoRenderer();

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
    _audioRenderer.initialize();
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.ready),
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
    if (_streamUrl == null) {
      _lastError = 'Stream URL is missing';
      playbackState.add(
        _buildState(
          playing: false,
          processingState: AudioProcessingState.error,
        ),
      );
      return;
    }
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
    _isConnecting = false;
    _lastError = null;
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.idle),
    );
    // NOTE: We intentionally do NOT call super.stop() here.
    // super.stop() tears down the audio_service foreground service and
    // disconnects the proxy's event relay. After that, playbackState.add()
    // events from this handler no longer reach UI-side listeners
    // (AudioManager._onLiveStreamState). Since we reuse this handler for
    // stream switching, we must keep the proxy alive.
  }

  /// Fully shuts down the handler including the audio_service foreground
  /// service and proxy relay. Call only when the app is truly done with
  /// audio (e.g. on app exit).
  Future<void> hardStop() async {
    await stop();
    await super.stop();
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
    onStateChanged?.call(false, true);

    try {
      await _cleanupPeerConnection();

      developer.log('WHEP: Creating peer connection...');
      _pc = await createPeerConnection(_iceConfig);

      // Add audio transceiver for WHEP audio playback
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // Register onTrack before createOffer to avoid missing the first event
      _pc!.onTrack = (RTCTrackEvent event) {
        final track = event.track;
        final trackInfo = '[WHEP DIAGNOSTICS] ON_TRACK EVENT received:\n'
            '  Kind: ${track.kind}\n'
            '  Track ID: ${track.id}\n'
            '  Enabled: ${track.enabled}\n'
            '  Muted: ${track.muted}\n'
            '  Streams Count: ${event.streams.length}';
        developer.log(trackInfo, name: 'WHEP_DIAGNOSTICS');

        track.onMute = () {
          developer.log('[WHEP DIAGNOSTICS] Track MUTED by system: ${track.kind} (${track.id})', name: 'WHEP_DIAGNOSTICS');
        };

        if (track.kind == 'audio') {
          _audioTrack = track;
          if (event.streams.isNotEmpty) {
            _remoteStream = event.streams.first;
            _audioRenderer.srcObject = _remoteStream;
          }
          _audioTrack!.enabled = !_isMuted; // apply any existing mute state
          Helper.setSpeakerphoneOn(true); // Route WebRTC audio to the loudspeaker!
          developer.log('WHEP: Audio track received and routed to speakerphone', name: 'WHEP_DIAGNOSTICS');

          if (!_isPlaying) {
            _isPlaying = true;
            _isConnecting = false;
            playbackState.add(_buildState(playing: true));
            onStateChanged?.call(true, false);
            developer.log('WHEP: Audio track received — setting playing:true', name: 'WHEP_DIAGNOSTICS');
          }
        } else if (track.kind == 'video') {
          developer.log('WHEP DIAGNOSTICS: Remote VIDEO track available (ID: ${track.id})', name: 'WHEP_DIAGNOSTICS');
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
              onStateChanged?.call(true, false);
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
            onStateChanged?.call(false, true);
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
            onStateChanged?.call(false, false);
            _scheduleReconnect();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _isPlaying = false;
            onStateChanged?.call(false, false);
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
              onStateChanged?.call(true, false);
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
              onStateChanged?.call(false, false);
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
      developer.log('WHEP: Sending offer to $_streamUrl', name: 'WHEP');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
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
        developer.log('WHEP HTTP ERROR ${response.statusCode}: ${response.data}', name: 'WHEP');
        throw Exception('WHEP error ${response.statusCode}: ${response.data}');
      }

      final answerSdp = response.data ?? '';
      if (answerSdp.isEmpty) throw Exception('Empty SDP answer from server');

      _analyzeSdpAnswer(answerSdp);

      await _pc!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );

      _startStatsLogging();

      _isConnecting = false;
      _isPlaying = true;
      playbackState.add(_buildState(playing: true));
      onStateChanged?.call(true, false);
      developer.log('WHEP: SDP exchange complete — setting playing:true', name: 'WHEP');
    } catch (e, st) {
      _isConnecting = false;
      _isPlaying = false;
      _lastError = e.toString();
      developer.log('WHEP connection error: $_lastError\n$st', name: 'WHEP');
      
      bool isStreamEnded = false;
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404 || statusCode == 403) {
          isStreamEnded = true;
          developer.log('WHEP: Stream appears to have ended (HTTP $statusCode)');
        }
      }

      if (!_isDisposed) {
        if (isStreamEnded) {
          playbackState.add(
            _buildState(
              playing: false,
              processingState: AudioProcessingState.completed,
            ),
          );
          // Do not schedule reconnect if stream ended
        } else {
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
    if (_audioTrack != null) {
      _audioTrack!.enabled = false;
      _audioTrack!.stop();
      _audioTrack = null;
      developer.log('WHEP: Audio track stopped and cleaned up');
    }
    await _cleanupPeerConnection();
    _isConnecting = false;
    _isPlaying = false;
    developer.log('WHEP: Disconnected, audio should be stopped');
  }

  Future<void> _cleanupPeerConnection() async {
    developer.log('WHEP: Cleaning up peer connection...');
    _statsTimer?.cancel();
    _statsTimer = null;
    _audioRenderer.srcObject = null;
    _remoteStream = null;
    _audioTrack = null;
    _isConnecting = false;
    _isPlaying = false;
    if (_pc != null) {
      _pc!.onConnectionState = null;
      _pc!.onIceConnectionState = null;
      _pc!.onTrack = null;
      await _pc!.close();
      await _pc!.dispose();
      _pc = null;
    }
  }

  void _analyzeSdpAnswer(String answerSdp) {
    final lines = answerSdp.split('\n');
    String currentMedia = 'none';
    bool hasAudio = false;
    bool hasVideo = false;
    String audioDirection = 'unknown';
    String videoDirection = 'unknown';
    int audioPort = -1;
    int videoPort = -1;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('m=audio')) {
        currentMedia = 'audio';
        hasAudio = true;
        final parts = line.split(' ');
        if (parts.length >= 2) {
          audioPort = int.tryParse(parts[1]) ?? -1;
        }
      } else if (line.startsWith('m=video')) {
        currentMedia = 'video';
        hasVideo = true;
        final parts = line.split(' ');
        if (parts.length >= 2) {
          videoPort = int.tryParse(parts[1]) ?? -1;
        }
      } else if (line.startsWith('a=sendrecv') ||
          line.startsWith('a=sendonly') ||
          line.startsWith('a=recvonly') ||
          line.startsWith('a=inactive')) {
        if (currentMedia == 'audio') audioDirection = line.substring(2);
        if (currentMedia == 'video') videoDirection = line.substring(2);
      }
    }

    final isAudioActive = hasAudio && audioPort > 0 && audioDirection != 'inactive';
    final sdpSummary = '[WHEP DIAGNOSTICS SDP ANSWER ANALYSIS]\n'
        '  Audio Section Present: $hasAudio (Port: $audioPort, Direction: $audioDirection)\n'
        '  Video Section Present: $hasVideo (Port: $videoPort, Direction: $videoDirection)\n'
        '  Is Audio Active in Server Answer?: $isAudioActive';

    developer.log(sdpSummary, name: 'WHEP_DIAGNOSTICS');
    if (!isAudioActive) {
      developer.log('[WHEP DIAGNOSTICS WARNING] The WHEP server SDP answer does NOT contain an active audio track! The live stream publisher may be streaming video-only or audio is disabled on the server side.', name: 'WHEP_DIAGNOSTICS');
    }
  }

  void _startStatsLogging() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_pc == null || _isDisposed) {
        timer.cancel();
        return;
      }
      try {
        final stats = await _pc!.getStats();
        int audioBytes = 0;
        int audioPackets = 0;
        int videoBytes = 0;
        int videoPackets = 0;
        double? audioLevel;

        for (var report in stats) {
          final values = report.values;
          final type = report.type;
          if (type == 'inbound-rtp') {
            final kind = values['kind'] ?? values['mediaType'];
            if (kind == 'audio') {
              audioBytes = int.tryParse(values['bytesReceived']?.toString() ?? '0') ?? 0;
              audioPackets = int.tryParse(values['packetsReceived']?.toString() ?? '0') ?? 0;
              if (values.containsKey('audioLevel')) {
                audioLevel = double.tryParse(values['audioLevel'].toString());
              }
            } else if (kind == 'video') {
              videoBytes = int.tryParse(values['bytesReceived']?.toString() ?? '0') ?? 0;
              videoPackets = int.tryParse(values['packetsReceived']?.toString() ?? '0') ?? 0;
            }
          }
        }

        final logMsg = '[WHEP DIAGNOSTICS WEBRTC STATS]\n'
            '  Audio Bytes Received: $audioBytes\n'
            '  Audio Packets Received: $audioPackets\n'
            '  Audio Level: ${audioLevel ?? 'N/A'}\n'
            '  Video Bytes Received: $videoBytes\n'
            '  Video Packets Received: $videoPackets\n'
            '  Audio Track Enabled: ${_audioTrack?.enabled}\n'
            '  Audio Track Muted: ${_audioTrack?.muted}';

        developer.log(logMsg, name: 'WHEP_DIAGNOSTICS');
      } catch (e) {
        developer.log('WHEP: Error fetching WebRTC stats: $e');
      }
    });
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



  void resetToLiveStreamMode() {
    if (_playbackMode == _AudioPlaybackMode.liveStream) return;
    _playbackMode = _AudioPlaybackMode.liveStream;
    if (mediaItem.value != null) {
      mediaItem.add(null);
    }
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.idle),
    );
  }

  // Called by old versions of audio_service, or custom usage
  Future<void> onStart(Map<String, dynamic>? extras) async {
    developer.log('WHEP: onStart called, extras: $extras');
    if (!_isDisposed && _streamUrl != null) {
      await _connect();
    }
  }

  // Called by old versions of audio_service, or custom usage
  Future<void> onStop() async {
    developer.log('WHEP: onStop called');
    await _disconnect();
    _reconnectTimer?.cancel();
    _lastError = null;
    playbackState.add(
      _buildState(playing: false, processingState: AudioProcessingState.idle),
    );
    // Don't call super.stop() — see stop() comments above.
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

  void updateRecordingPlaybackState({
    required bool playing,
    Duration? position,
    Duration? bufferedPosition,
    double speed = 1.0,
  }) {
    if (_playbackMode != _AudioPlaybackMode.recording) return;

    playbackState.add(
      PlaybackState(
        controls: [
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1],
        processingState: playing ? AudioProcessingState.ready : AudioProcessingState.idle,
        playing: playing,
        updatePosition: position ?? Duration.zero,
        bufferedPosition: bufferedPosition ?? Duration.zero,
        speed: speed,
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.seek,
          MediaAction.stop,
        },
      ),
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
    await _audioRenderer.dispose();
    developer.log('WHEP: Handler disposed');
  }

  bool get isConnected => _isPlaying;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  MediaStreamTrack? get audioTrack => _audioTrack;

  bool _isMuted = false;
  double _volume = 1.0;

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_audioTrack != null) {
      _audioTrack!.enabled = !muted;
      developer.log('WHEP: Audio ${muted ? 'muted' : 'unmuted'}');
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _isMuted = volume == 0;
    if (_audioTrack != null) {
      developer.log('WHEP: Volume set to $_volume (muted: $_isMuted)');
    }
  }

  bool get isMuted => _isMuted;
  double get volume => _volume;
}
