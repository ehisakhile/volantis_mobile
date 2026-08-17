import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Renders a [VideoPlayerController] (owned by `PlaylistPlayerProvider`) inside
/// a [Chewie] player with forwarding (±10s), fullscreen, playback speed and
/// proper aspect-ratio handling. Because the controller is owned outside this
/// widget, playback continues when the widget (and its screen) is disposed —
/// the global mini player keeps rendering the same controller.
class PlaylistVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String? thumbnailUrl;
  final bool autoPlay;

  const PlaylistVideoPlayer({
    super.key,
    required this.controller,
    this.thumbnailUrl,
    this.autoPlay = true,
  });

  @override
  State<PlaylistVideoPlayer> createState() => _PlaylistVideoPlayerState();
}

class _PlaylistVideoPlayerState extends State<PlaylistVideoPlayer> {
  static const _primary = Color(0xFF89CEFF);
  static const _surface = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _outlineVar = Color(0xFF3E4850);
  static const _onSurface = Color(0xFFDAE2FD);

  ChewieController? _chewieController;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(PlaylistVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach();
    }
  }

  void _attach() {
    _chewieController = ChewieController(
      videoPlayerController: widget.controller,
      autoPlay: widget.autoPlay,
      looping: false,
      aspectRatio: _aspectRatio(),
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: _primary,
        handleColor: _primary,
        bufferedColor: _outlineVar,
        backgroundColor: _surfaceHigh,
      ),
      // CRITICAL: Remove placeholder to prevent thumbnail obstruction
      placeholder: null,
    );
  }

  void _detach() {
    _chewieController?.dispose();
    _chewieController = null;
  }

  /// Use the real video aspect ratio (so a 9:16 clip isn't letterboxed into a
  /// 16:9 frame that can look like "audio only"), falling back to 16:9 before
  /// the controller reports a usable size.
  double _aspectRatio() {
    final value = widget.controller.value;
    final ratio = value.isInitialized ? value.aspectRatio : 16 / 9;
    return (ratio.isFinite && ratio > 0) ? ratio : 16 / 9;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = widget.controller.value.isInitialized;

    return AspectRatio(
      aspectRatio: _aspectRatio(),
      child: Container(
        color: Colors.black,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player - always show when initialized
              if (isInitialized && _chewieController != null)
                Chewie(controller: _chewieController!),

              // Thumbnail overlay - only before video is loaded AND not in fullscreen
              if (!isInitialized && !_isFullScreen)
                Container(
                  color: Colors.black,
                  child: widget.thumbnailUrl != null
                      ? Image.network(
                          widget.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _loading(),
                        )
                      : _loading(),
                ),

              // Loading indicator while buffering
              if (isInitialized &&
                  _chewieController != null &&
                  _chewieController!.videoPlayerController.value.isBuffering &&
                  !_isFullScreen)
                _loading(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading() {
    return Container(
      color: _surface.withOpacity(0.8),
      child: const Center(child: CircularProgressIndicator(color: _primary)),
    );
  }
}
