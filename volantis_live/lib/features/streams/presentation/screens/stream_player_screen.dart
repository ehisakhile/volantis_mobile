import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/company_live_stream_model.dart';
import '../providers/streams_provider.dart';

/// Stream player screen for playing live audio streams via WebRTC (WHEP protocol)
class StreamPlayerScreen extends StatefulWidget {
  final String companySlug;
  final String? streamTitle;
  final String? companyName;

  const StreamPlayerScreen({
    super.key,
    required this.companySlug,
    this.streamTitle,
    this.companyName,
  });

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> {
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  String? _error;
  String? _connectionState;
  CompanyLiveStream? _streamDetails;
  String? _playbackUrl;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _connectionState = 'initializing';
      });

      // Fetch stream details from API
      final streamsProvider = context.read<StreamsProvider>();
      final streamDetails = await streamsProvider.getCompanyLiveStream(
        widget.companySlug,
      );

      if (streamDetails == null) {
        throw Exception('Stream not found');
      }

      if (streamDetails.livestream.webrtcPlaybackUrl == null) {
        throw Exception('No playback URL available');
      }

      setState(() {
        _streamDetails = streamDetails;
        _playbackUrl = streamDetails.livestream.webrtcPlaybackUrl;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing player: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _connectionState = 'failed';
      });
    }
  }

  void _onConnected() {
    if (mounted) {
      setState(() {
        _isPlaying = true;
        _connectionState = 'connected';
      });
    }
  }

  void _onDisconnected() {
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _connectionState = 'disconnected';
      });
    }
  }

  void _onError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
        _isPlaying = false;
        _connectionState = 'failed';
      });
    }
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _streamDetails?.livestream.title ??
              widget.streamTitle ??
              'Live Stream',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_streamDetails != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_streamDetails!.livestream.viewerCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Connecting to stream...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializePlayer,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Audio player area
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.black,
            child: _playbackUrl != null && _playbackUrl!.isNotEmpty
                ? AudioWebRTCPlayer(
                    webRTCUrl: _playbackUrl!,
                    onConnected: _onConnected,
                    onDisconnected: _onDisconnected,
                    onError: _onError,
                    isMuted: _isMuted,
                  )
                : _buildWaitingUI(),
          ),
        ),

        // Stream info and controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status and live badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _connectionState == 'connected'
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _connectionState == 'connected'
                              ? Icons.check_circle
                              : Icons.circle,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _connectionState?.toUpperCase() ?? 'CONNECTING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_streamDetails != null) ...[
                    const Icon(
                      Icons.visibility,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_streamDetails!.livestream.viewerCount} watching',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Company name
              if (_streamDetails != null)
                Text(
                  _streamDetails!.company.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

              const SizedBox(height: 8),

              // Stream title
              if (_streamDetails != null &&
                  _streamDetails!.livestream.description != null)
                Text(
                  _streamDetails!.livestream.description!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),

              const SizedBox(height: 16),

              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _toggleMute,
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: _initializePlayer,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            _connectionState == 'connecting'
                ? 'Connecting to stream...'
                : 'Waiting for stream...',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            _connectionState ?? 'idle',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Audio WebRTC Player widget - handles the WebRTC connection for audio streaming
class AudioWebRTCPlayer extends StatefulWidget {
  final String webRTCUrl;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final Function(String)? onError;
  final bool isMuted;

  const AudioWebRTCPlayer({
    super.key,
    required this.webRTCUrl,
    this.onConnected,
    this.onDisconnected,
    this.onError,
    this.isMuted = false,
  });

  @override
  State<AudioWebRTCPlayer> createState() => _AudioWebRTCPlayerState();
}

class _AudioWebRTCPlayerState extends State<AudioWebRTCPlayer> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  bool _isInitialized = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  @override
  void didUpdateWidget(AudioWebRTCPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webRTCUrl != widget.webRTCUrl &&
        widget.webRTCUrl.isNotEmpty) {
      _reconnect();
    }
  }

  Future<void> _initRenderer() async {
    try {
      await _renderer.initialize();
      setState(() => _isInitialized = true);

      if (widget.webRTCUrl.isNotEmpty) {
        _connect();
      }
    } catch (e) {
      setState(() => _error = 'Failed to initialize renderer: $e');
      widget.onError?.call(_error!);
    }
  }

  /// Properly format SDP for Cloudflare Stream
  String _formatSdpForCloudflare(String sdp) {
    developer.log('Original SDP length: ${sdp.length}');

    // Ensure proper line endings (CRLF as per SDP spec)
    var lines = sdp.split(RegExp(r'\r?\n'));

    // Remove empty lines at the start and end
    lines = lines.where((line) => line.trim().isNotEmpty).toList();

    // Join with proper CRLF line endings
    var formattedSdp = lines.join('\r\n');

    // Ensure SDP ends with CRLF (critical for Cloudflare)
    if (!formattedSdp.endsWith('\r\n')) {
      formattedSdp += '\r\n';
    }

    developer.log('Formatted SDP length: ${formattedSdp.length}');
    developer.log('SDP ends with CRLF: ${formattedSdp.endsWith('\r\n')}');

    return formattedSdp;
  }

  /// Optimize SDP for Cloudflare Stream compatibility
  String _optimizeSdpForCloudflare(String sdp) {
    var lines = sdp.split(RegExp(r'\r?\n'));
    var optimizedLines = <String>[];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Keep essential SDP lines
      if (trimmed.startsWith('v=') ||
          trimmed.startsWith('o=') ||
          trimmed.startsWith('s=') ||
          trimmed.startsWith('t=') ||
          trimmed.startsWith('m=') ||
          trimmed.startsWith('c=') ||
          trimmed.startsWith('a=')) {
        // Skip bundle-only for better compatibility
        if (trimmed == 'a=bundle-only') continue;

        // Add recvonly for viewer mode
        if (trimmed.startsWith('m=video') || trimmed.startsWith('m=audio')) {
          optimizedLines.add(trimmed);
          // Ensure we have recvonly direction
          if (!lines.any((l) => l.trim().startsWith('a=recvonly'))) {
            optimizedLines.add('a=recvonly');
          }
        } else {
          optimizedLines.add(trimmed);
        }
      }
    }

    return optimizedLines.join('\r\n') + '\r\n';
  }

  Future<void> _connectToCloudflareStream(RTCSessionDescription offer) async {
    try {
      developer.log('=== Connecting to Cloudflare Stream ===');
      developer.log('URL: ${widget.webRTCUrl}');

      // Format SDP properly with CRLF line endings
      var sdpToSend = _formatSdpForCloudflare(offer.sdp ?? '');

      // Optimize SDP for Cloudflare
      sdpToSend = _optimizeSdpForCloudflare(sdpToSend);

      developer.log('Final SDP being sent (length: ${sdpToSend.length})');

      // Try raw SDP format first (Cloudflare's preferred method)
      final response = await http.post(
        Uri.parse(widget.webRTCUrl),
        headers: {
          'Content-Type': 'application/sdp',
          'Accept': 'application/sdp',
        },
        body: sdpToSend,
      );

      developer.log('Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Cloudflare returns raw SDP answer
        var answerSdp = response.body;

        // Ensure answer SDP also has proper formatting
        answerSdp = _formatSdpForCloudflare(answerSdp);

        developer.log('Received answer SDP');

        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        developer.log('✓ Remote description set successfully');

        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
        widget.onConnected?.call();
      } else {
        throw Exception(response.body);
      }
    } catch (e, stackTrace) {
      developer.log('Connection error:', error: e, stackTrace: stackTrace);
      _handleError('$e');
    }
  }

  Future<void> _connect() async {
    if (_isConnecting || _isConnected || widget.webRTCUrl.isEmpty) return;

    try {
      developer.log('=== Starting WebRTC Connection ===');
      developer.log('Target URL: ${widget.webRTCUrl}');

      setState(() {
        _isConnecting = true;
        _error = null;
      });

      // Cloudflare Stream optimized configuration
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      };

      developer.log('Creating peer connection...');
      _peerConnection = await createPeerConnection(configuration);
      developer.log('✓ Peer connection created');

      // Add audio transceiver only (audio-only stream)
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      developer.log('✓ Audio transceiver added');

      // Handle incoming tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        developer.log('✓ Track received: ${event.track?.kind}');
        if (event.streams.isNotEmpty) {
          developer.log(
            '✓ Stream received with ${event.streams.first.getTracks().length} tracks',
          );
          if (mounted) {
            setState(() {
              _renderer.srcObject = event.streams.first;
              _isConnected = true;
              _isConnecting = false;
            });
          }
          developer.log('✓ WebRTC connected successfully');
          widget.onConnected?.call();
        }
      };

      // Monitor connection states
      _peerConnection!.onIceConnectionState = (state) {
        developer.log('ICE connection state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          developer.log('✗ ICE connection failed or disconnected');
          _handleDisconnection();
        } else if (state ==
            RTCIceConnectionState.RTCIceConnectionStateConnected) {
          developer.log('✓ ICE connection established');
        }
      };

      _peerConnection!.onIceGatheringState = (state) {
        developer.log('ICE gathering state: $state');
      };

      _peerConnection!.onSignalingState = (state) {
        developer.log('Signaling state: $state');
      };

      // Create offer for receive-only connection
      final constraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
        'optional': [],
      };

      developer.log('Creating offer...');
      final offer = await _peerConnection!.createOffer(constraints);
      developer.log('✓ Offer created (type: ${offer.type})');

      await _peerConnection!.setLocalDescription(offer);
      developer.log('✓ Local description set');

      // Wait for ICE gathering to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Connect to Cloudflare Stream
      await _connectToCloudflareStream(offer);
    } catch (e, stackTrace) {
      developer.log('✗ Connection error:', error: e, stackTrace: stackTrace);
      _handleError('Failed to connect: $e');
    }
  }

  void _handleDisconnection() {
    if (mounted) {
      setState(() {
        _isConnected = false;
        _renderer.srcObject = null;
      });
      widget.onDisconnected?.call();
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
        _isConnecting = false;
        _isConnected = false;
      });
      widget.onError?.call(error);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _peerConnection?.close();
      _peerConnection = null;
      _renderer.srcObject = null;
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      widget.onDisconnected?.call();
    } catch (e) {
      developer.log('Error disconnecting: $e');
    }
  }

  Future<void> _reconnect() async {
    await _disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await _connect();
  }

  @override
  void dispose() {
    _disconnect();
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Initializing player...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Audio visualization UI
        if (_isConnected) _buildAudioPlayerUI(),

        // Connection status overlay
        if (_isConnected)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 10, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error overlay
        if (_error != null)
          Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Connection Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _reconnect,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reconnect',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Connecting overlay
        if (_isConnecting)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Connecting to stream...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioPlayerUI() {
    return Stack(
      children: [
        // Background gradient for audio player
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary.withOpacity(0.3), Colors.black],
            ),
          ),
        ),

        // Audio visualization
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated audio waves
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  widget.isMuted ? Icons.volume_off : Icons.graphic_eq,
                  color: widget.isMuted ? Colors.grey : AppColors.primary,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Audio Live Stream',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Listening...',
                style: TextStyle(
                  color: widget.isMuted ? Colors.grey : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Muted indicator
        if (widget.isMuted)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_off, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'MUTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
