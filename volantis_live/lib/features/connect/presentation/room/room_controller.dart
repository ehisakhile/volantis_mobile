import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Participant track info wrapper
class ParticipantTrack {
  final Participant participant;
  final bool isScreenShare;

  ParticipantTrack({required this.participant, this.isScreenShare = false});
}

typedef OnDisconnected = void Function();

/// Controller managing a LiveKit room connection
/// Owns the Room, handles track lifecycle, and maintains participant grid order
class RoomController extends ChangeNotifier {
  final Room room;
  late final EventsListener<RoomEvent> _listener;

  List<ParticipantTrack> _participantTracks = [];
  OnDisconnected? _onDisconnected;

  RoomController({required this.room}) {
    _listener = room.createListener();
    _setupListeners();
    room.addListener(_onRoomDidUpdate);
  }

  List<ParticipantTrack> get participantTracks => _participantTracks;

  void _onRoomDidUpdate() {
    _sortParticipants();
  }

  void _setupListeners() {
    _listener
      ..on<RoomDisconnectedEvent>((event) {
        _onDisconnected?.call();
      })
      ..on<ParticipantEvent>((event) {
        _sortParticipants();
      })
      ..on<LocalTrackPublishedEvent>((event) {
        _sortParticipants();
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        _sortParticipants();
      })
      ..on<TrackSubscribedEvent>((event) {
        _sortParticipants();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _sortParticipants();
      });
  }

  void setOnDisconnected(OnDisconnected callback) {
    _onDisconnected = callback;
  }

  /// Sort participants by active speaker, video priority, and join order
  void _sortParticipants() {
    List<ParticipantTrack> tracks = [];

    // Collect screen share tracks
    for (var participant in room.remoteParticipants.values) {
      for (var trackPub in participant.videoTrackPublications) {
        if (trackPub.isScreenShare) {
          tracks.add(
            ParticipantTrack(participant: participant, isScreenShare: true),
          );
        }
      }
    }

    // Collect user media (camera) tracks
    List<ParticipantTrack> userMediaTracks = [];
    for (var participant in room.remoteParticipants.values) {
      for (var trackPub in participant.videoTrackPublications) {
        if (!trackPub.isScreenShare) {
          userMediaTracks.add(
            ParticipantTrack(participant: participant, isScreenShare: false),
          );
        }
      }
    }

    // Sort user media tracks: active speaker first, then by video availability, then by join order
    userMediaTracks.sort((a, b) {
      // Active speaker first
      if (a.participant.isSpeaking && !b.participant.isSpeaking) return -1;
      if (!a.participant.isSpeaking && b.participant.isSpeaking) return 1;

      // If both speaking, sort by audio level (loudest first)
      if (a.participant.isSpeaking && b.participant.isSpeaking) {
        final aLevel = a.participant.audioLevel ?? 0.0;
        final bLevel = b.participant.audioLevel ?? 0.0;
        final levelDiff = (bLevel - aLevel);
        if (levelDiff.abs() > 0.001) return levelDiff > 0 ? -1 : 1;
      }

      // Video track priority
      final aHasVideo = a.participant.videoTrackPublications.isNotEmpty;
      final bHasVideo = b.participant.videoTrackPublications.isNotEmpty;
      if (aHasVideo && !bHasVideo) return -1;
      if (!aHasVideo && bHasVideo) return 1;

      // Maintain original order for stable sorting
      return 0;
    });

    // Combine: screen shares + user media + local participant
    tracks.addAll(userMediaTracks);

    // Add local participant's screen share if any
    if (room.localParticipant != null) {
      for (var trackPub in room.localParticipant!.videoTrackPublications) {
        if (trackPub.isScreenShare) {
          tracks.insert(
            0,
            ParticipantTrack(
              participant: room.localParticipant!,
              isScreenShare: true,
            ),
          );
        }
      }
    }

    // Add local participant's camera if any
    if (room.localParticipant != null) {
      for (var trackPub in room.localParticipant!.videoTrackPublications) {
        if (!trackPub.isScreenShare) {
          tracks.add(
            ParticipantTrack(
              participant: room.localParticipant!,
              isScreenShare: false,
            ),
          );
        }
      }
    }

    _participantTracks = tracks;
    notifyListeners();
  }

  /// Connect to LiveKit room
  Future<void> connect(
    String url,
    String token, {
    required bool enableMic,
    required bool enableCamera,
  }) async {
    try {
      await room.prepareConnection(url, token);
      await room.connect(url, token);

      if (enableMic) {
        try {
          await room.localParticipant?.setMicrophoneEnabled(true);
        } catch (e) {
          // Silently handle mic enable failure
        }
      }

      if (enableCamera) {
        try {
          await room.localParticipant?.setCameraEnabled(true);
        } catch (e) {
          // Silently handle camera enable failure
        }
      }

      _sortParticipants();
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle microphone on/off
  Future<void> toggleMic() async {
    try {
      final bool enabled = room.localParticipant?.isMicrophoneEnabled == true;
      await room.localParticipant?.setMicrophoneEnabled(!enabled);
      _sortParticipants();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Toggle camera on/off
  Future<void> toggleCamera() async {
    try {
      final bool enabled = room.localParticipant?.isCameraEnabled == true;
      await room.localParticipant?.setCameraEnabled(!enabled);
      _sortParticipants();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Flip camera between front and back
  Future<void> flipCamera() async {
    try {
      final track = room.localParticipant?.videoTrackPublications
          .firstWhere(
            (pub) => !pub.isScreenShare,
            orElse: () => throw Exception('No camera track found'),
          )
          .track;

      if (track is LocalVideoTrack) {
        final newPosition = (track.source == TrackSource.camera)
            ? CameraPosition.back
            : CameraPosition.front;
        await track.setCameraPosition(newPosition);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get current mic state
  bool get isMicEnabled => room.localParticipant?.isMicrophoneEnabled == true;

  /// Get current camera state
  bool get isCameraEnabled => room.localParticipant?.isCameraEnabled == true;

  /// Leave the room
  Future<void> leave() async {
    try {
      await room.disconnect();
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Future<void> dispose() async {
    room.removeListener(_onRoomDidUpdate);
    await _listener.dispose();
    await room.dispose();
    super.dispose();
  }
}
