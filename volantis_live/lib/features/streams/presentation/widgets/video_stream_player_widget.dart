import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VideoConnectionStatus { idle, connecting, connected, reconnecting, failed, disconnected }

class VideoStreamPlayerWidget extends StatefulWidget {
  final String? whepUrl;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final VoidCallback? onConnectionStateChanged;
  final Function(bool isConnected, bool isConnecting, String? error)? onStateCallback;

  const VideoStreamPlayerWidget({
    super.key,
    this.whepUrl,
    this.playbackUrl,
    this.thumbnailUrl,
    this.onConnectionStateChanged,
    this.onStateCallback,
  });

  @override
  State<VideoStreamPlayerWidget> createState() => _VideoStreamPlayerWidgetState();
}

class _VideoStreamPlayerWidgetState extends State<VideoStreamPlayerWidget> {
  RTCPeerConnection? _pc;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _renderer;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  VideoConnectionStatus _connectionStatus = VideoConnectionStatus.idle;
  bool _hasVideoTrack = false;
  bool _isManuallyStopped = false;
  Timer? _retryTimer;

  static const _iceServerUrls = [
    'stun:stun.cloudflare.com:3478',
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];

  Map<String, dynamic> get _iceConfig => {
    'iceServers': _iceServerUrls.map((url) => {'urls': url}).toList(),
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  @override
  void initState() {
    super.initState();
    _initRenderer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });
  }

  Future<void> _initRenderer() async {
    _renderer = RTCVideoRenderer();
    await _renderer!.initialize();
    _remoteStream = await createLocalMediaStream('remote');
    if (mounted) setState(() {});
  }

  String? get _playbackUrl => widget.whepUrl ?? widget.playbackUrl;

  Future<void> _startPlayback() async {
    if (_playbackUrl == null || _playbackUrl!.isEmpty) {
      _setError('No playback URL available');
      return;
    }

    await _stopCurrentConnection();
    _isManuallyStopped = false;

    _setConnecting();

    try {
      _pc = await createPeerConnection(_iceConfig);
      _setupPeerConnectionHandlers();

      await _addTransceivers();

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      final answerSdp = await _sendOfferAndGetAnswer(offer.sdp!);
      if (answerSdp != null) {
        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _pc!.setRemoteDescription(answer);
      }
    } catch (e) {
      _setError('Failed to connect: $e');
      _scheduleRetry();
    }
  }

  Future<void> _stopCurrentConnection() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_pc != null) {
      _pc!.onTrack = null;
      _pc!.onIceConnectionState = null;
      _pc!.close();
      _pc = null;
    }
    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        track.stop();
      }
      _remoteStream = null;
    }
    _hasVideoTrack = false;
  }

  void _setupPeerConnectionHandlers() {
    _pc!.onTrack = (RTCTrackEvent event) async {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else if (event.track != null) {
        _remoteStream?.addTrack(event.track!);
      }
      _updateVideoTrackState();
      if (_renderer != null && _remoteStream != null) {
        _renderer!.srcObject = _remoteStream;
      }
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

  Future<String?> _sendOfferAndGetAnswer(String offerSdp) async {
    try {
      final response = await Future.delayed(
        const Duration(seconds: 10),
        () => null,
      );
      return _preferOpus(offerSdp);
    } catch (e) {
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
      return sdp.replaceFirst(match.group(0)!, '${match.group(0)!}\r\n$opusFmtp');
    }
  }

  void _updateVideoTrackState() {
    final videoTracks = _remoteStream?.getVideoTracks() ?? [];
    if (mounted) {
      setState(() {
        _hasVideoTrack = videoTracks.isNotEmpty;
      });
    }
  }

  void _setConnecting() {
    if (!mounted || _isManuallyStopped) return;
    setState(() {
      _isConnecting = true;
      _isConnected = false;
      _error = null;
      _connectionStatus = VideoConnectionStatus.connecting;
    });
    _notifyStateChange();
  }

  void _setConnected() {
    if (!mounted || _isManuallyStopped) return;
    _retryTimer?.cancel();
    setState(() {
      _isConnecting = false;
      _isConnected = true;
      _error = null;
      _connectionStatus = VideoConnectionStatus.connected;
    });
    _notifyStateChange();
  }

  void _setReconnecting() {
    if (!mounted || _isManuallyStopped) return;
    setState(() {
      _connectionStatus = VideoConnectionStatus.reconnecting;
    });
    _notifyStateChange();
  }

  void _setFailed() {
    if (!mounted || _isManuallyStopped) return;
    setState(() {
      _isConnecting = false;
      _isConnected = false;
      _connectionStatus = VideoConnectionStatus.failed;
    });
    _notifyStateChange();
  }

  void _setDisconnected() {
    if (!mounted || _isManuallyStopped) return;
    setState(() {
      _isConnecting = false;
      _isConnected = false;
      _connectionStatus = VideoConnectionStatus.disconnected;
    });
    _notifyStateChange();
  }

  void _setError(String error) {
    if (!mounted || _isManuallyStopped) return;
    setState(() {
      _isConnecting = false;
      _isConnected = false;
      _error = error;
      _connectionStatus = VideoConnectionStatus.failed;
    });
    _notifyStateChange();
  }

  void _notifyStateChange() {
    widget.onStateCallback?.call(_isConnected, _isConnecting, _error);
    widget.onConnectionStateChanged?.call();
  }

  void _scheduleRetry() {
    if (_isManuallyStopped) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (!_isManuallyStopped && mounted) {
        _startPlayback();
      }
    });
  }

  void retry() {
    _startPlayback();
  }

  void stop() {
    _isManuallyStopped = true;
    _stopCurrentConnection();
    if (mounted) {
      setState(() {
        _connectionStatus = VideoConnectionStatus.disconnected;
        _isConnecting = false;
        _isConnected = false;
      });
      _notifyStateChange();
    }
  }

  @override
  void dispose() {
    _isManuallyStopped = true;
    _retryTimer?.cancel();
    _stopCurrentConnection();
    _renderer?.dispose();
    _renderer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF060E20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasVideoTrack && _renderer != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RTCVideoView(
                _renderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            _buildPlaceholder(),
          if (_connectionStatus == VideoConnectionStatus.connecting || _connectionStatus == VideoConnectionStatus.reconnecting)
            _buildLoadingOverlay(),
          if (_error != null)
            _buildErrorOverlay(),
          Positioned(
            bottom: 12,
            right: 12,
            child: _buildStatusBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          widget.thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultPlaceholder(),
        ),
      );
    }
    return _buildDefaultPlaceholder();
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2D45), Color(0xFF0C1929)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          color: Color(0xFF89CEFF),
          size: 64,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Color(0xFF89CEFF),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    String badgeText;
    switch (_connectionStatus) {
      case VideoConnectionStatus.connected:
        badgeColor = Colors.green;
        badgeText = 'LIVE';
        break;
      case VideoConnectionStatus.connecting:
      case VideoConnectionStatus.reconnecting:
        badgeColor = Colors.orange;
        badgeText = 'CONNECTING';
        break;
      case VideoConnectionStatus.failed:
        badgeColor = Colors.red;
        badgeText = 'ERROR';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'OFFLINE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_connectionStatus == VideoConnectionStatus.connected)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}