class RecommendedCompany {
  final int companyId;
  final String companyName;
  final String companySlug;
  final String? companyLogoUrl;
  final List<String> categories;

  RecommendedCompany({
    required this.companyId,
    required this.companyName,
    required this.companySlug,
    this.companyLogoUrl,
    required this.categories,
  });

  factory RecommendedCompany.fromJson(Map<String, dynamic> json) {
    return RecommendedCompany(
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      companySlug: json['company_slug'] ?? '',
      companyLogoUrl: json['company_logo_url'],
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  bool get hasLogo => companyLogoUrl != null && companyLogoUrl!.isNotEmpty;
}

class SubscribedLivestream {
  final int id;
  final String title;
  final String slug;
  final int companyId;
  final String companyName;
  final String companySlug;
  final bool isLive;
  final int viewerCount;
  final String? thumbnailUrl;

  SubscribedLivestream({
    required this.id,
    required this.title,
    required this.slug,
    required this.companyId,
    required this.companyName,
    required this.companySlug,
    required this.isLive,
    required this.viewerCount,
    this.thumbnailUrl,
  });

  factory SubscribedLivestream.fromJson(Map<String, dynamic> json) {
    return SubscribedLivestream(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      companySlug: json['company_slug'] ?? '',
      isLive: json['is_live'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      thumbnailUrl: json['thumbnail_url'],
    );
  }
}

class SubscribedRecording {
  final int id;
  final String title;
  final int companyId;
  final String companyName;
  final String companySlug;
  final String? thumbnailUrl;
  final int durationSeconds;

  SubscribedRecording({
    required this.id,
    required this.title,
    required this.companyId,
    required this.companyName,
    required this.companySlug,
    this.thumbnailUrl,
    required this.durationSeconds,
  });

  factory SubscribedRecording.fromJson(Map<String, dynamic> json) {
    return SubscribedRecording(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      companySlug: json['company_slug'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      durationSeconds: json['duration_seconds'] ?? 0,
    );
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class RecommendationsResponse {
  final List<RecommendedCompany> recommendedCompanies;
  final List<SubscribedLivestream> subscribedLivestreams;
  final List<SubscribedRecording> subscribedRecordings;

  RecommendationsResponse({
    required this.recommendedCompanies,
    required this.subscribedLivestreams,
    required this.subscribedRecordings,
  });

  factory RecommendationsResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationsResponse(
      recommendedCompanies:
          (json['recommended_companies'] as List<dynamic>?)
              ?.map((e) => RecommendedCompany.fromJson(e))
              .toList() ??
          [],
      subscribedLivestreams:
          (json['subscribed_livestreams'] as List<dynamic>?)
              ?.map((e) => SubscribedLivestream.fromJson(e))
              .toList() ??
          [],
      subscribedRecordings:
          (json['subscribed_recordings'] as List<dynamic>?)
              ?.map((e) => SubscribedRecording.fromJson(e))
              .toList() ??
          [],
    );
  }
}
