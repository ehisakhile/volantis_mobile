import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../../../../services/subscriptions_service.dart';
import '../../data/models/company_model.dart';
import '../../../recordings/data/models/recording_model.dart';

/// Home provider for managing home screen state - Companies listing
class HomeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final SubscriptionsService _subscriptionsService =
      SubscriptionsService.instance;

  // Companies data
  List<CompanyModel> _allCompanies = [];
  List<CompanyModel> _filteredCompanies = [];
  List<CompanyModel> _searchResults = [];
  // Track subscriptions by company slug (from API)
  Set<String> _subscribedSlugs = {};

  // Pagination
  int _currentOffset = 0;
  int _totalCompanies = 0;
  bool _hasMoreCompanies = true;
  static const int _pageSize = 50;

  // Search
  String _searchQuery = '';
  bool _isSearching = false;

  // Recordings from followed companies
  List<Recording> _followedRecordings = [];
  bool _isLoadingRecordings = false;

  // State
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSearchingLoading = false;
  String? _error;

  // Getters
  List<CompanyModel> get companies => _filteredCompanies;
  List<CompanyModel> get searchResults => _searchResults;
  List<CompanyModel> get followedCompanies =>
      _allCompanies.where((c) => _subscribedSlugs.contains(c.slug)).toList();
  Set<String> get subscribedSlugs => _subscribedSlugs;
  List<Recording> get followedRecordings => _followedRecordings;
  bool get isLoadingRecordings => _isLoadingRecordings;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSearchingLoading => _isSearchingLoading;
  bool get hasMoreCompanies => _hasMoreCompanies;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching && _searchQuery.isNotEmpty;
  int get totalCompanies => _totalCompanies;

  /// Initialize home data
  Future<void> init() async {
    _isLoading = true;
    _currentOffset = 0;
    _hasMoreCompanies = true;
    notifyListeners();

    try {
      // Fetch subscriptions from API
      await _fetchSubscriptions();

      // Fetch companies
      await _fetchCompanies();

      // Fetch recordings for followed companies
      await _fetchFollowedRecordings();

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch subscriptions from API
  Future<void> _fetchSubscriptions() async {
    try {
      _subscribedSlugs = await _subscriptionsService.getSubscribedSlugs();
      print('API: Loaded ${_subscribedSlugs.length} subscriptions from API');
    } catch (e) {
      print('API: Failed to fetch subscriptions - $e');
      // Continue without subscriptions - use empty set
      _subscribedSlugs = {};
    }
  }

  /// Fetch recordings for followed companies
  Future<void> _fetchFollowedRecordings() async {
    if (_subscribedSlugs.isEmpty) return;

    _isLoadingRecordings = true;
    notifyListeners();

    try {
      final followed = followedCompanies;
      final List<Recording> allRecordings = [];

      // Fetch recordings for each followed company (limit to 3 most recent per company)
      for (final company in followed) {
        try {
          final response = await _apiService.get(
            ApiConstants.companyRecordings.replaceAll(
              '{company_slug}',
              company.slug,
            ),
            queryParameters: {'limit': 3, 'offset': 0},
          );

          if (response.data is List) {
            final recordings = (response.data as List)
                .map((json) => Recording.fromJson(json as Map<String, dynamic>))
                .toList();

            // Add company info to each recording
            for (final recording in recordings) {
              allRecordings.add(recording);
            }
          }
        } catch (e) {
          // Continue with other companies if one fails
          debugPrint('Failed to fetch recordings for ${company.name}: $e');
        }
      }

      // Sort by created date (newest first)
      allRecordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Keep only the latest 10 recordings
      _followedRecordings = allRecordings.take(10).toList();
    } catch (e) {
      debugPrint('Error fetching followed recordings: $e');
    }

    _isLoadingRecordings = false;
    notifyListeners();
  }

  /// Fetch companies from API
  Future<void> _fetchCompanies() async {
    try {
      print(
        'API: Fetching companies from ${ApiConstants.getCompaniesEndpoint(offset: _currentOffset)}',
      );

      final response = await _apiService.get(
        ApiConstants.getCompaniesEndpoint(
          limit: _pageSize,
          offset: _currentOffset,
        ),
      );

      print('API: Companies response: ${response.data}');

      final companiesResponse = CompaniesResponse.fromJson(response.data);
      _totalCompanies = companiesResponse.total;

      final newCompanies = companiesResponse.companies;

      if (_currentOffset == 0) {
        _allCompanies = newCompanies;
      } else {
        _allCompanies.addAll(newCompanies);
      }

      // Sort companies: those with logo first, then by ID
      _sortCompaniesWithLogoFirst();

      // Update filtered companies
      _filteredCompanies = List.from(_allCompanies);

      // Update pagination state
      _hasMoreCompanies = _allCompanies.length < _totalCompanies;
      _currentOffset += newCompanies.length;
    } on DioException catch (e) {
      print('API: Error fetching companies - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Sort companies with logo first, then by ID
  void _sortCompaniesWithLogoFirst() {
    _allCompanies.sort((a, b) {
      // Companies with logos come first
      if (a.hasLogo && !b.hasLogo) return -1;
      if (!a.hasLogo && b.hasLogo) return 1;
      // Then sort by ID descending (newest first)
      return b.id.compareTo(a.id);
    });
  }

  /// Load more companies (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMoreCompanies) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      await _fetchCompanies();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Search companies
  Future<void> searchCompanies(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      _isSearching = false;
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    _isSearchingLoading = true;
    notifyListeners();

    try {
      print('API: Searching companies with query: $query');

      final response = await _apiService.get(
        ApiConstants.getCompanySearchEndpoint(query, limit: 20, offset: 0),
      );

      print('API: Search results: ${response.data}');

      final results = (response.data as List<dynamic>)
          .map((json) => CompanyModel.fromJson(json))
          .toList();

      _searchResults = results;
      _error = null;
    } on DioException catch (e) {
      print('API: Error searching companies - ${e.message}');
      _error = _handleError(e);
    }

    _isSearchingLoading = false;
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _isSearching = false;
    _searchResults = [];
    notifyListeners();
  }

  /// Check if a company is subscribed (by slug)
  bool isCompanySubscribed(String companySlug) {
    return _subscribedSlugs.contains(companySlug);
  }

  /// Check if a company is followed (by ID - for backward compatibility)
  bool isCompanyFollowed(int companyId) {
    // Find company by ID and check its slug
    final company = _allCompanies.where((c) => c.id == companyId).firstOrNull;
    if (company != null) {
      return _subscribedSlugs.contains(company.slug);
    }
    return false;
  }

  /// Toggle subscription status for a company (using slug)
  Future<void> toggleSubscription(String companySlug, {int? companyId}) async {
    final isCurrentlySubscribed = _subscribedSlugs.contains(companySlug);

    if (isCurrentlySubscribed) {
      // Unsubscribe
      final success = await _subscriptionsService.unsubscribe(companySlug);
      if (success) {
        _subscribedSlugs.remove(companySlug);
        // Remove recordings from unsubscribed company
        if (companyId != null) {
          _followedRecordings.removeWhere((r) => r.companyId == companyId);
        }
      }
    } else {
      // Subscribe
      final success = await _subscriptionsService.subscribe(companySlug);
      if (success) {
        _subscribedSlugs.add(companySlug);
        // Fetch recordings for the newly subscribed company
        await _fetchFollowedRecordings();
      }
    }

    notifyListeners();
  }

  /// Toggle follow status for a company (legacy method - uses ID)
  Future<void> toggleFollow(int companyId) async {
    final company = _allCompanies.where((c) => c.id == companyId).firstOrNull;
    if (company != null) {
      await toggleSubscription(company.slug, companyId: companyId);
    }
  }

  /// Refresh recordings for followed companies
  Future<void> refreshRecordings() async {
    await _fetchFollowedRecordings();
  }

  /// Refresh home data
  Future<void> refresh() async {
    await init();
  }

  /// Handle errors
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    return 'Failed to load companies';
  }
}
