import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../features/home/data/models/subscription_model.dart';
import 'api_service.dart';

/// Service for managing user subscriptions to companies/streamers
/// Using the new API endpoints: /subscriptions/{slug}/subscribe, /unsubscribe, /stats
class SubscriptionsService {
  static SubscriptionsService? _instance;
  final ApiService _apiService = ApiService.instance;

  // In-memory cache for subscriptions
  List<SubscriptionModel>? _subscriptionsCache;
  DateTime? _lastFetchTime;
  static const _cacheValidityDuration = Duration(minutes: 5);

  SubscriptionsService._();

  static SubscriptionsService get instance {
    _instance ??= SubscriptionsService._();
    return _instance!;
  }

  /// Check if cache is valid
  bool get _isCacheValid {
    if (_subscriptionsCache == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidityDuration;
  }

  /// Clear the cache
  void _clearCache() {
    _subscriptionsCache = null;
    _lastFetchTime = null;
  }

  /// Get all subscriptions for the current user
  /// Uses cache if available and still valid
  Future<List<SubscriptionModel>> getSubscriptions({
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid) {
      return _subscriptionsCache!;
    }

    try {
      final response = await _apiService.get(ApiConstants.subscriptions);

      if (response.data is List) {
        _subscriptionsCache = (response.data as List)
            .map(
              (json) =>
                  SubscriptionModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        _lastFetchTime = DateTime.now();
        return _subscriptionsCache!;
      }

      _subscriptionsCache = [];
      return [];
    } on DioException catch (e) {
      print('API: Error fetching subscriptions - ${e.message}');
      _clearCache();
      throw _handleError(e);
    }
  }

  /// Check if user is subscribed to a specific company by slug
  Future<bool> isSubscribed(String companySlug) async {
    // First check cache
    if (_isCacheValid) {
      return _subscriptionsCache!.any((s) => s.companySlug == companySlug);
    }

    // Fetch fresh data
    final subscriptions = await getSubscriptions();
    return subscriptions.any((s) => s.companySlug == companySlug);
  }

  /// Subscribe/Follow to a company using the new endpoint
  /// POST /subscriptions/{slug}/subscribe
  Future<bool> subscribe(String companySlug) async {
    try {
      final endpoint = ApiConstants.getSubscribeEndpoint(companySlug);
      print('API: Subscribing to company: $endpoint');

      final response = await _apiService.post(endpoint);

      print(
        'API: Subscribe response: ${response.statusCode} - ${response.data}',
      );

      // Clear cache after subscription change
      _clearCache();

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('API: Error subscribing to company - ${e.message}');
      return false;
    }
  }

  /// Unsubscribe/Unfollow from a company using the new endpoint
  /// DELETE /subscriptions/{slug}/unsubscribe
  Future<bool> unsubscribe(String companySlug) async {
    try {
      final endpoint = ApiConstants.getUnsubscribeEndpoint(companySlug);
      print('API: Unsubscribing from company: $endpoint');

      final response = await _apiService.delete(endpoint);

      print('API: Unsubscribe response: ${response.statusCode}');

      // Clear cache after subscription change
      _clearCache();

      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      print('API: Error unsubscribing from company - ${e.message}');
      return false;
    }
  }

  /// Get company subscription stats
  /// GET /subscriptions/{slug}/stats
  Future<CompanyStatsModel?> getCompanyStats(String companySlug) async {
    try {
      final endpoint = ApiConstants.getCompanyStatsEndpoint(companySlug);
      print('API: Getting company stats: $endpoint');

      final response = await _apiService.get(endpoint);

      if (response.data is Map<String, dynamic>) {
        return CompanyStatsModel.fromJson(response.data);
      }

      return null;
    } on DioException catch (e) {
      print('API: Error getting company stats - ${e.message}');
      return null;
    }
  }

  /// Get subscribed company slugs as a Set for quick lookup
  Future<Set<String>> getSubscribedSlugs() async {
    final subscriptions = await getSubscriptions();
    return subscriptions.map((s) => s.companySlug).toSet();
  }

  /// Get live subscriptions (companies that are currently live)
  Future<List<SubscriptionModel>> getLiveSubscriptions() async {
    final subscriptions = await getSubscriptions();
    return subscriptions.where((s) => s.isLive).toList();
  }

  /// Toggle subscription status for a company
  /// Returns true if now subscribed, false if unsubscribed
  Future<bool> toggleSubscription(String companySlug) async {
    final isCurrentlySubscribed = await isSubscribed(companySlug);

    if (isCurrentlySubscribed) {
      final success = await unsubscribe(companySlug);
      return success ? false : true; // If unsubscribe failed, still subscribed
    } else {
      final success = await subscribe(companySlug);
      return success
          ? true
          : false; // If subscribe failed, still not subscribed
    }
  }

  /// Handle errors
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    return 'Failed to load subscriptions';
  }
}
