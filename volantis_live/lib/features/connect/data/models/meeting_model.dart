/// Meeting model - represents a video conference room
class Meeting {
  final int id;
  final String niceId;
  final String title;
  final String status; // pending, active, ended
  final int participantCount;
  final int maxParticipants;
  final LiveKitToken? livekit;

  Meeting({
    required this.id,
    required this.niceId,
    required this.title,
    required this.status,
    required this.participantCount,
    required this.maxParticipants,
    this.livekit,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] ?? 0,
      niceId: json['nice_id'] ?? '',
      title: json['title'] ?? 'Untitled Room',
      status: json['status'] ?? 'pending',
      participantCount: json['participant_count'] ?? 0,
      maxParticipants: json['max_participants'] ?? 0,
      livekit: json['livekit'] != null ? LiveKitToken.fromJson(json['livekit']) : null,
    );
  }
}

/// LiveKit connection credentials
class LiveKitToken {
  final String token;
  final String livekitUrl;
  final String room;

  LiveKitToken({
    required this.token,
    required this.livekitUrl,
    required this.room,
  });

  factory LiveKitToken.fromJson(Map<String, dynamic> json) {
    return LiveKitToken(
      token: json['token'] ?? '',
      livekitUrl: json['livekit_url'] ?? '',
      room: json['room'] ?? '',
    );
  }
}

/// Guest token response for unauthenticated users joining
class GuestTokenResponse {
  final String token;
  final String livekitUrl;
  final String identity;
  final String displayName;
  final String room;
  final String meetingTitle;

  GuestTokenResponse({
    required this.token,
    required this.livekitUrl,
    required this.identity,
    required this.displayName,
    required this.room,
    required this.meetingTitle,
  });

  factory GuestTokenResponse.fromJson(Map<String, dynamic> json) {
    return GuestTokenResponse(
      token: json['token'] ?? '',
      livekitUrl: json['livekit_url'] ?? '',
      identity: json['identity'] ?? '',
      displayName: json['display_name'] ?? 'Guest',
      room: json['room'] ?? '',
      meetingTitle: json['meeting_title'] ?? '',
    );
  }
}
