import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../services/audio_manager.dart';
import '../../../../services/live_stream_service.dart';
import '../../../../services/share_service.dart';
import '../../data/models/company_live_stream_model.dart';
import '../../../chat/presentation/widgets/live_chat_widget.dart';
import '../providers/streams_provider.dart';

class FullScreenPlayerSheet extends StatefulWidget {
  const FullScreenPlayerSheet({super.key});

  @override
  State<FullScreenPlayerSheet> createState() => _FullScreenPlayerSheetState();
}

class _FullScreenPlayerSheetState extends State<FullScreenPlayerSheet>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF060E20);
  static const _primary = Color(0xFF89CEFF);
  static const _secondary = Color(0xFFD2BBFF);
  static const _tertiary = Color(0xFFFFB3AD);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);

  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;

  static const int _barCount = 30;
  final List<double> _barSeeds = List.generate(
    _barCount,
    (i) => (i * 0.7 + 0.3),
  );

  bool _showChat = false;
  StreamSubscription? _liveStreamStateSubscription;
  StreamSubscription? _audioStateSubscription;

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

    _liveStreamStateSubscription = LiveStreamService.instance.stateStream.listen(_onStateChanged);
    _audioStateSubscription = AudioManager.instance.stateStream.listen(_onAudioStateChanged);
  }

  void _onStateChanged(LiveStreamState state) {
    if (!mounted) return;
    setState(() {});
  }

  void _onAudioStateChanged(AudioState state) {
    debugPrint('[FullScreenPlayerSheet] AudioState changed: ${state.sourceType}, isPlaying: ${state.isPlaying}');
    if (!mounted) return;
    
    if (state.sourceType == AudioSourceType.none || 
        (state.sourceType == AudioSourceType.liveStream && !state.isPlaying && !state.isConnecting)) {
      debugPrint('[FullScreenPlayerSheet] Stream stopped, closing player');
      Navigator.of(context).maybePop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _liveStreamStateSubscription?.cancel();
    _audioStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _shareStream(StreamsProvider provider) async {
    final stream = provider.currentStream;
    if (stream != null) {
      ShareService().shareStream(
        streamSlug: stream.slug,
        companySlug: stream.companySlug,
        streamTitle: stream.title,
        companyName: stream.companyName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlayerOpen || provider.currentStream == null) {
          return const SizedBox.shrink();
        }

        final stream = provider.currentStream!;
        final livestreamService = LiveStreamService.instance;

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _onVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      onPressed: () {
                        provider.minimize();
                        Navigator.of(context).pop();
                      },
                    ),
                    _buildConnectionBadge(livestreamService.isWebRTCConnected),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () => ShareService().shareStreamWithSharePlus(
                            companySlug: stream.companySlug,
                            streamSlug: stream.slug,
                            streamTitle: stream.title,
                            companyName: stream.companyName,
                          ),
                        ),
                        IconButton(
                          icon: Icon(_showChat ? Icons.chat_bubble : Icons.chat_bubble_outline,
                              color: _showChat ? const Color(0xFF38BDF8) : Colors.white),
                          onPressed: () {
                            setState(() => _showChat = !_showChat);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _showChat
                    ? _buildChatView(stream, provider)
                    : _buildPlayerView(stream, provider, livestreamService),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return Consumer<StreamsProvider>(
      builder: (context, provider, _) {
        Color badgeColor;
        String badgeText;

        if (isConnected || provider.isPlaying) {
          badgeColor = Colors.green;
          badgeText = 'CONNECTED';
        } else if (provider.isConnecting) {
          badgeColor = Colors.orange;
          badgeText = 'CONNECTING';
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
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatView(dynamic stream, StreamsProvider provider) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showChat = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.4),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
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
                  child: ClipOval(
                    child: stream.companyLogoUrl != null
                        ? CachedNetworkImage(imageUrl: stream.companyLogoUrl!, fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(Icons.live_tv, color: _primary),
                            errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: _primary))
                        : const Icon(Icons.live_tv, color: _primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stream.companyName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Icon(Icons.visibility, color: _onVariant, size: 12),
                          const SizedBox(width: 2),
                          Text('${stream.totalViews}', style: TextStyle(color: _onVariant, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LiveChatWidget(slug: stream.slug, isCreator: provider.currentStream?.companySlug == stream.companySlug, companyName: stream.companyName),
        ),
      ],
    );
  }

  Widget _buildPlayerView(dynamic stream, StreamsProvider provider, LiveStreamService livestreamService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildAvatar(stream, provider.isPlaying),
          const SizedBox(height: 20),
          Text(stream.companyName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(stream.title, style: const TextStyle(color: _onVariant, fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _buildWaveform(),
          const SizedBox(height: 32),
          _buildStreamInfo(stream, provider),
          const SizedBox(height: 48),
          _buildControls(provider, livestreamService),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAvatar(dynamic stream, bool isConnected) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = _pulseCtrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96 + pulse * 8,
              height: 96 + pulse * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isConnected ? _tertiary.withOpacity(0.35 * (1 - pulse)) : Colors.grey.withOpacity(0.2),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _tertiary.withOpacity(0.7), width: 2)),
              child: ClipOval(
                child: stream.companyLogoUrl != null
                    ? CachedNetworkImage(imageUrl: stream.companyLogoUrl!, fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(Icons.live_tv, color: _primary),
                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: _primary))
                    : const Icon(Icons.live_tv, color: _primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreamInfo(dynamic stream, StreamsProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Colors.white, size: 6),
              SizedBox(width: 4),
              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.visibility, color: _onVariant, size: 16),
        const SizedBox(width: 4),
        Text('${provider.currentTotalViews > 0 ? provider.currentTotalViews : stream.totalViews} views', style: TextStyle(color: _onVariant, fontSize: 14)),
      ],
    );
  }

  Widget _buildWaveform() {
    return Consumer<StreamsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlaying && !provider.isConnecting) {
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
                  final height = 20 + 30 * (0.5 + 0.5 * math.sin(phase + barSeed * 2 * math.pi));
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 4,
                    height: height,
                    decoration: BoxDecoration(color: _primary.withOpacity(0.6), borderRadius: BorderRadius.circular(2)),
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildControls(StreamsProvider provider, LiveStreamService livestreamService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: provider.isMuted ? Icons.volume_off : Icons.volume_up,
          label: provider.isMuted ? 'Unmute' : 'Mute',
          onTap: () {
            livestreamService.toggleMute();
            provider.toggleMute();
          },
        ),
        const SizedBox(width: 24),
        _ControlButton(
          icon: Icons.close,
          label: 'Stop',
          onTap: () {
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

  const _ControlButton({required this.icon, required this.label, required this.onTap});

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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}