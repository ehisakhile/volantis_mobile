/// Model representing an active livestream from the /livestreams/active endpoint
class ActiveLivestream {
  final int id;
  final String title;
  final String slug;
  final int companyId;
  final String companySlug;
  final String companyName;
  final String? companyLogoUrl;
  final bool isLive;
  final int viewerCount;
  final String? thumbnailUrl;
  final DateTime? startedAt;

  ActiveLivestream({
    required this.id,
    required this.title,
    required this.slug,
    required this.companyId,
    required this.companySlug,
    required this.companyName,
    this.companyLogoUrl,
    required this.isLive,
    required this.viewerCount,
    this.thumbnailUrl,
    this.startedAt,
  });

  factory ActiveLivestream.fromJson(Map<String, dynamic> json) {
    return ActiveLivestream(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      companyId: json['company_id'] ?? 0,
      companySlug: json['company_slug'] ?? '',
      companyName: json['company_name'] ?? '',
      companyLogoUrl: json['company_logo_url'],
      isLive: json['is_live'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      thumbnailUrl: json['thumbnail_url'],
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
      'company_id': companyId,
      'company_slug': companySlug,
      'company_name': companyName,
      'company_logo_url': companyLogoUrl,
      'is_live': isLive,
      'viewer_count': viewerCount,
      'thumbnail_url': thumbnailUrl,
      'started_at': startedAt?.toIso8601String(),
    };
  }

  bool get hasLogo => companyLogoUrl != null && companyLogoUrl!.isNotEmpty;
}

/// Response model for active livestreams API
class ActiveLivestreamsResponse {
  final List<ActiveLivestream> streams;
  final int total;

  ActiveLivestreamsResponse({required this.streams, required this.total});

  factory ActiveLivestreamsResponse.fromJson(Map<String, dynamic> json) {
    final streamsList = json['streams'] as List<dynamic>? ?? [];
    return ActiveLivestreamsResponse(
      streams: streamsList
          .map((json) => ActiveLivestream.fromJson(json))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}
