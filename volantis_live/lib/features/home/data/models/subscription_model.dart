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
