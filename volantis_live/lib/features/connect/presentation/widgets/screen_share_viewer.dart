import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Renders a screen-share track with full viewer control:
/// - Pinch-to-zoom and pan (via [InteractiveViewer])
/// - Rotate in 90° steps (a phone share often arrives sideways)
/// - Toggle "fit" (whole share visible, letterboxed) vs "fill" (crops to
///   fill the tile) - useful since a share can be 16:9 or 9:16
/// - Expand to fullscreen / collapse back
///
/// Controls fade in on tap and auto-hide after a few seconds, like a
/// video player, so they don't obstruct the shared content.
class ScreenShareViewer extends StatefulWidget {
  final VideoTrack track;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const ScreenShareViewer({
    super.key,
    required this.track,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  @override
  State<ScreenShareViewer> createState() => _ScreenShareViewerState();
}

class _ScreenShareViewerState extends State<ScreenShareViewer> {
  final TransformationController _transformController =
      TransformationController();

  int _quarterTurns = 0; // 0..3, each step = 90° clockwise
  VideoViewFit _fit = VideoViewFit.contain;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _rotate() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
    _resetZoomSilently();
    _showControls();
  }

  void _toggleFit() {
    setState(() {
      _fit = _fit == VideoViewFit.contain
          ? VideoViewFit.cover
          : VideoViewFit.contain;
    });
    _showControls();
  }

  void _resetZoomSilently() {
    _transformController.value = Matrix4.identity();
  }

  void _resetZoom() {
    _resetZoomSilently();
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showControls,
      onDoubleTap: _resetZoom,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1,
                maxScale: 5,
                child: SizedBox.expand(
                  // RotatedBox rotates layout as well as painting, so an
                  // odd quarterTurn correctly swaps width/height - a 9:16
                  // phone share rotated 90° lays out like a 16:9 tile.
                  child: RotatedBox(
                    quarterTurns: _quarterTurns,
                    child: VideoTrackRenderer(widget.track, fit: _fit),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _buildControlsOverlay(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconButton(
                icon: Icons.rotate_90_degrees_cw_rounded,
                tooltip: 'Rotate',
                onPressed: _rotate,
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: _fit == VideoViewFit.contain
                    ? Icons.fit_screen_rounded
                    : Icons.crop_free_rounded,
                tooltip: _fit == VideoViewFit.contain
                    ? 'Fill screen'
                    : 'Fit screen',
                onPressed: _toggleFit,
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: Icons.center_focus_weak_rounded,
                tooltip: 'Reset zoom',
                onPressed: _resetZoom,
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: widget.isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: widget.isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                onPressed: widget.onToggleFullscreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
