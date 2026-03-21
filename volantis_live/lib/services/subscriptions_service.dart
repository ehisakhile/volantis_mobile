import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../features/home/data/models/subscription_model.dart';
import 'api_service.dart';

/// Service for managing user subscriptions to companies/streamers
class SubscriptionsService {
  static SubscriptionsService? _instance;
  final ApiService _apiService = ApiService.instance;

  SubscriptionsService._();

  static SubscriptionsService get instance {
    _instance ??= SubscriptionsService._();
    return _instance!;
  }

  /// Get all subscriptions for the current user
  Future<List<SubscriptionModel>> getSubscriptions() async {
    try {
      final response = await _apiService.get(ApiConstants.subscriptions);

      if (response.data is List) {
        return (response.data as List)
            .map(
              (json) =>
                  SubscriptionModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      print('API: Error fetching subscriptions - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Check if user is subscribed to a specific company by slug
  Future<bool> isSubscribed(String companySlug) async {
    try {
      final endpoint = ApiConstants.subscriptionBySlug.replaceAll(
        '{slug}',
        companySlug,
      );

      final response = await _apiService.get(endpoint);
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      print('API: Error checking subscription status - ${e.message}');
      return false;
    }
  }

  /// Subscribe to a company
  Future<bool> subscribe(String companySlug) async {
    try {
      final response = await _apiService.post(
        ApiConstants.subscriptions,
        data: {'company_slug': companySlug},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('API: Error subscribing to company - ${e.message}');
      return false;
    }
  }

  /// Unsubscribe from a company
  Future<bool> unsubscribe(String companySlug) async {
    try {
      final endpoint = ApiConstants.subscriptionBySlug.replaceAll(
        '{slug}',
        companySlug,
      );

      final response = await _apiService.delete(endpoint);
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      print('API: Error unsubscribing from company - ${e.message}');
      return false;
    }
  }

  /// Get subscribed company slugs as a Set for quick lookup
  Future<Set<String>> getSubscribedSlugs() async {
    final subscriptions = await getSubscriptions();
    return subscriptions.map((s) => s.companySlug).toSet();
  }

  /// Handle errors
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    return 'Failed to load subscriptions';
  }
}
