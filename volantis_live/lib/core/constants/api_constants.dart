/// API constants for VolantisLive
class ApiConstants {
  ApiConstants._();

  // Base URL - Production API
  static const String baseUrl = 'https://api-dev.volantislive.com';

  // API Version
  static const String apiVersion = 'v1';

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String signup = '/auth/signup/user';
  static const String verifyEmail = '/auth/verify-email';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String passwordReset = '/auth/password-reset';
  static const String passwordResetVerify = '/auth/password-reset/verify';
  static const String updateProfile = '/auth/profile';
  static const String deleteAccount = '/auth/account';

  static const String userProfile = '/auth/me';
  static const String userSettings = '/user/settings';
  static const String userAnalytics = '/user/analytics';

  static const String channels = '/channels';
  static const String channelDetail = '/channels/{id}';
  static const String subscribedChannels = '/user/channels/subscribed';
  static const String subscribeChannel = '/user/channels/{id}/subscribe';
  static const String unsubscribeChannel = '/user/channels/{id}/unsubscribe';

  static const String streams = '/streams';
  static const String liveStreams = '/streams/live';
  static const String activeLivestreams = '/livestreams/active';
  static const String streamDetail = '/streams/{id}';

  static const String downloads = '/user/downloads';
  static const String downloadChannel = '/channels/{id}/download';

  // Company endpoints (public)
  static const String companies = '/companies';
  static const String companySearch = '/companies/search';
  static const String companyHome = '/{company_slug}';
  static const String companyLiveEndpoint = '/{company_slug}/live';
  static const String companyStreams = '/{company_slug}/streams';
  static const String companyRecordings =
      '/recordings/public/company/{company_slug}';

  /// Get company streams endpoint with optional parameters
  static String getCompanyStreamsEndpoint(
    String companySlug, {
    int limit = 50,
    int offset = 0,
    bool includeInactive =
        true, // Include inactive (previous) streams by default
  }) {
    return '/$companySlug/streams?limit=$limit&offset=$offset&include_inactive=$includeInactive';
  }

  /// Get active-only company streams endpoint
  static String getCompanyActiveStreamsEndpoint(
    String companySlug, {
    int limit = 50,
    int offset = 0,
  }) {
    return '/$companySlug/streams?limit=$limit&offset=$offset&include_inactive=false';
  }

  // Subscription endpoints (new API with company slug)
  static const String subscriptions = '/subscriptions';
  static const String subscriptionBySlug = '/subscriptions/{slug}';

  // New follow/subscribe endpoints using company slug
  static const String subscribeToCompany = '/subscriptions/{slug}/subscribe';
  static const String unsubscribeFromCompany =
      '/subscriptions/{slug}/unsubscribe';
  static const String companyStats = '/subscriptions/{slug}/stats';

  /// Get subscribe endpoint for a company
  static String getSubscribeEndpoint(String companySlug) {
    return '/subscriptions/$companySlug/subscribe';
  }

  /// Get unsubscribe endpoint for a company
  static String getUnsubscribeEndpoint(String companySlug) {
    return '/subscriptions/$companySlug/unsubscribe';
  }

  /// Get company stats endpoint
  static String getCompanyStatsEndpoint(String companySlug) {
    return '/subscriptions/$companySlug/stats';
  }

  /// Get companies list endpoint
  static String getCompaniesEndpoint({int limit = 50, int offset = 0}) {
    return '/companies?limit=$limit&offset=$offset';
  }

  /// Get company search endpoint
  static String getCompanySearchEndpoint(
    String query, {
    int limit = 20,
    int offset = 0,
  }) {
    return '/companies/search?q=${Uri.encodeComponent(query)}&limit=$limit&offset=$offset';
  }

  /// Get company live stream endpoint
  static String getCompanyLiveEndpoint(String companySlug) {
    return '/$companySlug/live';
  }

  // Category endpoints
  static const String categories = '/categories';
  static const String categoryPreferences = '/categories/preferences/me';

  // Recommendations endpoint
  static const String recommendations = '/recommendations';

  /// Get categories endpoint with pagination
  static String getCategoriesEndpoint({int page = 1, int limit = 20}) {
    return '/categories?page=$page&limit=$limit';
  }

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Headers
  static const String contentType = 'application/x-www-form-urlencoded';
  static const String jsonContentType = 'application/json';
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';
}
