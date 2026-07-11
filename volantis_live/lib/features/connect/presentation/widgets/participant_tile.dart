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
        return participant.videoTrackPublications
                .firstWhere((pub) => pub.isScreenShare)
                .track
            as VideoTrack?;
      } else {
        return participant.videoTrackPublications
                .firstWhere((pub) => !pub.isScreenShare)
                .track
            as VideoTrack?;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = _getVideoTrack();
    final isSpeaking = participant.isSpeaking;
    final isMicMuted = participant.isMuted;

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
          // Video or placeholder
          if (videoTrack != null)
            VideoTrackRenderer(
              videoTrack,
              mirrorMode: VideoViewMirrorMode.auto,
              fit: VideoViewFit.cover,
            )
          else
            Container(
              color: ConnectColors.bgSubtle,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      color: ConnectColors.accent,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Camera Off',
                      style: TextStyle(
                        color: ConnectColors.textSecondary,
                        fontSize: 12,
                      ),
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
                    Colors.black.withOpacity(0),
                    Colors.black.withOpacity(0.6),
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
                      participant.name ?? 'Guest',
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
                      color: ConnectColors.success.withOpacity(0.4),
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
