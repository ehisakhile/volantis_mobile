import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reusable video player built on top of [Chewie] (which wraps
/// `video_player`). Provides forwarding (±10s), fullscreen, playback speed,
/// an error/loading state and an in-app picture-in-picture mode that keeps
/// playing in a draggable floating window while browsing the playlist.
class PlaylistVideoPlayer extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final bool autoPlay;

  /// Called once the underlying [VideoPlayerController] is ready so the
  /// caller can drive play/pause externally.
  final ValueChanged<VideoPlayerController>? onControllerCreated;
  final ValueChanged<VideoPlayerController>? onControllerDisposed;
  final ValueChanged<bool>? onPlayStateChanged;
  final ValueChanged<bool>? onPipChanged;
  final VoidCallback? onEnded;
  final ValueChanged<String>? onError;

  const PlaylistVideoPlayer({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.autoPlay = true,
    this.onControllerCreated,
    this.onControllerDisposed,
    this.onPlayStateChanged,
    this.onPipChanged,
    this.onEnded,
    this.onError,
  });

  @override
  State<PlaylistVideoPlayer> createState() => _PlaylistVideoPlayerState();
}

class _PlaylistVideoPlayerState extends State<PlaylistVideoPlayer> {
  static const _primary = Color(0xFF89CEFF);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _outlineVar = Color(0xFF3E4850);
  static const _onSurface = Color(0xFFDAE2FD);

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _initFailed = false;
  String? _errorMessage;
  bool _endedFired = false;

  bool _pipActive = false;
  OverlayEntry? _pipEntry;
  Offset _pipPosition = const Offset(16, 240);
  Size? _pipConstraints;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoController!.addListener(_onControllerListen);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _videoController!.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlay,
        looping: false,
        aspectRatio: 16 / 9,
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
        placeholder: widget.thumbnailUrl != null
            ? Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbnailFallback(),
              )
            : _thumbnailFallback(),
        errorBuilder: (_, errorMessage) => _buildError(errorMessage),
        additionalOptions: _buildAdditionalOptions,
      );

      widget.onControllerCreated?.call(_videoController!);
      setState(() {});
    } catch (e) {
      _initFailed = true;
      _errorMessage = e.toString();
      widget.onError?.call(_errorMessage!);
      if (mounted) setState(() {});
    }
  }

  void _onControllerListen() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    widget.onPlayStateChanged?.call(controller.value.isPlaying);

    if (controller.value.isCompleted) {
      if (!_endedFired) {
        _endedFired = true;
        widget.onEnded?.call();
      }
    } else {
      _endedFired = false;
    }
  }

  List<OptionItem> _buildAdditionalOptions(BuildContext context) {
    return [
      OptionItem(
        iconData: Icons.picture_in_picture_alt_rounded,
        title: _pipActive ? 'Exit picture-in-picture' : 'Picture-in-picture',
        onTap: (_) => _togglePip(),
      ),
    ];
  }

  // ── Picture-in-picture ───────────────────────────────────────────────

  void _togglePip() {
    if (_pipActive) {
      _exitPip();
    } else {
      _enterPip();
    }
  }

  void _enterPip() {
    if (_pipActive || _videoController == null) return;

    final overlay = Overlay.of(context);
    _pipConstraints = MediaQuery.sizeOf(context);
    _pipPosition = Offset(16, MediaQuery.sizeOf(context).height * 0.22);

    _pipEntry = OverlayEntry(builder: (_) => _buildPipWindow());
    _pipActive = true;
    overlay.insert(_pipEntry!);
    widget.onPipChanged?.call(true);
    setState(() {});
  }

  void _exitPip() {
    if (!_pipActive) return;
    _pipActive = false;
    if (_pipEntry != null && _pipEntry!.mounted) {
      _pipEntry!.remove();
    }
    _pipEntry = null;
    widget.onPipChanged?.call(false);
    if (mounted) setState(() {});
  }

  Widget _buildPipWindow() {
    const width = 200.0;
    final screen = _pipConstraints ?? MediaQuery.sizeOf(context);
    final dx = _pipPosition.dx.clamp(0.0, screen.width - width - 8.0);

    return Positioned(
      left: dx,
      top: _pipPosition.dy.clamp(8.0, screen.height - 200),
      width: width,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _pipPosition += details.delta;
            });
            _pipEntry?.markNeedsBuild();
          },
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
                  onTap: _exitPip,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(_videoController!),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: _PipIconBtn(
                            icon: Icons.open_in_full_rounded,
                            tooltip: 'Restore player',
                            onTap: _exitPip,
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
                      _PipIconBtn(
                        icon: Icons.play_circle_fill_rounded,
                        tooltip: 'Play',
                        onTap: () {
                          _videoController?.play();
                        },
                      ),
                      _PipIconBtn(
                        icon: Icons.pause_circle_filled_rounded,
                        tooltip: 'Pause',
                        onTap: () {
                          _videoController?.pause();
                        },
                      ),
                      const Spacer(),
                      _PipIconBtn(
                        icon: Icons.close_rounded,
                        tooltip: 'Close video',
                        onTap: () {
                          _exitPip();
                          widget.onEnded?.call();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVar.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.picture_in_picture_alt_rounded,
            color: _primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Playing in picture-in-picture',
              style: TextStyle(color: _onSurface, fontSize: 13),
            ),
          ),
          _PipIconBtn(
            icon: Icons.expand_rounded,
            tooltip: 'Restore player',
            onTap: _exitPip,
          ),
        ],
      ),
    );
  }

  // ── Main player UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return _buildError(_errorMessage ?? 'Unable to load video');
    }

    if (_pipActive) return _buildPipBar();

    if (_chewieController == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: widget.thumbnailUrl != null
            ? Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbnailFallback(),
              )
            : _thumbnailFallback(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      color: const Color(0xFF171F33),
      child: const Center(child: CircularProgressIndicator(color: _primary)),
    );
  }

  Widget _buildError(String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF171F33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Video could not be loaded',
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: _outlineVar, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exitPip();
    _chewieController?.dispose();
    _chewieController = null;
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_onControllerListen);
      widget.onControllerDisposed?.call(controller);
      controller.dispose();
    }
    _videoController = null;
    super.dispose();
  }
}

class _PipIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _PipIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
