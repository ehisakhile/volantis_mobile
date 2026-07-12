import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../utils/platform_utils.dart';

/// Participant track info wrapper
class ParticipantTrack {
  final Participant participant;
  final bool isScreenShare;

  ParticipantTrack({required this.participant, this.isScreenShare = false});
}

typedef OnDisconnected = void Function();
typedef OnSpeakingWhileMuted = void Function();
typedef OnMediaError = void Function(String action, Object error);

/// Controller managing a LiveKit room connection
/// Owns the Room, handles track lifecycle, and maintains participant grid order
class RoomController extends ChangeNotifier {
  final Room room;
  late final EventsListener<RoomEvent> _listener;

  List<ParticipantTrack> _participantTracks = [];
  OnDisconnected? _onDisconnected;
  OnSpeakingWhileMuted? _onSpeakingWhileMuted;
  OnMediaError? _onMediaError;

  late double _lastLocalAudioLevel;
  bool _isScreenSharing = false;

  // Re-entrancy guards so double-taps can't race the device state
  bool _micToggleInProgress = false;
  bool _cameraToggleInProgress = false;

  RoomController({required this.room}) {
    _listener = room.createListener();
    _lastLocalAudioLevel = 0;
    _setupListeners();
    room.addListener(_onRoomDidUpdate);
  }

  List<ParticipantTrack> get participantTracks => _participantTracks;

  bool get isMicToggleInProgress => _micToggleInProgress;
  bool get isCameraToggleInProgress => _cameraToggleInProgress;

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
      })
      // These are the events that actually fire on mute/unmute (as opposed
      // to publish/unpublish). Without these, remote tiles' mute icons and
      // your own control bar state can go stale.
      ..on<TrackMutedEvent>((event) {
        _sortParticipants();
      })
      ..on<TrackUnmutedEvent>((event) {
        _sortParticipants();
      });
  }

  void setOnDisconnected(OnDisconnected callback) {
    _onDisconnected = callback;
  }

  void setOnSpeakingWhileMuted(OnSpeakingWhileMuted callback) {
    _onSpeakingWhileMuted = callback;
  }

  /// Called when a mic/camera/screen-share action fails (e.g. permission
  /// denied). Wire this up in the UI to show a toast/snackbar instead of
  /// failing silently.
  void setOnMediaError(OnMediaError callback) {
    _onMediaError = callback;
  }

  /// Check if local participant is speaking while muted.
  /// Uses the published track's muted state (not device state) for consistency with UI.
  void checkSpeakingWhileMuted() {
    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    final audioPubs = localParticipant.audioTrackPublications;
    if (audioPubs.isEmpty) return;

    final isMicMuted = audioPubs.first.muted;
    final audioLevel = localParticipant.audioLevel ?? 0;
    const audioLevelThreshold = 0.1;

    if (isMicMuted &&
        audioLevel > audioLevelThreshold &&
        _lastLocalAudioLevel <= audioLevelThreshold) {
      _onSpeakingWhileMuted?.call();
    }

    _lastLocalAudioLevel = audioLevel;
  }

  void _sortParticipants() {
    List<ParticipantTrack> tracks = [];

    for (var participant in room.remoteParticipants.values) {
      for (var trackPub in participant.videoTrackPublications) {
        if (trackPub.isScreenShare) {
          tracks.add(
            ParticipantTrack(participant: participant, isScreenShare: true),
          );
        }
      }
    }

    List<ParticipantTrack> userMediaTracks = [];

    for (var participant in room.remoteParticipants.values) {
      bool hasVideoTrack = false;
      for (var trackPub in participant.videoTrackPublications) {
        if (!trackPub.isScreenShare) {
          userMediaTracks.add(
            ParticipantTrack(participant: participant, isScreenShare: false),
          );
          hasVideoTrack = true;
          break;
        }
      }
      if (!hasVideoTrack) {
        userMediaTracks.add(
          ParticipantTrack(participant: participant, isScreenShare: false),
        );
      }
    }

    userMediaTracks.sort((a, b) {
      if (a.participant.isSpeaking && !b.participant.isSpeaking) return -1;
      if (!a.participant.isSpeaking && b.participant.isSpeaking) return 1;

      if (a.participant.isSpeaking && b.participant.isSpeaking) {
        final aLevel = a.participant.audioLevel ?? 0.0;
        final bLevel = b.participant.audioLevel ?? 0.0;
        final levelDiff = (bLevel - aLevel);
        if (levelDiff.abs() > 0.001) return levelDiff > 0 ? -1 : 1;
      }

      final aHasVideo = a.participant.videoTrackPublications
          .where((pub) => !pub.isScreenShare)
          .isNotEmpty;
      final bHasVideo = b.participant.videoTrackPublications
          .where((pub) => !pub.isScreenShare)
          .isNotEmpty;
      if (aHasVideo && !bHasVideo) return -1;
      if (!aHasVideo && bHasVideo) return 1;

      return 0;
    });

    tracks.addAll(userMediaTracks);

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

  Future<void> connect(
    String url,
    String token, {
    required bool enableMic,
    required bool enableCamera,
  }) async {
    await room.prepareConnection(url, token);
    await room.connect(url, token);

    try {
      await room.localParticipant?.setMicrophoneEnabled(false);
    } catch (e) {
      _onMediaError?.call('connect_mic', e);
    }

    if (enableCamera) {
      try {
        await room.localParticipant?.setCameraEnabled(true);
      } catch (e) {
        _onMediaError?.call('connect_camera', e);
      }
    }

    _sortParticipants();
  }

  /// Toggle microphone on/off.
  /// Uses setCameraEnabled() to control the device, and relies on TrackMutedEvent/
  /// TrackUnmutedEvent listeners to update UI. Re-entrancy guard prevents double-taps.
  Future<void> toggleMic() async {
    if (_micToggleInProgress) return;
    _micToggleInProgress = true;
    notifyListeners();

    try {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) return;

      // Get current muted state from the published track (not device state)
      final audioPubs = localParticipant.audioTrackPublications;
      if (audioPubs.isEmpty) return;

      final currentlyMuted = audioPubs.first.muted;
      // Toggle: if muted, enable; if enabled, mute
      await localParticipant.setMicrophoneEnabled(currentlyMuted);
    } catch (e) {
      _onMediaError?.call('toggle_mic', e);
    } finally {
      _micToggleInProgress = false;
      notifyListeners();
    }
  }

  /// Toggle camera on/off. Same pattern as toggleMic.
  Future<void> toggleCamera() async {
    if (_cameraToggleInProgress) return;
    _cameraToggleInProgress = true;
    notifyListeners();

    try {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) return;

      // Get current muted state from the published video track (non-screen-share)
      final videoPubs = localParticipant.videoTrackPublications
          .where((pub) => !pub.isScreenShare)
          .toList();
      if (videoPubs.isEmpty) return;

      final currentlyMuted = videoPubs.first.muted;
      // Toggle: if muted, enable; if enabled, mute
      await localParticipant.setCameraEnabled(currentlyMuted);
    } catch (e) {
      _onMediaError?.call('toggle_camera', e);
    } finally {
      _cameraToggleInProgress = false;
      notifyListeners();
    }
  }

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
      _onMediaError?.call('flip_camera', e);
    }
  }

  /// Get mic state from the published track (not device state).
  /// Returns true if mic is NOT muted (i.e., enabled for other participants).
  bool get isMicEnabled {
    final audioPubs = room.localParticipant?.audioTrackPublications;
    if (audioPubs == null || audioPubs.isEmpty) return false;
    return !audioPubs.first.muted;
  }

  /// Get camera state from the published track (not device state).
  /// Returns true if camera is NOT muted (i.e., enabled for other participants).
  bool get isCameraEnabled {
    final videoPubs = room.localParticipant?.videoTrackPublications
        .where((pub) => !pub.isScreenShare)
        .toList();
    if (videoPubs == null || videoPubs.isEmpty) return false;
    return !videoPubs.first.muted;
  }

  bool get isScreenSharing => _isScreenSharing;

  /// Toggle screen sharing on/off.
  /// On Android: requires media projection foreground service and Helper.requestCapturePermission().
  /// On iOS: requires a broadcast extension (native Xcode setup required).
  /// See livekitclientreademe.md for platform-specific setup.
  Future<void> toggleScreenShare() async {
    try {
      if (_isScreenSharing) {
        await _stopScreenShare();
      } else {
        await _startScreenShare();
      }
    } catch (e) {
      _onMediaError?.call('toggle_screen_share', e);
    }
  }

  /// Start screen sharing using LiveKit's setScreenShareEnabled().
  /// On Android, requests capture permission and sets up foreground service.
  /// On iOS, requires a broadcast extension (native setup outside Dart).
  Future<void> _startScreenShare() async {
    try {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) return;

      // Android-specific: request capture permission
      if (PlatformUtils.isAndroid()) {
        final hasCapturePermission =
            await PlatformUtils.requestCapturePermission();
        if (!hasCapturePermission) {
          _onMediaError?.call('screen_share_permission', 'Capture permission denied');
          return;
        }

        // Setup foreground service for Android screen sharing
        final setupSuccess = await PlatformUtils.setupAndroidScreenShare();
        if (!setupSuccess) {
          _onMediaError?.call('screen_share_setup', 'Failed to setup background service');
          return;
        }
      }

      // iOS: requires broadcast extension setup (done in native Xcode project)
      // User must follow the setup guide at:
      // https://github.com/flutter-webrtc/flutter-webrtc/wiki/iOS-Screen-Sharing#broadcast-extension-quick-setup

      await localParticipant.setScreenShareEnabled(true);
      _isScreenSharing = true;
      notifyListeners();
      _sortParticipants(); // Update grid to prioritize screen share
    } catch (e) {
      _isScreenSharing = false;
      _onMediaError?.call('start_screen_share', e);
      rethrow;
    }
  }

  /// Stop screen sharing and cleanup platform resources.
  Future<void> _stopScreenShare() async {
    try {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) return;

      await localParticipant.setScreenShareEnabled(false);

      // Android-specific: cleanup background service
      if (PlatformUtils.isAndroid()) {
        await PlatformUtils.disableAndroidScreenShare();
      }

      _isScreenSharing = false;
      notifyListeners();
      _sortParticipants(); // Update grid to remove screen share focus
    } catch (e) {
      _onMediaError?.call('stop_screen_share', e);
      rethrow;
    }
  }

  Future<void> leave() async {
    try {
      await room.disconnect();
    } catch (e) {
      _onMediaError?.call('leave', e);
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
