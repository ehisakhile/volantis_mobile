import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../connect_colors.dart';

/// Single participant video tile
class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isScreenShare;
  final bool isLocalParticipant;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isScreenShare = false,
    this.isLocalParticipant = false,
  });

  VideoTrack? _getVideoTrack() {
    try {
      if (isScreenShare) {
        final pub = participant.videoTrackPublications
            .firstWhere((pub) => pub.isScreenShare);
        return !pub.muted ? pub.track as VideoTrack? : null;
      } else {
        final pub = participant.videoTrackPublications
            .firstWhere((pub) => !pub.isScreenShare);
        return !pub.muted ? pub.track as VideoTrack? : null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Generate avatar background color based on participant name
  Color _getAvatarColor() {
    final colors = [
      const Color(0xFF3B82F6), // blue
      const Color(0xFF8B5CF6), // purple
      const Color(0xFFEC4899), // pink
      const Color(0xFFF59E0B), // amber
      const Color(0xFF10B981), // emerald
    ];
    final hashCode = (participant.name ?? 'guest').hashCode;
    return colors[hashCode.abs() % colors.length];
  }

  /// Get initials from participant name
  String _getInitials() {
    final name = participant.name ?? 'Guest';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'G';
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = _getVideoTrack();
    final isSpeaking = participant.isSpeaking;
    final isMicMuted = participant.isMuted;
    final hasVideo = videoTrack != null;

    return Container(
      decoration: BoxDecoration(
        color: ConnectColors.bgCard,
        border: Border.all(
          color: isSpeaking ? ConnectColors.accent : ConnectColors.border,
          width: isSpeaking ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or avatar placeholder
          if (hasVideo)
            VideoTrackRenderer(
              videoTrack!,
              mirrorMode: VideoViewMirrorMode.auto,
              fit: VideoViewFit.cover,
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getAvatarColor(),
                    _getAvatarColor().withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getInitials(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isMicMuted)
                      Icon(
                        Icons.mic_off,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),

          // Participant info bar (bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isLocalParticipant
                          ? '${participant.name ?? 'You'} (You)'
                          : (participant.name ?? 'Guest'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ConnectColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isMicMuted)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.mic_off,
                        color: ConnectColors.error,
                        size: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Active speaker indicator
          if (isSpeaking)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: ConnectColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ConnectColors.success.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
