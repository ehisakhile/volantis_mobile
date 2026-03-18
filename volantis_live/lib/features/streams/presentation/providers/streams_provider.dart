import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../../data/models/company_live_stream_model.dart';

/// LiveStream model for API response
class LiveStream {
  final int id;
  final String title;
  final String slug;
  final int companyId;
  final String companySlug;
  final String companyName;
  final String? companyLogoUrl;
  final bool isLive;
  final int viewerCount;
  final String? thumbnailUrl;
  final DateTime? startedAt;

  LiveStream({
    required this.id,
    required this.title,
    required this.slug,
    required this.companyId,
    required this.companySlug,
    required this.companyName,
    this.companyLogoUrl,
    required this.isLive,
    required this.viewerCount,
    this.thumbnailUrl,
    this.startedAt,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      companyId: json['company_id'] ?? 0,
      companySlug: json['company_slug'] ?? '',
      companyName: json['company_name'] ?? '',
      companyLogoUrl: json['company_logo_url'],
      isLive: json['is_live'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      thumbnailUrl: json['thumbnail_url'],
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
    );
  }
}

/// Streams provider for managing streams screen state
class StreamsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<LiveStream> _allStreams = [];
  List<LiveStream> _liveStreams = [];
  List<LiveStream> _filteredStreams = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LiveStream> get allStreams => _allStreams;
  List<LiveStream> get liveStreams => _liveStreams;
  List<LiveStream> get filteredStreams => _filteredStreams;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize streams data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _fetchActiveStreams();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch all active livestreams
  Future<void> _fetchActiveStreams() async {
    try {
      print(
        'API: Fetching active livestreams from ${ApiConstants.activeLivestreams}',
      );

      final response = await _apiService.get(ApiConstants.activeLivestreams);

      print('API: Active streams response: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      final streams = data['streams'] as List<dynamic>? ?? [];

      _allStreams = streams.map((json) => LiveStream.fromJson(json)).toList();
      _liveStreams = _allStreams.where((s) => s.isLive).toList();
      _filteredStreams = _allStreams;
    } on DioException catch (e) {
      print('API: Error fetching streams - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Search streams
  void searchStreams(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredStreams = _allStreams;
    } else {
      _filteredStreams = _allStreams.where((stream) {
        final titleLower = stream.title.toLowerCase();
        final companyLower = stream.companyName.toLowerCase();
        final queryLower = query.toLowerCase();
        return titleLower.contains(queryLower) ||
            companyLower.contains(queryLower);
      }).toList();
    }
    notifyListeners();
  }

  /// Refresh streams
  Future<void> refresh() async {
    await init();
  }

  /// Handle errors
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    return 'Failed to load streams';
  }

  /// Fetch company live stream details by company slug
  /// This is used when user taps on a stream to get the playback URL
  Future<CompanyLiveStream?> getCompanyLiveStream(String companySlug) async {
    try {
      print(
        'API: Fetching company live stream from ${ApiConstants.getCompanyLiveEndpoint(companySlug)}',
      );

      final response = await _apiService.get(
        ApiConstants.getCompanyLiveEndpoint(companySlug),
      );

      print('API: Company live stream response: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      return CompanyLiveStream.fromJson(data);
    } on DioException catch (e) {
      print('API: Error fetching company live stream - ${e.message}');
      throw _handleError(e);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
