import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../../../../services/subscriptions_service.dart';
import '../../../recordings/data/models/recording_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/recommendations_model.dart';

/// Home recording with company info attached
class HomeRecording {
  final int id;
  final int companyId;
  final String companySlug;
  final String companyName;
  final int? livestreamId;
  final String title;
  final String? description;
  final String s3Url;
  final String streamingUrl;
  final List<int>? categoryIds;
  final int? durationSeconds;
  final int? fileSizeBytes;
  final bool isProcessed;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final int? replayCount;
  final String? watchStatus;

  const HomeRecording({
    required this.id,
    required this.companyId,
    required this.companySlug,
    required this.companyName,
    this.livestreamId,
    required this.title,
    this.description,
    required this.s3Url,
    required this.streamingUrl,
    this.categoryIds,
    this.durationSeconds,
    this.fileSizeBytes,
    this.isProcessed = true,
    this.thumbnailUrl,
    required this.createdAt,
    this.replayCount,
    this.watchStatus,
  });

  factory HomeRecording.fromJson(Map<String, dynamic> json, String companySlug) {
    return HomeRecording(
      id: json['id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      companySlug: companySlug,
      companyName: '', // Will be populated from company lookup
      livestreamId: json['livestream_id'] as int?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      s3Url: json['s3_url'] as String? ?? '',
      streamingUrl: json['streaming_url'] as String? ?? '',
      categoryIds: (json['category_ids'] as List<dynamic>?)?.cast<int>(),
      durationSeconds: json['duration_seconds'] as int?,
      fileSizeBytes: json['file_size_bytes'] as int?,
      isProcessed: json['is_processed'] as bool? ?? false,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      replayCount: json['replay_count'] as int?,
      watchStatus: json['watch_status'] as String?,
    );
  }

  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final seconds = durationSeconds! % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

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

  // Recommendations from API
  RecommendationsResponse? _recommendations;
  bool _isLoadingRecommendations = false;

  // Public Recordings (fetched from subscribed company endpoints)
  List<HomeRecording> _homeRecordings = [];
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
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isLoadingRecordings => _isLoadingRecordings;
  RecommendationsResponse? get recommendations => _recommendations;
  List<RecommendedCompany> get recommendedCompanies =>
      _recommendations?.recommendedCompanies ?? [];
  List<SubscribedLivestream> get subscribedLivestreams =>
      _recommendations?.subscribedLivestreams ?? [];
  List<SubscribedRecording> get subscribedRecordings =>
      _recommendations?.subscribedRecordings ?? [];
  List<HomeRecording> get homeRecordings => _homeRecordings;
  bool get hasRecordings => _homeRecordings.isNotEmpty;
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
    _homeRecordings = [];
    notifyListeners();

    try {
      // Fetch subscriptions from API
      await _fetchSubscriptions();

      // Fetch companies
      await _fetchCompanies();

      // Fetch recommendations from API
      await _fetchRecommendations();

      // Fetch public recordings from subscribed companies
      await _fetchPublicRecordingsFromSubscriptions();

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

  /// Fetch recommendations from API
  Future<void> _fetchRecommendations() async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.recommendations);
      _recommendations = RecommendationsResponse.fromJson(response.data);
      print('API: Recommendations loaded successfully');
    } catch (e) {
      debugPrint('API: Error fetching recommendations - $e');
      _recommendations = null;
    }

    _isLoadingRecommendations = false;
    notifyListeners();
  }

  /// Fetch public recordings from subscribed companies
  Future<void> _fetchPublicRecordingsFromSubscriptions() async {
    if (_subscribedSlugs.isEmpty) {
      _homeRecordings = [];
      notifyListeners();
      return;
    }

    _isLoadingRecordings = true;
    notifyListeners();

    try {
      final List<HomeRecording> allRecordings = [];

      // Fetch recordings from ALL subscribed companies
      for (final slug in _subscribedSlugs) {
        try {
          final response = await _apiService.get(
            '/recordings/public/company/$slug',
            queryParameters: {'limit': 10, 'offset': 0},
          );

          final recordingsList = (response.data as List)
              .map((j) => HomeRecording.fromJson(j as Map<String, dynamic>, slug))
              .toList();

          allRecordings.addAll(recordingsList);
        } catch (e) {
          // Skip companies that fail
          print('API: Failed to fetch recordings for $slug - $e');
        }
      }

      // Sort by created date, newest first
      allRecordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Take top 20
      _homeRecordings = allRecordings.take(20).toList();
      print('API: Home recordings loaded: ${_homeRecordings.length}');
    } catch (e) {
      debugPrint('API: Error fetching public recordings - $e');
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

  /// Check if a company has an active livestream
  bool companyHasActiveLivestream(String companySlug) {
    return _recommendations?.subscribedLivestreams
            .any((livestream) => livestream.companySlug == companySlug) ??
        false;
  }

  /// Toggle subscription status for a company (using slug)
  Future<void> toggleSubscription(String companySlug, {int? companyId}) async {
    final isCurrentlySubscribed = _subscribedSlugs.contains(companySlug);

    if (isCurrentlySubscribed) {
      // Unsubscribe
      final success = await _subscriptionsService.unsubscribe(companySlug);
      if (success) {
        _subscribedSlugs.remove(companySlug);
      }
    } else {
      // Subscribe
      final success = await _subscriptionsService.subscribe(companySlug);
      if (success) {
        _subscribedSlugs.add(companySlug);
        // Refresh recommendations after subscribing
        await _fetchRecommendations();
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

  /// Refresh recommendations
  Future<void> refreshRecordings() async {
    await _fetchRecommendations();
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
