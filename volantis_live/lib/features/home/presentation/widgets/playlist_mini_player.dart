import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../data/models/playlist_model.dart';
import '../providers/playlist_provider.dart';
import 'package:volantis_live/services/audio_manager.dart';

/// Global mini player for playlist playback. Mounted above the root navigator
/// so it stays visible after leaving the playlist screen: audio shows a compact
/// bar, video shows a draggable picture-in-picture window. Tapping it jumps
/// back to the full playlist player screen.
class PlaylistMiniPlayer extends StatelessWidget {
  final GoRouter router;

  const PlaylistMiniPlayer({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistPlayerProvider>(
      builder: (context, provider, _) {
        if (!provider.showMiniPlayer) return const SizedBox.shrink();

        final item = provider.currentItem;
        if (item == null) return const SizedBox.shrink();

        if (item.isVideo) {
          final controller = provider.videoController;
          if (controller == null || !controller.value.isInitialized) {
            return const SizedBox.shrink();
          }
          return _VideoMiniWindow(
            controller: controller,
            title: item.title,
            onRestore: () => _restore(provider),
            onClose: () => provider.closePlayer(),
          );
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _AudioMiniBar(
              provider: provider,
              item: item,
              onRestore: () => _restore(provider),
              onClose: () => provider.closePlayer(),
            ),
          ),
        );
      },
    );
  }

  void _restore(PlaylistPlayerProvider provider) {
    final companySlug = provider.companySlug;
    final playlistId = provider.playlistId;
    if (companySlug == null || playlistId == null) return;
    router.push('/company/$companySlug/playlist/$playlistId');
  }
}

// ── Draggable video picture-in-picture window ─────────────────────────────────

class _VideoMiniWindow extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  const _VideoMiniWindow({
    required this.controller,
    required this.title,
    required this.onRestore,
    required this.onClose,
  });

  @override
  State<_VideoMiniWindow> createState() => _VideoMiniWindowState();
}

class _VideoMiniWindowState extends State<_VideoMiniWindow> {
  static const _outlineVar = Color(0xFF3E4850);

  static const double _width = 200;
  static const double _aspect = 16 / 9;

  Offset _position = const Offset(16, 240);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final height = _width / _aspect;
        final left = _position.dx.clamp(0.0, screen.width - _width - 8.0);
        final top = _position.dy.clamp(8.0, screen.height - height - 140.0);

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: _width,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() => _position += details.delta);
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1326),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outlineVar, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: widget.onRestore,
                          child: AspectRatio(
                            aspectRatio: _aspect,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(widget.controller),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.open_in_full_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              _iconBtn(
                                Icons.play_arrow_rounded,
                                'Play',
                                () => widget.controller.play(),
                              ),
                              _iconBtn(
                                Icons.pause_rounded,
                                'Pause',
                                () => widget.controller.pause(),
                              ),
                              const Spacer(),
                              _iconBtn(
                                Icons.close_rounded,
                                'Close player',
                                widget.onClose,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Audio mini bar ─────────────────────────────────────────────────────────────

class _AudioMiniBar extends StatelessWidget {
  final PlaylistPlayerProvider provider;
  final PlaylistItemModel item;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  const _AudioMiniBar({
    required this.provider,
    required this.item,
    required this.onRestore,
    required this.onClose,
  });

  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _surface = Color(0xFF060E20);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioState>(
      stream: AudioManager.instance.stateStream,
      initialData: AudioManager.instance.currentState,
      builder: (context, snap) {
        final state = snap.data ?? const AudioState();
        final isPlaying =
            state.sourceType == AudioSourceType.recording && state.isPlaying;
        final isLoading =
            state.sourceType == AudioSourceType.recording &&
                state.isConnecting;

        return GestureDetector(
          onTap: onRestore,
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _progressLine(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(
                    children: [
                      _thumbnail(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to return to playlist',
                              style: TextStyle(
                                color: _onVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _playPause(isPlaying: isPlaying, isLoading: isLoading),
                      _closeButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _progressLine() {
    return StreamBuilder<Duration?>(
      stream: AudioManager.instance.positionStream,
      builder: (_, posSnap) {
        final pos = posSnap.data?.inMilliseconds.toDouble() ?? 0;
        final durMs =
            AudioManager.instance.duration?.inMilliseconds.toDouble() ??
                (item.durationSeconds != null
                    ? (item.durationSeconds! * 1000).toDouble()
                    : 1.0);
        final progress = (pos / durMs).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (_, constraints) {
            return Stack(
              children: [
                Container(height: 2, color: _surfaceHigh),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: constraints.maxWidth * progress,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _primaryCont],
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

  Widget _thumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: item.thumbnailUrl != null
          ? CachedNetworkImage(
              imageUrl: item.thumbnailUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.audiotrack_rounded, color: _primary, size: 20),
    );
  }

  Widget _playPause({required bool isPlaying, required bool isLoading}) {
    return GestureDetector(
      onTap: () => provider.togglePlayPause(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _primaryCont],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: _onPrimary,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _onPrimary,
                  size: 20,
                ),
        ),
      ),
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.close_rounded, color: _onVariant, size: 18),
      ),
    );
  }
}
