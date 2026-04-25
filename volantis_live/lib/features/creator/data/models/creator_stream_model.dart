import 'package:equatable/equatable.dart';

enum StreamType { audio, video }

enum StreamStatus { idle, starting, live, ending, ended }

class CreatorStream extends Equatable {
  final int id;
  final int companyId;
  final String? companySlug;
  final String? companyName;
  final String title;
  final String slug;
  final String? description;
  final StreamType streamType;
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? cfLiveInputUid;
  final String? cfRtmpsUrl;
  final String? cfStreamKey;
  final String? cfWebrtcPublishUrl;
  final String? cfWebrtcPlaybackUrl;
  final String? recordingUrl;
  final String? thumbnailUrl;
  final int viewerCount;
  final int peakViewers;
  final String createdByUsername;
  final DateTime createdAt;

  const CreatorStream({
    required this.id,
    required this.companyId,
    this.companySlug,
    this.companyName,
    required this.title,
    required this.slug,
    this.description,
    required this.streamType,
    required this.isActive,
    this.startTime,
    this.endTime,
    this.cfLiveInputUid,
    this.cfRtmpsUrl,
    this.cfStreamKey,
    this.cfWebrtcPublishUrl,
    this.cfWebrtcPlaybackUrl,
    this.recordingUrl,
    this.thumbnailUrl,
    this.viewerCount = 0,
    this.peakViewers = 0,
    required this.createdByUsername,
    required this.createdAt,
  });

  factory CreatorStream.fromJson(Map<String, dynamic> json) {
    return CreatorStream(
      id: json['id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      companySlug: json['company_slug'],
      companyName: json['company_name'],
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      streamType: json['stream_type'] == 'video'
          ? StreamType.video
          : StreamType.audio,
      isActive: json['is_active'] ?? false,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      cfLiveInputUid: json['cf_live_input_uid'],
      cfRtmpsUrl: json['cf_rtmps_url'],
      cfStreamKey: json['cf_stream_key'],
      cfWebrtcPublishUrl: json['cf_webrtc_publish_url'],
      cfWebrtcPlaybackUrl: json['cf_webrtc_playback_url'],
      recordingUrl: json['recording_url'],
      thumbnailUrl: json['thumbnail_url'],
      viewerCount: json['viewer_count'] ?? 0,
      peakViewers: json['peak_viewers'] ?? 0,
      createdByUsername: json['created_by_username'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'company_slug': companySlug,
      'company_name': companyName,
      'title': title,
      'slug': slug,
      'description': description,
      'stream_type': streamType == StreamType.video ? 'video' : 'audio',
      'is_active': isActive,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'cf_live_input_uid': cfLiveInputUid,
      'cf_rtmps_url': cfRtmpsUrl,
      'cf_stream_key': cfStreamKey,
      'cf_webrtc_publish_url': cfWebrtcPublishUrl,
      'cf_webrtc_playback_url': cfWebrtcPlaybackUrl,
      'recording_url': recordingUrl,
      'thumbnail_url': thumbnailUrl,
      'viewer_count': viewerCount,
      'peak_viewers': peakViewers,
      'created_by_username': createdByUsername,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CreatorStream copyWith({
    int? id,
    int? companyId,
    String? companySlug,
    String? companyName,
    String? title,
    String? slug,
    String? description,
    StreamType? streamType,
    bool? isActive,
    DateTime? startTime,
    DateTime? endTime,
    String? cfLiveInputUid,
    String? cfRtmpsUrl,
    String? cfStreamKey,
    String? cfWebrtcPublishUrl,
    String? cfWebrtcPlaybackUrl,
    String? recordingUrl,
    String? thumbnailUrl,
    int? viewerCount,
    int? peakViewers,
    String? createdByUsername,
    DateTime? createdAt,
  }) {
    return CreatorStream(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companySlug: companySlug ?? this.companySlug,
      companyName: companyName ?? this.companyName,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      streamType: streamType ?? this.streamType,
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      cfLiveInputUid: cfLiveInputUid ?? this.cfLiveInputUid,
      cfRtmpsUrl: cfRtmpsUrl ?? this.cfRtmpsUrl,
      cfStreamKey: cfStreamKey ?? this.cfStreamKey,
      cfWebrtcPublishUrl: cfWebrtcPublishUrl ?? this.cfWebrtcPublishUrl,
      cfWebrtcPlaybackUrl: cfWebrtcPlaybackUrl ?? this.cfWebrtcPlaybackUrl,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewerCount: viewerCount ?? this.viewerCount,
      peakViewers: peakViewers ?? this.peakViewers,
      createdByUsername: createdByUsername ?? this.createdByUsername,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    companyId,
    companySlug,
    companyName,
    title,
    slug,
    description,
    streamType,
    isActive,
    startTime,
    endTime,
    cfLiveInputUid,
    cfRtmpsUrl,
    cfStreamKey,
    cfWebrtcPublishUrl,
    cfWebrtcPlaybackUrl,
    recordingUrl,
    thumbnailUrl,
    viewerCount,
    peakViewers,
    createdByUsername,
    createdAt,
  ];
}

class StreamStats extends Equatable {
  final String slug;
  final bool isActive;
  final int viewerCount;
  final int peakViewers;
  final int totalViews;
  final String? websocketUrl;

  const StreamStats({
    required this.slug,
    required this.isActive,
    required this.viewerCount,
    required this.peakViewers,
    required this.totalViews,
    this.websocketUrl,
  });

  factory StreamStats.fromJson(Map<String, dynamic> json) {
    return StreamStats(
      slug: json['slug'] ?? '',
      isActive: json['is_active'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      peakViewers: json['peak_viewers'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      websocketUrl: json['websocket_url'],
    );
  }

  @override
  List<Object?> get props => [
    slug,
    isActive,
    viewerCount,
    peakViewers,
    totalViews,
    websocketUrl,
  ];
}

class ChatMessage extends Equatable {
  final int id;
  final String slug;
  final int userId;
  final String? username;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isEdited;

  const ChatMessage({
    required this.id,
    required this.slug,
    required this.userId,
    this.username,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
    this.isEdited = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      userId: json['user_id'] ?? 0,
      username: json['username'],
      userAvatarUrl: json['user_avatar_url'],
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isEdited: json['is_edited'] ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    slug,
    userId,
    username,
    userAvatarUrl,
    content,
    createdAt,
    isEdited,
  ];
}
