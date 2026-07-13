import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../connect_colors.dart';
import '../room/room_controller.dart';
import '../widgets/control_bar.dart';
import '../widgets/participant_tile.dart';
import '../widgets/screen_share_viewer.dart';

/// Full-screen video conferencing room with stable, non-jumping layout
///
/// Core principles:
/// - Max 4 tiles on main screen (always stable, never resizes)
/// - No tile resizing for active speaker (highlight with border glow instead)
/// - Overflow shown via +N indicator at bottom-right
/// - Additional participants accessible via 2-column explorer bottom sheet
/// - Priority ordering: pinned > host > speaking > video
class ConnectRoomScreen extends StatefulWidget {
  final String url;
  final String token;
  final String displayName;
  final String? meetingCode;

  const ConnectRoomScreen({
    super.key,
    required this.url,
    required this.token,
    required this.displayName,
    this.meetingCode,
  });

  @override
  State<ConnectRoomScreen> createState() => _ConnectRoomScreenState();
}

class _ConnectRoomScreenState extends State<ConnectRoomScreen> {
  late RoomController _controller;
  bool _isConnecting = true;
  String? _error;
  DateTime? _lastUnmuteNotification;
  Timer? _audioCheckTimer;

  // Main grid is always 4 participants max — stable layout
  static const int _mainGridSize = 4;

  // Pinned participants (by SID) to keep them in main view
  final Set<String> _pinnedParticipants = {};

  // Screen share fullscreen mode: hides chrome (control bar, participant
  // strip, badges) so the share fills the entire display.
  bool _isScreenShareFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  Future<void> _initializeRoom() async {
    try {
      final room = Room();

      _controller = RoomController(room: room);
      _controller.setOnDisconnected(_onDisconnected);
      _controller.setOnSpeakingWhileMuted(_onSpeakingWhileMuted);

      await _controller.connect(
        widget.url,
        widget.token,
        enableMic: false,
        enableCamera: false,
      );

      // Start periodic check for speaking while muted
      _audioCheckTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _controller.checkSpeakingWhileMuted(),
      );

      setState(() => _isConnecting = false);
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _error = e.toString();
      });
    }
  }

  void _onSpeakingWhileMuted() {
    // Debounce notifications - only show once every 3 seconds
    final now = DateTime.now();
    if (_lastUnmuteNotification != null &&
        now.difference(_lastUnmuteNotification!) < const Duration(seconds: 3)) {
      return;
    }
    _lastUnmuteNotification = now;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You\'re muted — tap the mic button to unmute'),
          duration: const Duration(seconds: 3),
          backgroundColor: ConnectColors.accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          action: SnackBarAction(
            label: 'Unmute',
            textColor: Colors.white,
            onPressed: () {
              _controller.toggleMic();
            },
          ),
        ),
      );
    }
  }

  void _onDisconnected() {
    print('ConnectRoomScreen: Disconnected, navigating home');
    _clearMeetingState();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _leave() async {
    print('ConnectRoomScreen: User initiated leave');
    await _controller.leave();
    _clearMeetingState();
    if (mounted) {
      context.go('/');
    }
  }

  void _clearMeetingState() {
    print('ConnectRoomScreen: Clearing all meeting state');
    // The RoomController's dispose will clean up the LiveKit room
    // and all associated tracks, participants, and streams
    _controller.dispose();
  }

  String get meetingLink => widget.meetingCode != null
      ? 'connect.volantislive.com/${widget.meetingCode}'
      : '';

  Future<void> _shareMeeting() async {
    if (widget.meetingCode == null) return;
    await Share.share(
      'Join my meeting: $meetingLink',
      subject: 'Join my meeting',
    );
  }

  Future<void> _copyLink() async {
    if (meetingLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: meetingLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link copied to clipboard'),
          backgroundColor: ConnectColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ConnectColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share Meeting',
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meetingLink,
                style: TextStyle(color: ConnectColors.accent, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ConnectColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    color: ConnectColors.accent,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Copy Link',
                  style: TextStyle(color: ConnectColors.text),
                ),
                subtitle: Text(
                  'Copy to clipboard',
                  style: TextStyle(
                    color: ConnectColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyLink();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ConnectColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: ConnectColors.accent,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Share',
                  style: TextStyle(color: ConnectColors.text),
                ),
                subtitle: Text(
                  'Share via other apps',
                  style: TextStyle(
                    color: ConnectColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareMeeting();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculate priority score for ordering participants
  /// Higher score = higher priority in main grid
  /// Pinned (100) > Speaking (50) > Has Video (30)
  int _calculatePriority(ParticipantTrack track) {
    int score = 0;

    if (_pinnedParticipants.contains(track.participant.sid)) score += 100;
    if (track.participant.isSpeaking) score += 50;

    // Check if participant has a video track (not screen share)
    final hasVideo = track.participant.videoTrackPublications
        .where((pub) => !pub.isScreenShare)
        .isNotEmpty;
    if (hasVideo) score += 30;

    return score;
  }

  /// Get the top 4 participants to show in main grid, sorted by priority
  List<ParticipantTrack> _getTopParticipants(List<ParticipantTrack> allTracks) {
    final regularTracks = allTracks.where((t) => !t.isScreenShare).toList();
    regularTracks.sort((a, b) {
      return _calculatePriority(b).compareTo(_calculatePriority(a));
    });
    return regularTracks.take(_mainGridSize).toList();
  }

  /// Get remaining participants not in main grid
  List<ParticipantTrack> _getOverflowParticipants(
    List<ParticipantTrack> allTracks,
  ) {
    final topParticipants = _getTopParticipants(allTracks);
    final topSids = topParticipants.map((t) => t.participant.sid).toSet();
    return allTracks
        .where((t) => !t.isScreenShare && !topSids.contains(t.participant.sid))
        .toList();
  }

  @override
  void dispose() {
    _audioCheckTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Scaffold(
        backgroundColor: ConnectColors.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ConnectColors.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connecting...',
                  style: TextStyle(color: ConnectColors.text, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: ConnectColors.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: ConnectColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Error',
                    style: TextStyle(
                      color: ConnectColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ConnectColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ConnectColors.accent,
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final allTracks = _controller.participantTracks;

        // Separate screen share from regular participants
        ParticipantTrack? screenShareTrack;
        try {
          screenShareTrack = allTracks.firstWhere((t) => t.isScreenShare);
        } catch (e) {
          screenShareTrack = null;
        }
        final hasScreenShare = screenShareTrack != null;
        final screenShareVideoTrack = hasScreenShare
            ? screenShareTrack.participant.videoTrackPublications
                  .firstWhere((pub) => pub.isScreenShare)
                  .track
            : null;

        // Fullscreen screen share: strip away all other chrome so the share
        // fills the entire display. The viewer itself provides an exit
        // button, so this is the only branch that returns early.
        if (hasScreenShare &&
            _isScreenShareFullscreen &&
            screenShareVideoTrack is VideoTrack) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: ScreenShareViewer(
                track: screenShareVideoTrack,
                isFullscreen: true,
                onToggleFullscreen: () {
                  setState(() => _isScreenShareFullscreen = false);
                },
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ConnectColors.bg,
          body: SafeArea(
            child: Stack(
              children: [
                if (allTracks.isEmpty)
                  Center(
                    child: Text(
                      'Waiting for participants...',
                      style: TextStyle(
                        color: ConnectColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child:
                        (hasScreenShare && screenShareVideoTrack is VideoTrack)
                        ? _buildScreenShareLayout(
                            screenShareVideoTrack,
                            allTracks,
                          )
                        : _buildMainGrid(allTracks),
                  ),

                // Control bar
                ControlBar(
                  isMicEnabled: _controller.isMicEnabled,
                  isCameraEnabled: _controller.isCameraEnabled,
                  isScreenSharing: _controller.isScreenSharing,
                  onToggleMic: _controller.toggleMic,
                  onToggleCamera: _controller.toggleCamera,
                  onFlipCamera: _controller.flipCamera,
                  onToggleScreenShare: _controller.toggleScreenShare,
                  onLeave: _leave,
                ),

                // Participant count badge
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${allTracks.length} ${allTracks.length != 1 ? 'participants' : 'participant'}',
                      style: TextStyle(
                        color: ConnectColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Share button (only if meeting code is available)
                if (widget.meetingCode != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showShareOptions(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share_rounded,
                                  color: ConnectColors.text,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    color: ConnectColors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // +N overflow indicator (bottom-right, above controls)
                if (!hasScreenShare)
                  Positioned(
                    bottom: 80,
                    right: 16,
                    child: _buildOverflowIndicator(allTracks),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build the main stable 4-tile grid with optional overflow indicator
  Widget _buildMainGrid(List<ParticipantTrack> allTracks) {
    if (allTracks.isEmpty) {
      return const SizedBox.shrink();
    }

    final topParticipants = _getTopParticipants(allTracks);

    return Column(
      children: [Expanded(child: _buildStableGrid(topParticipants))],
    );
  }

  /// Build the stable 4-tile grid layout
  /// Layout is fixed: single tile, 2-split, 3-split (centered), or 2x2
  /// All layouts expand to fill available height
  Widget _buildStableGrid(List<ParticipantTrack> tracks) {
    if (tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (tracks.length == 1) {
      return _buildTile(tracks[0]);
    } else if (tracks.length == 2) {
      return Column(
        children: [
          Expanded(child: _buildTile(tracks[0])),
          const SizedBox(height: 8),
          Expanded(child: _buildTile(tracks[1])),
        ],
      );
    } else if (tracks.length == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(tracks[0])),
                const SizedBox(width: 8),
                Expanded(child: _buildTile(tracks[1])),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildTile(tracks[2]),
              ),
            ),
          ),
        ],
      );
    } else {
      // 4+ participants: 2x2 grid using full height
      // Use LayoutBuilder to dynamically calculate aspect ratio for full space usage
      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the perfect aspect ratio to fill all available space
          // For a 2x2 grid: each tile gets half the width and half the height
          // childAspectRatio = width / height
          // width per tile = (maxWidth - 8px gap) / 2
          // height per tile = (maxHeight - 8px gap) / 2
          final tileWidth = (constraints.maxWidth - 8) / 2;
          final tileHeight = (constraints.maxHeight - 8) / 2;
          final aspectRatio = tileWidth / tileHeight;

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: false,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: aspectRatio,
            ),
            itemCount: tracks.length,
            itemBuilder: (context, index) => _buildTile(tracks[index]),
          );
        },
      );
    }
  }

  /// Screen share is showing: give it the spotlight with participants below
  Widget _buildScreenShareLayout(
    VideoTrack screenShareVideoTrack,
    List<ParticipantTrack> allTracks,
  ) {
    final regularTracks = allTracks.where((t) => !t.isScreenShare).toList();
    final overflowTracks = _getOverflowParticipants(allTracks);
    final hasOverflow = overflowTracks.isNotEmpty;

    return Column(
      children: [
        Expanded(
          flex: 70,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ScreenShareViewer(
              track: screenShareVideoTrack,
              isFullscreen: false,
              onToggleFullscreen: () {
                setState(() => _isScreenShareFullscreen = true);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 30,
          child: Stack(
            children: [
              _buildScreenShareStrip(regularTracks),
              // Overflow indicator for screen share strip
              if (hasOverflow)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _buildOverflowIndicator(allTracks),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a single participant tile with active speaker highlighting
  /// No resizing — only highlight with border glow when speaking
  Widget _buildTile(ParticipantTrack track) {
    final isSpeaking = track.participant.isSpeaking;

    return GestureDetector(
      onLongPress: () {
        // Long-press to pin/unpin
        setState(() {
          if (_pinnedParticipants.contains(track.participant.sid)) {
            _pinnedParticipants.remove(track.participant.sid);
          } else {
            _pinnedParticipants.add(track.participant.sid);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSpeaking ? ConnectColors.accent : ConnectColors.border,
            width: isSpeaking ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: ConnectColors.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ParticipantTile(
          participant: track.participant,
          isScreenShare: track.isScreenShare,
          isLocalParticipant:
              track.participant == _controller.room.localParticipant,
        ),
      ),
    );
  }

  /// Build a horizontal scrollable strip of participants for screen share
  /// Uses smaller tiles (square) so more participants fit on screen
  Widget _buildScreenShareStrip(List<ParticipantTrack> tracks) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No participants',
          style: TextStyle(color: ConnectColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 6, right: 6),
          child: AspectRatio(
            // Smaller aspect ratio (square-ish) so more tiles fit
            aspectRatio: 1.0,
            child: _buildTile(tracks[index]),
          ),
        );
      },
    );
  }

  /// Build the +N overflow indicator with avatar collage
  /// Shows up to 4 participant avatars in a mini grid + count overlay
  Widget _buildOverflowIndicator(List<ParticipantTrack> allTracks) {
    final overflow = _getOverflowParticipants(allTracks);
    final overflowCount = overflow.length;

    if (overflowCount == 0) {
      return const SizedBox.shrink();
    }

    // Take first 4 overflow participants for the collage
    final previewParticipants = overflow.take(4).toList();

    return GestureDetector(
      onTap: () => _showParticipantsExplorer(context),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Avatar collage grid
            _buildAvatarCollage(previewParticipants),

            // +N overlay at bottom-right
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ConnectColors.accent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ConnectColors.bg, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$overflowCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build avatar collage for overflow indicator
  /// Arranges 1-4 participant avatars in a grid pattern
  Widget _buildAvatarCollage(List<ParticipantTrack> participants) {
    if (participants.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: ConnectColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            Icons.people_rounded,
            color: ConnectColors.text,
            size: 28,
          ),
        ),
      );
    }

    if (participants.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildAvatarTile(participants[0]),
      );
    } else if (participants.length == 2) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: _buildAvatarTile(participants[0]),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: _buildAvatarTile(participants[1]),
            ),
          ),
        ],
      );
    } else if (participants.length == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                    ),
                    child: _buildAvatarTile(participants[0]),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                    ),
                    child: _buildAvatarTile(participants[1]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: _buildAvatarTile(participants[2]),
            ),
          ),
        ],
      );
    } else {
      // 4 participants: 2x2 grid
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
            child: _buildAvatarTile(participants[0]),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
            ),
            child: _buildAvatarTile(participants[1]),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
            ),
            child: _buildAvatarTile(participants[2]),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(12),
            ),
            child: _buildAvatarTile(participants[3]),
          ),
        ],
      );
    }
  }

  /// Build a single avatar tile for the collage
  /// Shows participant video or fallback avatar
  Widget _buildAvatarTile(ParticipantTrack track) {
    final participant = track.participant;

    // Try to get the participant's camera video track
    try {
      final videoTrack = participant.videoTrackPublications
          .firstWhere((pub) => !pub.isScreenShare)
          .track;

      if (videoTrack is VideoTrack) {
        return Container(
          color: Colors.black,
          child: VideoTrackRenderer(
            videoTrack,
            mirrorMode: VideoViewMirrorMode.auto,
            fit: VideoViewFit.cover,
          ),
        );
      }
    } catch (e) {
      // No video track available, use fallback
    }

    // Fallback: show avatar with initials or name
    return Container(
      color: ConnectColors.border,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_rounded, color: ConnectColors.text, size: 16),
            const SizedBox(height: 2),
            Text(
              participant.name.isNotEmpty
                  ? participant.name.substring(0, 1).toUpperCase()
                  : '?',
              style: TextStyle(
                color: ConnectColors.text,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show all participants in a 2-column bottom sheet explorer
  /// Tap a participant to bring them into the main grid
  void _showParticipantsExplorer(BuildContext context) {
    final allTracks = _controller.participantTracks;
    final regularTracks = allTracks.where((t) => !t.isScreenShare).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ConnectColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'All Participants',
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: regularTracks.length,
                  itemBuilder: (context, index) {
                    final track = regularTracks[index];
                    final isPinned = _pinnedParticipants.contains(
                      track.participant.sid,
                    );

                    return GestureDetector(
                      onTap: () {
                        // Pin this participant to bring into main view
                        setState(() {
                          _pinnedParticipants.clear();
                          _pinnedParticipants.add(track.participant.sid);
                        });
                        Navigator.pop(ctx);
                      },
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isPinned
                                    ? ConnectColors.accent
                                    : ConnectColors.border,
                                width: isPinned ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ParticipantTile(
                              participant: track.participant,
                              isScreenShare: track.isScreenShare,
                              isLocalParticipant:
                                  track.participant ==
                                  _controller.room.localParticipant,
                            ),
                          ),
                          if (isPinned)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: ConnectColors.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.push_pin_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
