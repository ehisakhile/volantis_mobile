import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing followed companies locally
class FollowedCompaniesService {
  static const String _followedCompaniesKey = 'followed_companies';
  static FollowedCompaniesService? _instance;
  static FlutterSecureStorage? _storage;

  FollowedCompaniesService._();

  static FollowedCompaniesService get instance {
    _instance ??= FollowedCompaniesService._();
    return _instance!;
  }

  static FlutterSecureStorage get _secureStorage {
    _storage ??= const FlutterSecureStorage();
    return _storage!;
  }

  /// Get all followed company IDs
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

  /// Check if a company is followed
  Future<bool> isCompanyFollowed(int companyId) async {
    final followedIds = await getFollowedCompanyIds();
    return followedIds.contains(companyId);
  }

  /// Follow a company
  Future<void> followCompany(int companyId) async {
    final followedIds = await getFollowedCompanyIds();
    followedIds.add(companyId);
    await _saveFollowedCompanies(followedIds);
  }

  /// Unfollow a company
  Future<void> unfollowCompany(int companyId) async {
    final followedIds = await getFollowedCompanyIds();
    followedIds.remove(companyId);
    await _saveFollowedCompanies(followedIds);
  }

  /// Toggle follow status
  Future<bool> toggleFollow(int companyId) async {
    final isFollowed = await isCompanyFollowed(companyId);
    if (isFollowed) {
      await unfollowCompany(companyId);
      return false;
    } else {
      await followCompany(companyId);
      return true;
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

  /// Clear all followed companies
  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _followedCompaniesKey);
    } catch (e) {
      print('Error clearing followed companies: $e');
    }
  }
}
