import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/recordings_provider.dart';
import 'full_screen_player_sheet.dart';

/// Mini player bar — VolantisLive dark glass design
/// Shown at the bottom when the player is minimized.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  // ── Design tokens ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060E20);
  static const _glassCard = Color(0xFF131B2E);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlayerOpen || provider.currentRecording == null) {
          return const SizedBox.shrink();
        }

        final recording = provider.currentRecording!;

        return GestureDetector(
          onTap: () {
            provider.expand();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const FullScreenPlayerSheet(),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: _bg,
              border: const Border(
                top: BorderSide(color: Color(0xFF1A2540), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Progress line ───────────────────────────────────────
                _ProgressLine(provider: provider),

                // ── Content row ─────────────────────────────────────────
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    child: Row(
                      children: [
                        // Thumbnail
                        _MiniThumbnail(
                          url: recording.hasThumbnail
                              ? recording.thumbnailUrl
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // Title + position
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                recording.title,
                                style: const TextStyle(
                                  color: _onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _PositionLabel(provider: provider),
                            ],
                          ),
                        ),

                        // Controls
                        _MiniControls(provider: provider),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Thin progress line ────────────────────────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  final RecordingsProvider provider;

  const _ProgressLine({required this.provider});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: provider.positionStream,
      builder: (_, snap) {
        final pos = snap.data?.inMilliseconds.toDouble() ?? 0;
        final dur = provider.duration?.inMilliseconds.toDouble() ?? 1;
        final progress = (pos / dur).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (_, constraints) {
            return Stack(
              children: [
                Container(height: 2, color: const Color(0xFF222A3D)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: constraints.maxWidth * progress,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF89CEFF), Color(0xFF0EA5E9)],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Mini thumbnail ────────────────────────────────────────────────────────────

class _MiniThumbnail extends StatelessWidget {
  final String? url;

  const _MiniThumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF222A3D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.mic_rounded, color: Color(0xFF89CEFF), size: 22),
    );
  }
}

// ── Position label ────────────────────────────────────────────────────────────

class _PositionLabel extends StatelessWidget {
  final RecordingsProvider provider;

  const _PositionLabel({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20).withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Completed',
          style: TextStyle(
            color: Color(0xFF66BB6A),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: provider.positionStream,
      builder: (_, snap) {
        final pos = snap.data ?? Duration.zero;
        return Text(
          _fmt(pos),
          style: const TextStyle(
            color: Color(0xFFBEC8D2),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Mini controls row ─────────────────────────────────────────────────────────

class _MiniControls extends StatelessWidget {
  final RecordingsProvider provider;

  const _MiniControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skip back
        _CtrlBtn(
          icon: Icons.replay_10_rounded,
          onTap: () => provider.skipBack(10),
          size: 20,
        ),

        const SizedBox(width: 4),

        // Play / Pause — gradient circle
        StreamBuilder<PlayerState>(
          stream: provider.playerStateStream,
          builder: (_, snap) {
            final playing = snap.data?.playing ?? false;
            return GestureDetector(
              onTap: () => provider.togglePlayPause(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF89CEFF), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF89CEFF).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: const Color(0xFF00344D),
                  size: 22,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 4),

        // Skip forward
        _CtrlBtn(
          icon: Icons.forward_10_rounded,
          onTap: () => provider.skipForward(10),
          size: 20,
        ),

        const SizedBox(width: 4),

        // Close
        _CtrlBtn(
          icon: Icons.close_rounded,
          onTap: () => provider.closePlayer(),
          size: 18,
        ),
      ],
    );
  }
}

// ── Small control button ──────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CtrlBtn({required this.icon, required this.onTap, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFBEC8D2), size: size),
      ),
    );
  }
}
