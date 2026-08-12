import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../connect_colors.dart';
import 'menu_options_dialog.dart';
import 'hand_raise_button.dart';
import 'reaction_picker.dart';

/// Control bar with mic, camera, screen share, menu, and leave buttons
class ControlBar extends StatefulWidget {
  final bool isMicEnabled;
  final bool isCameraEnabled;
  final bool isScreenSharing;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onLeave;
  final Room? room;

  const ControlBar({
    super.key,
    required this.isMicEnabled,
    required this.isCameraEnabled,
    required this.isScreenSharing,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onFlipCamera,
    required this.onToggleScreenShare,
    required this.onLeave,
    this.room,
  });

  @override
  State<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<ControlBar> {
  void _openMenu(BuildContext context) {
    if (widget.room == null) return;

    showMenuOptionsDialog(
      context,
      onFlipCamera: widget.onFlipCamera,
      room: widget.room!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _ControlButton(
                  icon: widget.isMicEnabled
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  isActive: widget.isMicEnabled,
                  onPressed: widget.onToggleMic,
                  tooltip: widget.isMicEnabled ? 'Mute' : 'Unmute',
                ),
                _ControlButton(
                  icon: widget.isCameraEnabled
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  isActive: widget.isCameraEnabled,
                  onPressed: widget.onToggleCamera,
                  tooltip: widget.isCameraEnabled
                      ? 'Stop video'
                      : 'Start video',
                ),
                _ControlButton(
                  icon: Icons.screen_share_rounded,
                  isActive: widget.isScreenSharing,
                  onPressed: widget.onToggleScreenShare,
                  tooltip: widget.isScreenSharing
                      ? 'Stop sharing'
                      : 'Share screen',
                ),
                const SizedBox(width: 4),
                const ReactionPicker(),
                const SizedBox(width: 4),
                const HandRaiseButton(),
                const SizedBox(width: 4),
                _ControlButton(
                  icon: Icons.chat_bubble,
                  isActive: false,
                  onPressed: () => _openMenu(context),
                  tooltip: 'More options',
                ),
                _ControlButton(
                  icon: Icons.call_end_rounded,
                  isActive: false,
                  isDanger: true,
                  onPressed: widget.onLeave,
                  tooltip: 'Leave call',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual control button
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final bool isDanger;
  final VoidCallback onPressed;
  final String tooltip;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.tooltip,
    this.isDanger = false,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.tooltip,
      enabled: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        onTapDown: (_) {
          _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () {
          _controller.reverse();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            shape: BoxShape.circle,
            border: Border.all(color: _getBorderColor(), width: 1.5),
            boxShadow: [
              if (widget.isActive && !widget.isDanger)
                BoxShadow(
                  color: ConnectColors.accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              else if (widget.isDanger)
                BoxShadow(
                  color: ConnectColors.error.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Icon(widget.icon, color: _getIconColor(), size: 22),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.isDanger) {
      return ConnectColors.error;
    }
    if (widget.isActive) {
      return ConnectColors.accent;
    }
    return Colors.white.withValues(alpha: 0.1);
  }

  Color _getBorderColor() {
    if (widget.isDanger) {
      return ConnectColors.error.withValues(alpha: 0.5);
    }
    if (widget.isActive) {
      return ConnectColors.accent.withValues(alpha: 0.5);
    }
    return Colors.white.withValues(alpha: 0.1);
  }

  Color _getIconColor() {
    if (widget.isDanger || widget.isActive) {
      return Colors.white;
    }
    return ConnectColors.textSecondary;
  }
}
