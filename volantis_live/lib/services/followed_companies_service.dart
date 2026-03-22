import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/home/data/models/subscription_model.dart';
import 'subscriptions_service.dart';

/// Service for managing followed companies
/// Uses API as primary source with local fallback/cache
class FollowedCompaniesService {
  static const String _followedCompaniesKey = 'followed_companies';
  static FollowedCompaniesService? _instance;
  static FlutterSecureStorage? _storage;

  // Reference to subscriptions service for API calls
  final SubscriptionsService _subscriptionsService =
      SubscriptionsService.instance;

  FollowedCompaniesService._();

  static FollowedCompaniesService get instance {
    _instance ??= FollowedCompaniesService._();
    return _instance!;
  }

  static FlutterSecureStorage get _secureStorage {
    _storage ??= const FlutterSecureStorage();
    return _storage!;
  }

  /// Get all followed company IDs from local storage
  /// Note: This is for local caching - actual state comes from API
  Future<Set<int>> getFollowedCompanyIds() async {
    try {
      final data = await _secureStorage.read(key: _followedCompaniesKey);
      if (data == null || data.isEmpty) {
        return {};
      }
      final List<dynamic> ids = jsonDecode(data);
      return ids.map((id) => id as int).toSet();
    } catch (e) {
      print('Error reading followed companies: $e');
      return {};
    }
  }

  /// Get all subscriptions from API
  Future<List<SubscriptionModel>> getFollowedSubscriptions() async {
    try {
      return await _subscriptionsService.getSubscriptions();
    } catch (e) {
      print('Error fetching followed subscriptions: $e');
      return [];
    }
  }

  /// Check if a company is followed (by ID - for backward compatibility)
  Future<bool> isCompanyFollowed(int companyId) async {
    // Try to get from API first
    try {
      // We need the slug to check - this is a limitation
      // The caller should use isCompanyFollowedBySlug when possible
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if a company is followed by slug
  Future<bool> isCompanyFollowedBySlug(String companySlug) async {
    try {
      return await _subscriptionsService.isSubscribed(companySlug);
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  /// Follow a company (subscribe via API)
  Future<bool> followCompany(int companyId, String companySlug) async {
    try {
      final success = await _subscriptionsService.subscribe(companySlug);
      if (success) {
        // Also save to local storage for offline access
        await _addToLocalStorage(companyId);
      }
      return success;
    } catch (e) {
      print('Error following company: $e');
      return false;
    }
  }

  /// Unfollow a company (unsubscribe via API)
  Future<bool> unfollowCompany(int companyId, String companySlug) async {
    try {
      final success = await _subscriptionsService.unsubscribe(companySlug);
      if (success) {
        // Also remove from local storage
        await _removeFromLocalStorage(companyId);
      }
      return success;
    } catch (e) {
      print('Error unfollowing company: $e');
      return false;
    }
  }

  /// Toggle follow status
  /// Returns true if now followed, false if unfollowed
  Future<bool> toggleFollow(int companyId, String companySlug) async {
    final isFollowed = await isCompanyFollowedBySlug(companySlug);
    if (isFollowed) {
      final success = await unfollowCompany(companyId, companySlug);
      return success ? false : true;
    } else {
      final success = await followCompany(companyId, companySlug);
      return success ? true : false;
    }
  }

  /// Get company stats
  Future<CompanyStatsModel?> getCompanyStats(String companySlug) async {
    try {
      return await _subscriptionsService.getCompanyStats(companySlug);
    } catch (e) {
      print('Error getting company stats: $e');
      return null;
    }
  }

  /// Get live followed streams
  Future<List<SubscriptionModel>> getLiveFollowedStreams() async {
    try {
      return await _subscriptionsService.getLiveSubscriptions();
    } catch (e) {
      print('Error getting live followed streams: $e');
      return [];
    }
  }

  /// Get followed company slugs
  Future<Set<String>> getFollowedSlugs() async {
    try {
      return await _subscriptionsService.getSubscribedSlugs();
    } catch (e) {
      print('Error getting followed slugs: $e');
      return {};
    }
  }

  /// Add company ID to local storage
  Future<void> _addToLocalStorage(int companyId) async {
    try {
      final followedIds = await getFollowedCompanyIds();
      followedIds.add(companyId);
      await _saveFollowedCompanies(followedIds);
    } catch (e) {
      print('Error saving to local storage: $e');
    }
  }

  /// Remove company ID from local storage
  Future<void> _removeFromLocalStorage(int companyId) async {
    try {
      final followedIds = await getFollowedCompanyIds();
      followedIds.remove(companyId);
      await _saveFollowedCompanies(followedIds);
    } catch (e) {
      print('Error removing from local storage: $e');
    }
  }

  /// Save followed companies to storage
  Future<void> _saveFollowedCompanies(Set<int> followedIds) async {
    try {
      final data = jsonEncode(followedIds.toList());
      await _secureStorage.write(key: _followedCompaniesKey, value: data);
    } catch (e) {
      print('Error saving followed companies: $e');
    }
  }

  /// Clear all followed companies (local only)
  Future<void> clearLocal() async {
    try {
      await _secureStorage.delete(key: _followedCompaniesKey);
    } catch (e) {
      print('Error clearing followed companies: $e');
    }
  }

  /// Force refresh subscriptions from API
  Future<List<SubscriptionModel>> refreshSubscriptions() async {
    return await _subscriptionsService.getSubscriptions(forceRefresh: true);
  }
}
