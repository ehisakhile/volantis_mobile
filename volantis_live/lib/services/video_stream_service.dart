import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'live_stream_service.dart';

class VideoStreamService {
  static VideoStreamService? _instance;
  static VideoStreamService get instance {
    _instance ??= VideoStreamService._();
    return _instance!;
  }

  VideoStreamService._();

  final Dio _dio = Dio();
  bool _isInitialized = false;
  VideoStreamData? _currentStream;
  RTCPeerConnection? _pc;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _renderer;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;

  final _stateController = StreamController<VideoStreamState>.broadcast();
  Stream<VideoStreamState> get stateStream => _stateController.stream;

  Timer? _retryTimer;

  VideoStreamData? get currentStream => _currentStream;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  RTCVideoRenderer? get renderer => _renderer;

  static const _iceServerUrls = [
    'stun:stun.cloudflare.com:3478',
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];

  dynamic get iceConfig => {
    'iceServers': _iceServerUrls.map((url) => {'urls': url}).toList(),
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  Future<void> init() async {
    if (_isInitialized) return;
    _renderer = RTCVideoRenderer();
    await _renderer!.initialize();
    _isInitialized = true;
    debugPrint('[VideoStreamService] Initialized');
  }

  Future<void> startStream(VideoStreamData stream) async {
    debugPrint('[VideoStreamService] Starting video stream: ${stream.title}');

    final playbackUrl = stream.whepUrl ?? stream.playbackUrl;
    if (playbackUrl == null || playbackUrl.isEmpty) {
      _setError('No playback URL available');
      return;
    }

    try {
      await init();
      await _stopCurrentConnection();

      _currentStream = stream;
      _isConnecting = true;
      _error = null;
      _notifyStateChange();

      _pc = await createPeerConnection(iceConfig);
      _setupPeerConnectionHandlers();

      _remoteStream = await createLocalMediaStream('remote');
      _renderer!.srcObject = _remoteStream;

      await _addTransceivers();

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      final sdpWithOpus = _preferOpus(offer.sdp ?? '');
      final answerSdp = await _sendWhepOffer(playbackUrl, sdpWithOpus);
      if (answerSdp != null) {
        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _pc!.setRemoteDescription(answer);
      }

      debugPrint('[VideoStreamService] Stream started: ${stream.title}');
    } catch (e) {
      debugPrint('[VideoStreamService] Error starting stream: $e');
      _setError('Failed to connect: $e');
      _scheduleRetry();
    }
  }

  void _setupPeerConnectionHandlers() {
    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else if (event.track != null) {
        _remoteStream?.addTrack(event.track!);
      }
      if (_renderer != null && _remoteStream != null) {
        _renderer!.srcObject = _remoteStream;
      }
      _notifyStateChange();
    };

    _pc!.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _setConnected();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          _setConnecting();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _setReconnecting();
          _scheduleRetry();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _setFailed();
          _scheduleRetry();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _setDisconnected();
          break;
        default:
          break;
      }
    };
  }

  Future<void> _addTransceivers() async {
    await _pc!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    await _pc!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
  }

  Future<String?> _sendWhepOffer(String url, String offerSdp) async {
    try {
      final response = await _dio.post(
        url,
        data: offerSdp,
        options: Options(
          headers: {
            'Content-Type': 'application/sdp',
            'Accept': 'application/sdp',
          },
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data.toString();
    } on DioException catch (e) {
      debugPrint('[VideoStreamService] WHEP request failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[VideoStreamService] WHEP request error: $e');
      return null;
    }
  }

  String _preferOpus(String sdp) {
    final match = RegExp(r'a=rtpmap:(\d+) opus\/48000\/2', caseSensitive: false).firstMatch(sdp);
    if (match == null) return sdp;
    final pt = match[1];
    final opusFmtp = 'a=fmtp:$pt minptime=10;useinbandfec=1;stereo=0;maxaveragebitrate=96000';
    if (sdp.contains('a=fmtp:$pt')) {
      return sdp.replaceFirst(RegExp(r'a=fmtp:\d+ [^\r\n]+'), opusFmtp);
    } else {
      final insertAfter = match.group(0)!;
      return sdp.replaceFirst(insertAfter, '$insertAfter\r\n$opusFmtp');
    }
  }

  Future<void> _stopCurrentConnection() async {
    _retryTimer?.cancel();
    _retryTimer = null;

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        track.stop();
      }
      _remoteStream = null;
    }

    if (_pc != null) {
      _pc!.onTrack = null;
      _pc!.onIceConnectionState = null;
      _pc!.close();
      _pc = null;
    }
  }

  Future<void> stopStream() async {
    debugPrint('[VideoStreamService] Stopping stream');
    _retryTimer?.cancel();
    await _stopCurrentConnection();
    _currentStream = null;
    _isConnected = false;
    _isConnecting = false;
    _notifyStateChange();
  }

  void retry() {
    if (_currentStream != null) {
      _retryTimer?.cancel();
      startStream(_currentStream!);
    }
  }

  void _setConnecting() {
    _isConnecting = true;
    _isConnected = false;
    _error = null;
    _notifyStateChange();
  }

  void _setConnected() {
    _retryTimer?.cancel();
    _isConnecting = false;
    _isConnected = true;
    _error = null;
    _notifyStateChange();
  }

  void _setReconnecting() {
    _isConnecting = true;
    _notifyStateChange();
  }

  void _setFailed() {
    _isConnecting = false;
    _isConnected = false;
    _notifyStateChange();
  }

  void _setDisconnected() {
    _isConnecting = false;
    _isConnected = false;
    _notifyStateChange();
  }

  void _setError(String error) {
    _isConnecting = false;
    _isConnected = false;
    _error = error;
    _notifyStateChange();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (_currentStream != null && !_isConnected) {
        startStream(_currentStream!);
      }
    });
  }

  void _notifyStateChange() {
    _stateController.add(VideoStreamState(
      liveStream: _currentStream,
      isConnected: _isConnected,
      isConnecting: _isConnecting,
      error: _error,
    ));
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _stopCurrentConnection();
    _renderer?.dispose();
    _renderer = null;
    await _stateController.close();
    _isInitialized = false;
    _currentStream = null;
  }
}

class VideoStreamState {
  final VideoStreamData? liveStream;
  final bool isConnected;
  final bool isConnecting;
  final String? error;

  VideoStreamState({
    this.liveStream,
    required this.isConnected,
    required this.isConnecting,
    this.error,
  });
}

class VideoStreamData {
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

  const VideoStreamData({
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

  factory VideoStreamData.fromLiveStreamData(LiveStreamData data) {
    return VideoStreamData(
      id: data.id,
      title: data.title,
      slug: data.slug,
      companyId: data.companyId,
      companySlug: data.companySlug,
      companyName: data.companyName,
      companyLogoUrl: data.companyLogoUrl,
      isLive: data.isLive,
      viewerCount: data.viewerCount,
      totalViews: data.totalViews,
      thumbnailUrl: data.thumbnailUrl,
      startedAt: data.startedAt,
      whepUrl: data.whepUrl,
      playbackUrl: data.playbackUrl,
      streamType: data.streamType,
    );
  }
}