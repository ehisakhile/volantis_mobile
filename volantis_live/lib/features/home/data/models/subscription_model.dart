/// Model representing a user's subscription to a company/streamer
class SubscriptionModel {
  final int companyId;
  final String companyName;
  final String companySlug;
  final String? companyLogoUrl;
  final DateTime? subscribedAt;
  final bool isLive;
  final int currentViewers;

  SubscriptionModel({
    required this.companyId,
    required this.companyName,
    required this.companySlug,
    this.companyLogoUrl,
    this.subscribedAt,
    this.isLive = false,
    this.currentViewers = 0,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      companySlug: json['company_slug'] ?? '',
      companyLogoUrl: json['company_logo_url'],
      subscribedAt: json['subscribed_at'] != null
          ? DateTime.tryParse(json['subscribed_at'])
          : null,
      isLive: json['is_live'] ?? false,
      currentViewers: json['current_viewers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'company_slug': companySlug,
      'company_logo_url': companyLogoUrl,
      'subscribed_at': subscribedAt?.toIso8601String(),
      'is_live': isLive,
      'current_viewers': currentViewers,
    };
  }

  /// Check if subscription has a logo
  bool get hasLogo => companyLogoUrl != null && companyLogoUrl!.isNotEmpty;
}

/// Model representing company subscription stats
class CompanyStatsModel {
  final String companySlug;
  final String companyName;
  final int totalStreams;
  final int totalStreamedHours;
  final int totalStreamedMinutes;
  final int subscriberCount;
  final int currentViewers;
  final bool isLive;
  final String? activeStreamTitle;

  CompanyStatsModel({
    required this.companySlug,
    required this.companyName,
    required this.totalStreams,
    required this.totalStreamedHours,
    required this.totalStreamedMinutes,
    required this.subscriberCount,
    required this.currentViewers,
    required this.isLive,
    this.activeStreamTitle,
  });

  factory CompanyStatsModel.fromJson(Map<String, dynamic> json) {
    // Handle nested total_streamed_time object
    final streamedTime = json['total_streamed_time'] as Map<String, dynamic>?;

    return CompanyStatsModel(
      companySlug: json['company_slug'] ?? '',
      companyName: json['company_name'] ?? '',
      totalStreams: json['total_streams'] ?? 0,
      totalStreamedHours: streamedTime?['hours'] ?? 0,
      totalStreamedMinutes: streamedTime?['minutes'] ?? 0,
      subscriberCount: json['subscriber_count'] ?? 0,
      currentViewers: json['current_viewers'] ?? 0,
      isLive: json['is_live'] ?? false,
      activeStreamTitle: json['active_stream_title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_slug': companySlug,
      'company_name': companyName,
      'total_streams': totalStreams,
      'total_streamed_time': {
        'hours': totalStreamedHours,
        'minutes': totalStreamedMinutes,
      },
      'subscriber_count': subscriberCount,
      'current_viewers': currentViewers,
      'is_live': isLive,
      'active_stream_title': activeStreamTitle,
    };
  }

  /// Get formatted streamed time string
  String get formattedStreamedTime {
    if (totalStreamedHours > 0) {
      return '${totalStreamedHours}h ${totalStreamedMinutes}m';
    }
    return '${totalStreamedMinutes}m';
  }
}
