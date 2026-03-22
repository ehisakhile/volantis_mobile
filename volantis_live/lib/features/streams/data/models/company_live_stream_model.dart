/// Model representing a company from the API response
class Company {
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? description;

  Company({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      logoUrl: json['logo_url'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'description': description,
    };
  }
}

/// Model representing a live stream from company live endpoint
class CompanyLiveStreamDetail {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final bool isLive;
  final int viewerCount;
  final int peakViewers;
  final int totalViews;
  final String? webrtcPlaybackUrl;
  final String? hlsUrl;
  final DateTime? startedAt;

  CompanyLiveStreamDetail({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    required this.isLive,
    required this.viewerCount,
    required this.peakViewers,
    required this.totalViews,
    this.webrtcPlaybackUrl,
    this.hlsUrl,
    this.startedAt,
  });

  factory CompanyLiveStreamDetail.fromJson(Map<String, dynamic> json) {
    return CompanyLiveStreamDetail(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      isLive: json['is_live'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      peakViewers: json['peak_viewers'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      webrtcPlaybackUrl: json['webrtc_playback_url'],
      hlsUrl: json['hls_url'],
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'description': description,
      'is_live': isLive,
      'viewer_count': viewerCount,
      'peak_viewers': peakViewers,
      'total_views': totalViews,
      'webrtc_playback_url': webrtcPlaybackUrl,
      'hls_url': hlsUrl,
      'started_at': startedAt?.toIso8601String(),
    };
  }
}

/// Model representing the company live stream response
class CompanyLiveStream {
  final Company company;
  final CompanyLiveStreamDetail livestream;
  final int subscribersCount;
  final String message;

  CompanyLiveStream({
    required this.company,
    required this.livestream,
    required this.subscribersCount,
    required this.message,
  });

  factory CompanyLiveStream.fromJson(Map<String, dynamic> json) {
    return CompanyLiveStream(
      company: Company.fromJson(json['company'] ?? {}),
      livestream: CompanyLiveStreamDetail.fromJson(json['livestream'] ?? {}),
      subscribersCount: json['subscribers_count'] ?? 0,
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company': company.toJson(),
      'livestream': livestream.toJson(),
      'subscribers_count': subscribersCount,
      'message': message,
    };
  }
}

/// Model representing a company stream (from company streams endpoint)
class CompanyStream {
  final int id;
  final int companyId;
  final String title;
  final String slug;
  final String? description;
  final String streamType;
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final String? cfLiveInputUid;
  final String? cfRtmpsUrl;
  final String? cfStreamKey;
  final String? cfWebrtcPublishUrl;
  final String? cfWebrtcPlaybackUrl;
  final String? recordingUrl;
  final String? thumbnailUrl;
  final int viewerCount;
  final int peakViewers;
  final int totalViews;
  final String? createdByUsername;
  final DateTime? createdAt;

  CompanyStream({
    required this.id,
    required this.companyId,
    required this.title,
    required this.slug,
    this.description,
    required this.streamType,
    required this.isActive,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.cfLiveInputUid,
    this.cfRtmpsUrl,
    this.cfStreamKey,
    this.cfWebrtcPublishUrl,
    this.cfWebrtcPlaybackUrl,
    this.recordingUrl,
    this.thumbnailUrl,
    required this.viewerCount,
    required this.peakViewers,
    required this.totalViews,
    this.createdByUsername,
    this.createdAt,
  });

  factory CompanyStream.fromJson(Map<String, dynamic> json) {
    return CompanyStream(
      id: json['id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      streamType: json['stream_type'] ?? '',
      isActive: json['is_active'] ?? false,
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'])
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'])
          : null,
      durationSeconds: json['duration_seconds'],
      cfLiveInputUid: json['cf_live_input_uid'],
      cfRtmpsUrl: json['cf_rtmps_url'],
      cfStreamKey: json['cf_stream_key'],
      cfWebrtcPublishUrl: json['cf_webrtc_publish_url'],
      cfWebrtcPlaybackUrl: json['cf_webrtc_playback_url'],
      recordingUrl: json['recording_url'],
      thumbnailUrl: json['thumbnail_url'],
      viewerCount: json['viewer_count'] ?? 0,
      peakViewers: json['peak_viewers'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      createdByUsername: json['created_by_username'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'slug': slug,
      'description': description,
      'stream_type': streamType,
      'is_active': isActive,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'cf_live_input_uid': cfLiveInputUid,
      'cf_rtmps_url': cfRtmpsUrl,
      'cf_stream_key': cfStreamKey,
      'cf_webrtc_publish_url': cfWebrtcPublishUrl,
      'cf_webrtc_playback_url': cfWebrtcPlaybackUrl,
      'recording_url': recordingUrl,
      'thumbnail_url': thumbnailUrl,
      'viewer_count': viewerCount,
      'peak_viewers': peakViewers,
      'total_views': totalViews,
      'created_by_username': createdByUsername,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Get formatted duration string
  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) {
      return 'N/A';
    }
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get formatted date string
  String get formattedDate {
    if (createdAt == null) return '';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }
}
