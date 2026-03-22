import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../services/live_stream_service.dart';
import '../../data/models/company_live_stream_model.dart';
import '../../../chat/presentation/widgets/live_chat_widget.dart';
import '../providers/streams_provider.dart';

/// Full-screen player bottom sheet for live streams
/// Uses bottom sheet pattern like the recordings player for easy minimizing
/// Implements WebRTC audio streaming
class FullScreenPlayerSheet extends StatefulWidget {
  const FullScreenPlayerSheet({super.key});

  @override
  State<FullScreenPlayerSheet> createState() => _FullScreenPlayerSheetState();
}

class _FullScreenPlayerSheetState extends State<FullScreenPlayerSheet>
    with TickerProviderStateMixin {
  // Design tokens
  static const _bg = Color(0xFF060E20);
  static const _primary = Color(0xFF89CEFF);
  static const _secondary = Color(0xFFD2BBFF);
  static const _tertiary = Color(0xFFFFB3AD);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);

  // Animations
  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;

  static const int _barCount = 30;
  final List<double> _barSeeds = List.generate(
    _barCount,
    (i) => (i * 0.7 + 0.3),
  );

  // WebRTC state
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  String? _playbackUrl;
  CompanyLiveStream? _streamDetails;

  // WebRTC components
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  bool _isWebRTCInitialized = false;

  // Audio track for muting
  MediaStreamTrack? _audioTrack;

  // Flag to track if we're fully closing vs minimizing
  bool _isClosing = false;

  // Chat visibility
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Register WebRTC callbacks with LiveStreamService
    LiveStreamService.instance.setWebRTCCleanupCallback(_cleanupWebRTC);
    LiveStreamService.instance.setWebRTCStateCallback(_onWebRTCStateChanged);

    // Sync with existing WebRTC state if already connected
    _syncFromService();

    _initializeWebRTC();
  }

  /// Sync local state with LiveStreamService state
  void _syncFromService() {
    final service = LiveStreamService.instance;
    if (service.isWebRTCConnected || service.isWebRTCConnecting) {
      setState(() {
        _isConnected = service.isWebRTCConnected;
        _isConnecting = service.isWebRTCConnecting;
        _error = service.webRTCError;
        _audioTrack = service.audioTrack;
      });
    }
  }

  /// Callback for WebRTC state changes from service
  void _onWebRTCStateChanged(
    bool isConnected,
    bool isConnecting,
    String? error,
  ) {
    if (!mounted) return;
    setState(() {
      _isConnected = isConnected;
      _isConnecting = isConnecting;
      _error = error;
    });
  }

  Future<void> _initializeWebRTC() async {
    try {
      final provider = context.read<StreamsProvider>();

      // Get stream details
      final details = await provider.getCompanyLiveStream(
        provider.currentStream!.companySlug,
      );

      if (!mounted) return;

      if (details == null) {
        throw Exception('Stream not found');
      }

      if (details.livestream.webrtcPlaybackUrl == null) {
        throw Exception('No playback URL available');
      }

      setState(() {
        _streamDetails = details;
        _playbackUrl = details.livestream.webrtcPlaybackUrl;
        _isLoading = false;
      });

      // Initialize WebRTC renderer
      await _renderer.initialize();
      setState(() => _isWebRTCInitialized = true);

      // Connect to WebRTC stream
      if (_playbackUrl != null && _playbackUrl!.isNotEmpty) {
        await _connectToStream();
      }
    } catch (e) {
      developer.log('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Properly format SDP for Cloudflare Stream
  String _formatSdpForCloudflare(String sdp) {
    developer.log('Original SDP length: ${sdp.length}');
    var lines = sdp.split(RegExp(r'\r?\n'));
    lines = lines.where((line) => line.trim().isNotEmpty).toList();
    var formattedSdp = lines.join('\r\n');
    if (!formattedSdp.endsWith('\r\n')) {
      formattedSdp += '\r\n';
    }
    developer.log('Formatted SDP length: ${formattedSdp.length}');
    return formattedSdp;
  }

  /// Optimize SDP for Cloudflare Stream compatibility
  String _optimizeSdpForCloudflare(String sdp) {
    var lines = sdp.split(RegExp(r'\r?\n'));
    var optimizedLines = <String>[];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('v=') ||
          trimmed.startsWith('o=') ||
          trimmed.startsWith('s=') ||
          trimmed.startsWith('t=') ||
          trimmed.startsWith('m=') ||
          trimmed.startsWith('c=') ||
          trimmed.startsWith('a=')) {
        if (trimmed == 'a=bundle-only') continue;

        if (trimmed.startsWith('m=video') || trimmed.startsWith('m=audio')) {
          optimizedLines.add(trimmed);
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

  Future<void> _connectToStream() async {
    if (_isConnecting ||
        _isConnected ||
        _playbackUrl == null ||
        _playbackUrl!.isEmpty)
      return;

    try {
      developer.log('=== Starting WebRTC Connection ===');
      developer.log('Target URL: $_playbackUrl');

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

        // Capture audio track for muting
        if (event.track?.kind == 'audio') {
          _audioTrack = event.track;
          developer.log('✓ Audio track captured for muting control');

          // Apply current mute state to the track
          final provider = context.read<StreamsProvider>();
          if (provider.isMuted && event.track != null) {
            event.track!.enabled = false;
            developer.log('✓ Applied mute state to new track');
          }
        }

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
            // Update service state
            LiveStreamService.instance.updateWebRTCState(
              isConnected: true,
              isConnecting: false,
              audioTrack: _audioTrack,
            );
          }
          developer.log('✓ WebRTC connected successfully');
        }
      };

      // Monitor connection states
      _peerConnection!.onIceConnectionState = (state) {
        developer.log('ICE connection state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          developer.log('✗ ICE connection failed or disconnected');
          if (mounted) {
            setState(() {
              _isConnected = false;
              _renderer.srcObject = null;
            });
          }
        } else if (state ==
            RTCIceConnectionState.RTCIceConnectionStateConnected) {
          developer.log('✓ ICE connection established');
        }
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
      if (mounted) {
        setState(() {
          _error = 'Failed to connect: $e';
          _isConnecting = false;
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _connectToCloudflareStream(RTCSessionDescription offer) async {
    try {
      developer.log('=== Connecting to Cloudflare Stream ===');
      developer.log('URL: $_playbackUrl');

      var sdpToSend = _formatSdpForCloudflare(offer.sdp ?? '');
      sdpToSend = _optimizeSdpForCloudflare(sdpToSend);

      developer.log('Final SDP being sent (length: ${sdpToSend.length})');

      final response = await http.post(
        Uri.parse(_playbackUrl!),
        headers: {
          'Content-Type': 'application/sdp',
          'Accept': 'application/sdp',
        },
        body: sdpToSend,
      );

      developer.log('Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        var answerSdp = _formatSdpForCloudflare(response.body);
        developer.log('Received answer SDP');

        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        developer.log('✓ Remote description set successfully');

        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isConnected = true;
          });
        }
      } else {
        throw Exception(response.body);
      }
    } catch (e, stackTrace) {
      developer.log('Connection error:', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _error = '$e';
          _isConnecting = false;
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _reconnect() async {
    await _disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await _connectToStream();
  }

  /// Cleanup callback for LiveStreamService - used when switching streams or stopping
  Future<void> _cleanupWebRTC() async {
    developer.log('WebRTC cleanup callback triggered');
    await _disconnect();
  }

  /// Set audio track enabled/disabled for mute functionality
  /// Uses both local track and service for persistence
  void _setAudioTrackEnabled(bool enabled) {
    // Update local track if available
    if (_audioTrack != null) {
      _audioTrack!.enabled = enabled;
      developer.log('Audio track ${enabled ? 'unmuted' : 'muted'} locally');
    }
    // Also update service for persistence across widget lifecycle
    LiveStreamService.instance.setAudioTrackEnabled(enabled);
  }

  /// Disconnect WebRTC - optionally clear service state
  /// [clearServiceState] should be false when minimizing (keep WebRTC in service)
  /// and true when fully stopping the stream
  Future<void> _disconnect({bool clearServiceState = true}) async {
    try {
      await _peerConnection?.close();
      _peerConnection = null;
      _audioTrack = null;
      _renderer.srcObject = null;
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
      }
      // Clear service state if requested (i.e., when fully stopping)
      if (clearServiceState) {
        LiveStreamService.instance.updateWebRTCState(
          isConnected: false,
          isConnecting: false,
          error: null,
        );
      }
    } catch (e) {
      developer.log('Error disconnecting: $e');
    }
  }

  @override
  void dispose() {
    // Only disconnect WebRTC when fully closing (not minimizing)
    // When minimizing, the WebRTC continues running in the service
    if (_isClosing) {
      LiveStreamService.instance.setWebRTCCleanupCallback(null);
      LiveStreamService.instance.setWebRTCStateCallback(null);
      _disconnect(clearServiceState: true);
    }
    _renderer.dispose();
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlayerOpen || provider.currentStream == null) {
          return const SizedBox.shrink();
        }

        final stream = provider.currentStream!;
        final theme = Theme.of(context);

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _onVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        provider.minimize();
                        Navigator.of(context).pop();
                      },
                    ),
                    _buildConnectionBadge(),
                    IconButton(
                      icon: Icon(
                        _showChat ? Icons.chat_bubble : Icons.chat_bubble_outline,
                        color: _showChat ? const Color(0xFF38BDF8) : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _showChat = !_showChat;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _showChat
                    ? Column(
                        children: [
                          // Mini player header when in chat-only mode
                          GestureDetector(
                            onTap: () => setState(() => _showChat = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withOpacity(0.4),
                                border: Border(
                                  bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF222A3D),
                                      border: Border.all(color: const Color(0xFF060E20), width: 2),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: stream.companyLogoUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: stream.companyLogoUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const Icon(Icons.live_tv, color: _primary),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(Icons.live_tv, color: _primary),
                                          )
                                        : const Icon(Icons.live_tv, color: _primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stream.companyName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'LIVE',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.visibility, color: _onVariant, size: 12),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${stream.viewerCount}',
                                              style: TextStyle(color: _onVariant, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Full screen chat
                          Expanded(
                            child: LiveChatWidget(
                              slug: stream.slug,
                              isCreator: provider.currentStream?.companySlug == stream.companySlug,
                              companyName: stream.companyName,
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            _buildAvatar(stream, provider),
                            const SizedBox(height: 20),
                            Text(
                              stream.companyName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stream.title,
                              style: const TextStyle(
                                color: _onVariant,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            _buildWaveform(),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        color: Colors.white,
                                        size: 6,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.visibility, color: _onVariant, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${stream.viewerCount} watching',
                                  style: TextStyle(color: _onVariant, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                            _buildControls(provider),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionBadge() {
    Color badgeColor;
    String badgeText;

    if (_isConnected) {
      badgeColor = Colors.green;
      badgeText = 'CONNECTED';
    } else if (_isConnecting) {
      badgeColor = Colors.orange;
      badgeText = 'CONNECTING';
    } else if (_error != null) {
      badgeColor = Colors.red;
      badgeText = 'ERROR';
    } else {
      badgeColor = Colors.grey;
      badgeText = 'DISCONNECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(dynamic stream, StreamsProvider provider) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = _pulseCtrl.value;
        final isConnected = _isConnected;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ping ring
            Container(
              width: 96 + pulse * 8,
              height: 96 + pulse * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isConnected
                      ? _tertiary.withOpacity(0.35 * (1 - pulse))
                      : Colors.grey.withOpacity(0.2),
                  width: 2,
                ),
              ),
            ),
            // Static ring
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _tertiary.withOpacity(0.7), width: 2),
              ),
            ),
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222A3D),
                border: Border.all(color: const Color(0xFF060E20), width: 3),
              ),
              clipBehavior: Clip.hardEdge,
              child: stream.companyLogoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: stream.companyLogoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const Icon(Icons.live_tv, color: _primary),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.live_tv, color: _primary),
                    )
                  : const Icon(Icons.live_tv, color: _primary),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaveform() {
    // Only show waveform when connected
    if (!_isConnected) {
      if (_isConnecting) {
        return Column(
          children: [
            SizedBox(
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 4,
                    height: 20 + (i % 3) * 15.0,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connecting to stream...',
              style: TextStyle(color: _onVariant, fontSize: 14),
            ),
          ],
        );
      }
      return const SizedBox(height: 80);
    }

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          return AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) {
              final phase = _waveCtrl.value * 2 * math.pi;
              final barSeed = _barSeeds[i];
              final height =
                  20 +
                  30 * (0.5 + 0.5 * math.sin(phase + barSeed * 2 * math.pi));
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildControls(StreamsProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mute button
        _ControlButton(
          icon: provider.isMuted ? Icons.volume_off : Icons.volume_up,
          label: provider.isMuted ? 'Unmute' : 'Mute',
          onTap: () {
            provider.toggleMute();
            // Apply mute state to WebRTC audio track
            _setAudioTrackEnabled(!provider.isMuted);
          },
        ),
        const SizedBox(width: 24),
        // // Play/Pause button
        // GestureDetector(
        //   onTap: () {
        //     if (_isConnected) {
        //       provider.togglePlayPause();
        //     } else if (!_isConnecting && _error == null) {
        //       _connectToStream();
        //     } else if (_error != null) {
        //       _reconnect();
        //     }
        //   },
        //   child: Container(
        //     width: 72,
        //     height: 72,
        //     decoration: BoxDecoration(
        //       color: _primary,
        //       shape: BoxShape.circle,
        //       boxShadow: [
        //         BoxShadow(
        //           color: _primary.withOpacity(0.4),
        //           blurRadius: 20,
        //           spreadRadius: 2,
        //         ),
        //       ],
        //     ),
        //     child: Icon(
        //       _isConnected
        //           ? (provider.isPlaying ? Icons.pause : Icons.play_arrow)
        //           : (_error != null ? Icons.refresh : Icons.play_arrow),
        //       color: _bg,
        //       size: 40,
        //     ),
        //   ),
        // ),
        // const SizedBox(width: 24),
        // Close button
        _ControlButton(
          icon: Icons.close,
          label: 'Stop',
          onTap: () {
            // Set closing flag before pop (which triggers dispose)
            _isClosing = true;
            // closePlayer() will call stopStream() which triggers the cleanup callback
            // which calls _disconnect(), so we don't need to call it directly
            provider.closePlayer();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
