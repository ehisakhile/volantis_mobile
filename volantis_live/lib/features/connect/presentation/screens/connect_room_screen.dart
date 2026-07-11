import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  Future<void> _initializeRoom() async {
    try {
      print('ConnectRoomScreen: Initializing room');
      final room = Room();

      _controller = RoomController(room: room);
      _controller.setOnDisconnected(_onDisconnected);

      await _controller.connect(
        widget.url,
        widget.token,
        enableMic: true,
        enableCamera: true,
      );

      setState(() => _isConnecting = false);
      print('ConnectRoomScreen: Room initialized and connected');
    } catch (e) {
      print('ConnectRoomScreen: Error initializing room: $e');
      setState(() {
        _isConnecting = false;
        _error = e.toString();
      });
    }
  }

  void _onDisconnected() {
    print('ConnectRoomScreen: Disconnected, popping back');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _leave() async {
    print('ConnectRoomScreen: User initiated leave');
    await _controller.leave();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
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
          // Participant grid
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final tracks = _controller.participantTracks;

              if (tracks.isEmpty) {
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

              // Responsive grid layout
              final columns = _calculateColumns(tracks.length);
              final childAspectRatio = 16 / 9;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isLocal =
                          track.participant ==
                          _controller.room.localParticipant;

                      return ParticipantTile(
                        participant: track.participant,
                        isScreenShare: track.isScreenShare,
                        isLocalParticipant: isLocal,
                      );
                    },
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
                onToggleMic: _controller.toggleMic,
                onToggleCamera: _controller.toggleCamera,
                onFlipCamera: _controller.flipCamera,
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

  /// Calculate number of grid columns based on participant count
  int _calculateColumns(int participantCount) {
    if (participantCount == 1) return 1;
    if (participantCount == 2) return 2;
    if (participantCount <= 4) return 2;
    return 3;
  }
}
