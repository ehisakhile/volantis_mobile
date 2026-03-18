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
