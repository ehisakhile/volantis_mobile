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

/// Full-screen video conferencing room
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

  // Small grids (<=4 participants) use the exact hand-tuned 1/2/3/4 layouts.
  // Once there are more people than that, we switch to a swipeable,
  // Zoom-style paginated grid so everyone stays reachable via a swipe
  // instead of being crammed into one screen or hidden behind dots you
  // have to tap one at a time.
  static const int _soloPageSize = 4;
  static const int _crowdPageSize = 8;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Focused tile: tap a tile to expand it; tap again to unfocus
  String? _focusedParticipantId;

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
                style: TextStyle(
                  color: ConnectColors.accent,
                  fontSize: 12,
                ),
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
                  child: Icon(Icons.copy_rounded, color: ConnectColors.accent, size: 20),
                ),
                title: Text('Copy Link', style: TextStyle(color: ConnectColors.text)),
                subtitle: Text('Copy to clipboard', style: TextStyle(color: ConnectColors.textSecondary, fontSize: 12)),
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
                  child: Icon(Icons.share_rounded, color: ConnectColors.accent, size: 20),
                ),
                title: Text('Share', style: TextStyle(color: ConnectColors.text)),
                subtitle: Text('Share via other apps', style: TextStyle(color: ConnectColors.textSecondary, fontSize: 12)),
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

  @override
  void dispose() {
    _audioCheckTimer?.cancel();
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Scaffold(
        backgroundColor: ConnectColors.bg,
        body: Center(
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
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: ConnectColors.bg,
        body: Center(
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

        final regularTracks = allTracks.where((t) => !t.isScreenShare).toList();

        // Fullscreen screen share: strip away all other chrome so the share
        // fills the entire display. The viewer itself provides an exit
        // button, so this is the only branch that returns early.
        if (hasScreenShare &&
            _isScreenShareFullscreen &&
            screenShareVideoTrack is VideoTrack) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: ScreenShareViewer(
              track: screenShareVideoTrack,
              isFullscreen: true,
              onToggleFullscreen: () {
                setState(() => _isScreenShareFullscreen = false);
              },
            ),
          );
        }

        return Scaffold(
          backgroundColor: ConnectColors.bg,
          body: Stack(
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
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Expanded(
                          child:
                              (hasScreenShare &&
                                  screenShareVideoTrack is VideoTrack)
                              ? _buildScreenShareLayout(
                                  screenShareVideoTrack,
                                  regularTracks,
                                )
                              : _buildParticipantPager(regularTracks),
                        ),
                        if (!hasScreenShare &&
                            regularTracks.length > _soloPageSize)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildPaginationDots(regularTracks.length),
                          ),
                      ],
                    ),
                  ),
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
            ],
          ),
        );
      },
    );
  }

  /// Screen share is showing: give it the spotlight (with full pan/zoom/
  /// rotate/fit/fullscreen control) and keep every other participant
  /// reachable in a horizontally scrollable strip below - including anyone
  /// with camera/mic off, since RoomController now always keeps them in
  /// the track list.
  Widget _buildScreenShareLayout(
    VideoTrack screenShareVideoTrack,
    List<ParticipantTrack> regularTracks,
  ) {
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
        Expanded(flex: 30, child: _buildStrip(regularTracks)),
      ],
    );
  }

  /// Swipeable pager over all non-screen-share participants. Groups <=4
  /// people use the exact hand-tuned layout (1 full / 2 split / 3 split /
  /// 2x2). Larger groups paginate 8 at a time in a dense grid, swipeable
  /// left/right, so a class of 20+ students all stay reachable.
  Widget _buildParticipantPager(List<ParticipantTrack> regularTracks) {
    if (regularTracks.isEmpty) {
      return const SizedBox.shrink();
    }

    // If the user has focused a specific tile, show it large with the rest
    // in a strip - regardless of how many total participants there are.
    if (_focusedParticipantId != null &&
        regularTracks.any((t) => t.participant.sid == _focusedParticipantId)) {
      final focusTrack = regularTracks.firstWhere(
        (t) => t.participant.sid == _focusedParticipantId,
      );
      final rest = regularTracks
          .where((t) => t.participant.sid != _focusedParticipantId)
          .toList();
      return Column(
        children: [
          Expanded(flex: 60, child: _buildTile(focusTrack, isFocused: true)),
          const SizedBox(height: 8),
          Expanded(flex: 40, child: _buildStrip(rest)),
        ],
      );
    }

    final pageSize = regularTracks.length <= _soloPageSize
        ? _soloPageSize
        : _crowdPageSize;
    final totalPages = (regularTracks.length / pageSize).ceil();
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: totalPages,
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemBuilder: (context, pageIndex) {
        final start = pageIndex * pageSize;
        final end = (start + pageSize).clamp(0, regularTracks.length);
        final pageTracks = regularTracks.sublist(start, end);
        return _buildGridPage(pageTracks);
      },
    );
  }

  /// Lays out a single page of tiles. Small pages (<=4) use the exact
  /// hand-tuned arrangement; larger pages (5-8, "swipe for more") use a
  /// dense 2-column grid, similar to a Zoom gallery page.
  Widget _buildGridPage(List<ParticipantTrack> pageTracks) {
    if (pageTracks.length == 1) {
      return _buildTile(pageTracks[0], isFocused: false);
    } else if (pageTracks.length == 2) {
      return Column(
        children: [
          Expanded(child: _buildTile(pageTracks[0], isFocused: false)),
          const SizedBox(height: 8),
          Expanded(child: _buildTile(pageTracks[1], isFocused: false)),
        ],
      );
    } else if (pageTracks.length == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(pageTracks[0], isFocused: false)),
                const SizedBox(width: 8),
                Expanded(child: _buildTile(pageTracks[1], isFocused: false)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildTile(pageTracks[2], isFocused: false),
              ),
            ),
          ),
        ],
      );
    } else if (pageTracks.length == 4) {
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: pageTracks.length,
        itemBuilder: (context, index) =>
            _buildTile(pageTracks[index], isFocused: false),
      );
    } else {
      // 5-8 participants on this page: denser 2-column grid (up to 4 rows).
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
        ),
        itemCount: pageTracks.length,
        itemBuilder: (context, index) =>
            _buildTile(pageTracks[index], isFocused: false),
      );
    }
  }

  /// Build a single participant tile with tap-to-focus
  Widget _buildTile(ParticipantTrack track, {required bool isFocused}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_focusedParticipantId == track.participant.sid) {
            _focusedParticipantId = null; // Unfocus
          } else {
            _focusedParticipantId = track.participant.sid; // Focus this tile
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: isFocused
              ? Border.all(color: ConnectColors.accent, width: 3)
              : Border.all(color: ConnectColors.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: ConnectColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
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

  /// Build a horizontal, scrollable strip of participants (used below a
  /// focused tile or an active screen share).
  Widget _buildStrip(List<ParticipantTrack> tracks) {
    if (tracks.isEmpty) {
      return const SizedBox.expand();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildTile(tracks[index], isFocused: false),
          ),
        );
      },
    );
  }

  /// Build pagination dots. Tapping one animates the swipeable pager to
  /// that page, in sync with an actual left/right swipe.
  Widget _buildPaginationDots(int participantCount) {
    final pageSize = participantCount <= _soloPageSize
        ? _soloPageSize
        : _crowdPageSize;
    final totalPages = (participantCount / pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          },
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index
                  ? ConnectColors.accent
                  : ConnectColors.border,
            ),
          ),
        ),
      ),
    );
  }
}
