import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../../../../services/followed_companies_service.dart';
import '../../data/models/company_model.dart';

/// Home provider for managing home screen state - Companies listing
class HomeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final FollowedCompaniesService _followedCompaniesService =
      FollowedCompaniesService.instance;

  // Companies data
  List<CompanyModel> _allCompanies = [];
  List<CompanyModel> _filteredCompanies = [];
  List<CompanyModel> _searchResults = [];
  Set<int> _followedCompanyIds = {};

  // Pagination
  int _currentOffset = 0;
  int _totalCompanies = 0;
  bool _hasMoreCompanies = true;
  static const int _pageSize = 50;

  // Search
  String _searchQuery = '';
  bool _isSearching = false;

  // State
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSearchingLoading = false;
  String? _error;

  // Getters
  List<CompanyModel> get companies => _filteredCompanies;
  List<CompanyModel> get searchResults => _searchResults;
  List<CompanyModel> get followedCompanies =>
      _allCompanies.where((c) => _followedCompanyIds.contains(c.id)).toList();
  Set<int> get followedCompanyIds => _followedCompanyIds;
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
      // Load followed companies from local storage
      _followedCompanyIds = await _followedCompaniesService
          .getFollowedCompanyIds();

      // Fetch companies
      await _fetchCompanies();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
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

  /// Check if a company is followed
  bool isCompanyFollowed(int companyId) {
    return _followedCompanyIds.contains(companyId);
  }

  /// Toggle follow status for a company
  Future<void> toggleFollow(int companyId) async {
    final isFollowed = await _followedCompaniesService.toggleFollow(companyId);

    if (isFollowed) {
      _followedCompanyIds.add(companyId);
    } else {
      _followedCompanyIds.remove(companyId);
    }

    notifyListeners();
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
