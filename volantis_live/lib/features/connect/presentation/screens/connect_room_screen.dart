import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:go_router/go_router.dart';
import '../connect_colors.dart';
import '../room/room_controller.dart';
import '../widgets/control_bar.dart';
import '../widgets/participant_tile.dart';

/// Full-screen video conferencing room
class ConnectRoomScreen extends StatefulWidget {
  final String url;
  final String token;
  final String displayName;

  const ConnectRoomScreen({
    super.key,
    required this.url,
    required this.token,
    required this.displayName,
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
  int _currentPage = 0;
  static const int _participantsPerPage = 4;

  // Focused tile: tap a tile to expand it; tap again to unfocus
  String? _focusedParticipantId;

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

    return Scaffold(
      backgroundColor: ConnectColors.bg,
      body: Stack(
        children: [
          // Participant grid with exact layout spec
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final allTracks = _controller.participantTracks;

              if (allTracks.isEmpty) {
                return Center(
                  child: Text(
                    'Waiting for participants...',
                    style: TextStyle(
                      color: ConnectColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              // Separate screen share from regular participants
              ParticipantTrack? screenShareTrack;
              try {
                screenShareTrack = allTracks.firstWhere((t) => t.isScreenShare);
              } catch (e) {
                screenShareTrack = null;
              }
              final hasScreenShare = screenShareTrack != null;

              final regularTracks = allTracks
                  .where((t) => !t.isScreenShare)
                  .toList();

              // If screen sharing, it takes the focused slot; otherwise,
              // let the user tap to focus or show normal grid.
              String? effectiveFocused = _focusedParticipantId;
              if (hasScreenShare) {
                effectiveFocused = screenShareTrack.participant.sid;
              }

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildParticipantLayout(
                          regularTracks,
                          screenShareTrack,
                          hasScreenShare,
                          effectiveFocused,
                        ),
                      ),
                      // Pagination dots (only if >4 regular participants)
                      if (regularTracks.length > _participantsPerPage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPaginationDots(regularTracks.length),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Control bar
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return ControlBar(
                isMicEnabled: _controller.isMicEnabled,
                isCameraEnabled: _controller.isCameraEnabled,
                isScreenSharing: _controller.isScreenSharing,
                onToggleMic: _controller.toggleMic,
                onToggleCamera: _controller.toggleCamera,
                onFlipCamera: _controller.flipCamera,
                onToggleScreenShare: _controller.toggleScreenShare,
                onLeave: _leave,
              );
            },
          ),

          // Participant count badge
          Positioned(
            top: 16,
            left: 16,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final count = _controller.participantTracks.length;
                return Container(
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
                    '$count ${count != 1 ? 'participants' : 'participant'}',
                    style: TextStyle(
                      color: ConnectColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build participant layout following exact spec:
  /// 1 participant: fills entire space
  /// 2 participants: top/bottom split, each full width
  /// 3 participants: top half split 2-side, bottom half 1 centered
  /// 4 participants: 2x2 grid
  /// 5+: paginate with 4 per page
  /// If focused tile exists: show focused full-screen, others in strip below
  Widget _buildParticipantLayout(
    List<ParticipantTrack> regularTracks,
    ParticipantTrack? screenShareTrack,
    bool hasScreenShare,
    String? focusedId,
  ) {
    // Get current page of participants (4 per page)
    final totalPages =
        (regularTracks.length + _participantsPerPage - 1) ~/ _participantsPerPage;
    _currentPage = _currentPage.clamp(0, totalPages - 1);

    final startIdx = _currentPage * _participantsPerPage;
    final endIdx = (startIdx + _participantsPerPage).clamp(0, regularTracks.length);
    final pageTracks = regularTracks.sublist(startIdx, endIdx);

    // If screen share or user has focused a tile, show focused + strip
    if ((hasScreenShare && screenShareTrack != null) || focusedId != null) {
      final focusTrack = hasScreenShare && screenShareTrack != null
          ? screenShareTrack
          : pageTracks.firstWhere((t) => t.participant.sid == focusedId);

      return Column(
        children: [
          // Focused tile (takes 60% of height)
          Expanded(
            flex: 60,
            child: _buildTile(focusTrack, isFocused: true),
          ),
          const SizedBox(height: 8),
          // Strip of remaining participants (40% height)
          Expanded(
            flex: 40,
            child: _buildStrip(
              pageTracks.where((t) => t.participant.sid != focusedId).toList(),
            ),
          ),
        ],
      );
    }

    // Normal grid layout based on participant count
    if (pageTracks.length == 1) {
      // 1 participant: full screen
      return _buildTile(pageTracks[0], isFocused: false);
    } else if (pageTracks.length == 2) {
      // 2 participants: top/bottom split
      return Column(
        children: [
          Expanded(
            child: _buildTile(pageTracks[0], isFocused: false),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildTile(pageTracks[1], isFocused: false),
          ),
        ],
      );
    } else if (pageTracks.length == 3) {
      // 3 participants: top half split 2-side, bottom half 1 centered
      return Column(
        children: [
          Expanded(
            flex: 1,
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
            flex: 1,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildTile(pageTracks[2], isFocused: false),
              ),
            ),
          ),
        ],
      );
    } else {
      // 4+ participants: 2x2 grid
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: pageTracks.length,
        itemBuilder: (context, index) {
          return _buildTile(pageTracks[index], isFocused: false);
        },
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
                  )
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

  /// Build a horizontal strip of participants
  Widget _buildStrip(List<ParticipantTrack> tracks) {
    if (tracks.isEmpty) {
      return const SizedBox.expand();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : 8,
            right: index == tracks.length - 1 ? 0 : 0,
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildTile(tracks[index], isFocused: false),
          ),
        );
      },
    );
  }

  /// Build pagination dots
  Widget _buildPaginationDots(int participantCount) {
    final totalPages =
        (participantCount + _participantsPerPage - 1) ~/ _participantsPerPage;
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => GestureDetector(
          onTap: () {
            setState(() => _currentPage = index);
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
