import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../services/api_service.dart';

enum WebRTCServiceState {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
  closed,
}

class WebRTCServiceStats {
  final int bitrate;
  final String? codecName;
  final int? packetsLost;
  final int? packetsSent;
  final int? roundTripTime;
  final DateTime timestamp;

  WebRTCServiceStats({
    required this.bitrate,
    this.codecName,
    this.packetsLost,
    this.packetsSent,
    this.roundTripTime,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebRTCServiceStats.empty() {
    return WebRTCServiceStats(
      bitrate: 0,
      timestamp: DateTime.now(),
    );
  }
}

class WebRTCServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  WebRTCServiceException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'WebRTCServiceException: $message (code: $code)';
}

typedef WebRTCServiceStateCallback = void Function(
  WebRTCServiceState state,
  String? error,
);
typedef WebRTCServiceStatsCallback = void Function(
  WebRTCServiceStats stats,
);

class WebRTCService {
  static WebRTCService? _instance;
  static WebRTCService get instance {
    _instance ??= WebRTCService._();
    return _instance!;
  }

  WebRTCService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStreamTrack? _audioTrack;
  RTCRtpSender? _audioSender;

  WebRTCServiceState _state = WebRTCServiceState.idle;
  String? _currentStreamSlug;
  String? _whipEndpoint;
  String? _lastError;

  WebRTCServiceStateCallback? _onStateChanged;
  WebRTCServiceStatsCallback? _onStatsUpdated;

  Timer? _statsTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _statsInterval = Duration(seconds: 2);

  WebRTCServiceState get state => _state;
  String? get currentStreamSlug => _currentStreamSlug;
  String? get lastError => _lastError;
  MediaStreamTrack? get audioTrack => _audioTrack;

  void setStateCallback(WebRTCServiceStateCallback? callback) {
    _onStateChanged = callback;
  }

  void setStatsCallback(WebRTCServiceStatsCallback? callback) {
    _onStatsUpdated = callback;
  }

  void _updateState(WebRTCServiceState newState, [String? error]) {
    _state = newState;
    _lastError = error;
    _onStateChanged?.call(newState, error);
    debugPrint('WebRTCService: State changed to $newState${error != null ? ' - $error' : ''}');
  }

  Map<String, dynamic> _getIceServers() {
    return {
      'iceServers': [
        {
          'urls': 'stun:stun.cloudflare.com:3478',
        },
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    };
  }

  Map<String, dynamic> _getMediaConstraints() {
    return {
      'audio': true,
      'video': false,
    };
  }

  Future<void> connect({
    required String streamSlug,
    required String whipEndpoint,
    MediaStream? providedStream,
  }) async {
    if (_state == WebRTCServiceState.connecting ||
        _state == WebRTCServiceState.connected) {
      debugPrint('WebRTCService: Already connecting or connected');
      return;
    }

    _currentStreamSlug = streamSlug;
    _whipEndpoint = whipEndpoint;
    _reconnectAttempts = 0;

    try {
      await _initializeConnection(providedStream: providedStream);
    } catch (e) {
      _handleConnectionError(e);
    }
  }

  Future<void> _initializeConnection({MediaStream? providedStream}) async {
    _updateState(WebRTCServiceState.connecting);

    try {
      await _cleanupPeerConnection();

      final configuration = _getIceServers();
      debugPrint('WebRTCService: Creating peer connection with config: $configuration');

      _peerConnection = await createPeerConnection(
        configuration,
        _getMediaConstraints(),
      );

      _peerConnection!.onIceConnectionState = _handleIceConnectionState;
      _peerConnection!.onIceCandidate = _handleIceCandidate;
      _peerConnection!.onConnectionState = _handleConnectionState;

      if (providedStream != null) {
        _localStream = providedStream;
      } else {
        _localStream = await navigator.mediaDevices.getUserMedia(
          _getMediaConstraints(),
        );
      }

      _audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (_audioTrack == null) {
        throw WebRTCServiceException(
          'No audio track available',
          code: 'NO_AUDIO_TRACK',
        );
      }

      _audioSender = await _peerConnection!.addTrack(
        _audioTrack!,
        _localStream!,
      );

      debugPrint('WebRTCService: Audio track added, creating SDP offer');

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
        'mandatory': {
          'googEchoCancellation': true,
          'googAutoGainControl': true,
          'googNoiseSuppression': true,
          'googHighpassFilter': true,
        },
      });

      await _peerConnection!.setLocalDescription(offer);

      final sdpWithCodecs = _modifySdpForOpus(offer.sdp ?? '');

      debugPrint('WebRTCService: Sending WHIP request to $_whipEndpoint');

      final whipResponse = await _postWhipOffer(sdpWithCodecs);

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          whipResponse['sdp'],
          whipResponse['type'] ?? 'answer',
        ),
      );

      await _peerConnection!.setConfiguration(_getIceServers());

      _startStatsCollection();

      debugPrint('WebRTCService: WHIP handshake completed successfully');
      _updateState(WebRTCServiceState.connected);
    } catch (e) {
      debugPrint('WebRTCService: Error during initialization: $e');
      rethrow;
    }
  }

  String _modifySdpForOpus(String sdp) {
    final lines = sdp.split('\n');
    final modifiedLines = <String>[];
    bool opusFound = false;

    for (var line in lines) {
      if (line.contains('a=rtpmap:')) {
        if (line.contains('opus/48000')) {
          opusFound = true;
          if (!line.contains('minptime=10')) {
            final parts = line.split(' ');
            if (parts.length >= 2) {
              modifiedLines.add('${parts[0]} ${parts[1]}/2');
            } else {
              modifiedLines.add(line);
            }
            modifiedLines.add('a=fmtp:111 minptime=10;useinbandfec=1');
            continue;
          }
        }
      }
      modifiedLines.add(line);
    }

    if (!opusFound) {
      modifiedLines.add('a=fmtp:111 minptime=10;useinbandfec=1');
    }

    return modifiedLines.join('\n');
  }

  Future<Map<String, dynamic>> _postWhipOffer(String sdp) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/sdp',
          'Accept': 'application/sdp, */*',
        },
      ));

      final token = await ApiService.getToken();
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final response = await dio.post(
        _whipEndpoint!,
        data: sdp,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final contentType = response.headers.value('content-type') ?? '';
        String sdpAnswer = '';

        if (contentType.contains('application/sdp')) {
          sdpAnswer = response.data.toString();
        } else if (response.data is Map<String, dynamic>) {
          sdpAnswer = response.data['sdp'] ?? '';
        }

        if (sdpAnswer.isEmpty) {
          throw WebRTCServiceException(
            'Empty SDP answer from WHIP endpoint',
            code: 'EMPTY_SDP',
          );
        }

        return {
          'sdp': sdpAnswer,
          'type': 'answer',
        };
      } else {
        throw WebRTCServiceException(
          'WHIP request failed with status ${response.statusCode}',
          code: 'WHIP_FAILED',
        );
      }
    } on DioException catch (e) {
      throw WebRTCServiceException(
        'WHIP request failed: ${e.message}',
        code: 'WHIP_DIO_ERROR',
        originalError: e,
      );
    }
  }

  void _handleIceConnectionState(RTCIceConnectionState state) {
    debugPrint('WebRTCService: ICE connection state: $state');

    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _updateState(WebRTCServiceState.connected);
        _reconnectAttempts = 0;
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        debugPrint('WebRTCService: ICE disconnected');
        _triggerReconnect();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        debugPrint('WebRTCService: ICE failed');
        _triggerReconnect();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        _updateState(WebRTCServiceState.closed);
        break;
      default:
        break;
    }
  }

  void _handleConnectionState(RTCPeerConnectionState state) {
    debugPrint('WebRTCService: Connection state: $state');

    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _updateState(WebRTCServiceState.connected);
        _reconnectAttempts = 0;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _triggerReconnect();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _updateState(WebRTCServiceState.failed, 'Connection failed');
        _triggerReconnect();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _updateState(WebRTCServiceState.closed);
        break;
      default:
        break;
    }
  }

  void _handleIceCandidate(RTCIceCandidate candidate) {
    debugPrint('WebRTCService: New ICE candidate: ${candidate.candidate}');
  }

  void _triggerReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _updateState(
        WebRTCServiceState.failed,
        'Max reconnection attempts reached',
      );
      return;
    }

    if (_reconnectTimer?.isActive == true) {
      return;
    }

    _updateState(WebRTCServiceState.reconnecting);
    _reconnectAttempts++;

    debugPrint(
      'WebRTCService: Attempting reconnection $_reconnectAttempts/$_maxReconnectAttempts',
    );

    _reconnectTimer = Timer(_reconnectDelay, () async {
      try {
        await _cleanupPeerConnection();
        await _initializeConnection();
      } catch (e) {
        _handleConnectionError(e);
      }
    });
  }

  void _handleConnectionError(dynamic error) {
    String errorMessage = 'Connection error';

    if (error is WebRTCServiceException) {
      errorMessage = error.message;
    } else {
      errorMessage = error.toString();
    }

    debugPrint('WebRTCService: Connection error: $errorMessage');
    _updateState(WebRTCServiceState.failed, errorMessage);

    _triggerReconnect();
  }

  void _startStatsCollection() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(_statsInterval, (_) async {
      await _collectStats();
    });
  }

  Future<void> _collectStats() async {
    if (_peerConnection == null || _audioTrack == null) {
      return;
    }

    try {
      final stats = await _peerConnection!.getStats();

      int bitrate = 0;
      String? codecName;
      int? packetsLost;
      int? packetsSent;
      int? roundTripTime;

      for (final report in stats) {
        if (report.type == 'outbound-rtp') {
          final bytesSent = report.values['bytesSent'] as int? ?? 0;
          final timestamp = report.values['timestamp'] as int? ?? 0;
          if (timestamp > 0) {
            bitrate = (bytesSent * 8) ~/ 2;
          }
        }

        if (report.type == 'candidate-pair' &&
            report.values['state'] == 'succeeded') {
          roundTripTime = report.values['currentRoundTripTime'] as int?;
        }

        if (report.type == 'remote-inbound-rtp') {
          packetsLost = report.values['packetsLost'] as int?;
          packetsSent = report.values['packetsReceived'] as int?;
        }

        if (report.type == 'codec' &&
            report.values['mimeType']?.toString().contains('opus') == true) {
          codecName = report.values['mimeType'] as String?;
        }
      }

      final serviceStats = WebRTCServiceStats(
        bitrate: bitrate,
        codecName: codecName,
        packetsLost: packetsLost,
        packetsSent: packetsSent,
        roundTripTime: roundTripTime,
      );

      _onStatsUpdated?.call(serviceStats);
    } catch (e) {
      debugPrint('WebRTCService: Error collecting stats: $e');
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _statsTimer?.cancel();
    await _cleanupPeerConnection();
    _currentStreamSlug = null;
    _whipEndpoint = null;
    _updateState(WebRTCServiceState.idle);
  }

  Future<void> _cleanupPeerConnection() async {
    debugPrint('WebRTCService: Cleaning up peer connection');

    _statsTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_audioTrack != null) {
      _audioTrack!.stop();
      _audioTrack = null;
    }

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      _localStream = null;
    }

    if (_peerConnection != null) {
      _peerConnection!.onIceConnectionState = null;
      _peerConnection!.onIceCandidate = null;
      _peerConnection!.onConnectionState = null;

      await _peerConnection!.close();
      _peerConnection = null;
    }

    _audioSender = null;
  }

  Future<void> mute() async {
    if (_audioTrack != null) {
      _audioTrack!.enabled = false;
      debugPrint('WebRTCService: Audio muted');
    }
  }

  Future<void> unmute() async {
    if (_audioTrack != null) {
      _audioTrack!.enabled = true;
      debugPrint('WebRTCService: Audio unmuted');
    }
  }

  bool get isMuted => _audioTrack?.enabled == false;

  Future<void> dispose() async {
    await disconnect();
    _instance = null;
  }
}