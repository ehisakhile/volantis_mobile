import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../../../../services/live_stream_service.dart';
import '../../../../services/subscriptions_service.dart';
import '../../../../services/review_manager.dart';
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
  final int totalViews;
  final String? thumbnailUrl;
  final DateTime? startedAt;
  final String? whepUrl;
  final String? playbackUrl;

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
    this.totalViews = 0,
    this.thumbnailUrl,
    this.startedAt,
    this.whepUrl,
    this.playbackUrl,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    final whepUrl = json['whep_url'] ??
        json['cf_webrtc_playback_url'] ??
        json['webrtc_playback_url'];
    final playbackUrl = json['playback_url'] ??
        json['cf_webrtc_playback_url'] ??
        json['webrtc_playback_url'] ??
        json['hls_url'];

    return LiveStream(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      companyId: json['company_id'] ?? 0,
      companySlug: json['company_slug'] ?? '',
      companyName: json['company_name'] ?? '',
      companyLogoUrl: json['company_logo_url'],
      isLive: json['is_live'] ?? json['is_active'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      thumbnailUrl: json['thumbnail_url'],
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
      whepUrl: whepUrl,
      playbackUrl: playbackUrl,
    );
  }

  LiveStream copyWith({
    int? id,
    String? title,
    String? slug,
    int? companyId,
    String? companySlug,
    String? companyName,
    String? companyLogoUrl,
    bool? isLive,
    int? viewerCount,
    int? totalViews,
    String? thumbnailUrl,
    DateTime? startedAt,
    String? whepUrl,
    String? playbackUrl,
  }) {
    return LiveStream(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      companyId: companyId ?? this.companyId,
      companySlug: companySlug ?? this.companySlug,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      isLive: isLive ?? this.isLive,
      viewerCount: viewerCount ?? this.viewerCount,
      totalViews: totalViews ?? this.totalViews,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      startedAt: startedAt ?? this.startedAt,
      whepUrl: whepUrl ?? this.whepUrl,
      playbackUrl: playbackUrl ?? this.playbackUrl,
    );
  }
}

/// Streams provider for managing streams screen state
class StreamsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final LiveStreamService _liveStreamService = LiveStreamService.instance;
  final SubscriptionsService _subscriptionsService =
      SubscriptionsService.instance;

  List<LiveStream> _allStreams = [];
  List<LiveStream> _liveStreams = [];
  List<LiveStream> _filteredStreams = [];
  List<LiveStream> _followedStreams = []; // Streams from followed companies
  Set<String> _followedSlugs = {}; // Company slugs that user follows
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingFollowed = false;
  String? _error;

  // Realtime viewer counts
  int _currentViewerCount = 0;
  int _currentPeakViewers = 0;
  int _currentTotalViews = 0;
  Timer? _viewerCountPollingTimer;

  // Live stream player state
  LiveStream? _currentStream;
  CompanyLiveStreamDetail? _currentStreamDetails;
  bool _isPlayerOpen = false;
  bool _isPlayerExpanded = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isConnecting = false;
  String? _playerError;
  StreamSubscription? _streamSubscription;

  StreamsProvider() {
    _streamSubscription = _liveStreamService.stateStream.listen(
      _onStreamStateChanged,
    );
  }

  void _onStreamStateChanged(LiveStreamState state) {
    _isPlaying = state.isPlaying;
    _isMuted = state.isMuted;
    _playerError = state.error;
    if (state.liveStream != null) {
      _currentStream = LiveStream(
        id: state.liveStream!.id,
        title: state.liveStream!.title,
        slug: state.liveStream!.slug,
        companyId: state.liveStream!.companyId,
        companySlug: state.liveStream!.companySlug,
        companyName: state.liveStream!.companyName,
        companyLogoUrl: state.liveStream!.companyLogoUrl,
        isLive: state.liveStream!.isLive,
        viewerCount: state.liveStream!.viewerCount,
        totalViews: state.liveStream!.totalViews,
        thumbnailUrl: state.liveStream!.thumbnailUrl,
        startedAt: state.liveStream!.startedAt,
        whepUrl: state.liveStream!.whepUrl,
        playbackUrl: state.liveStream!.playbackUrl,
      );
    } else if (!_isPlayerOpen) {
      _currentStream = null;
    }
    notifyListeners();
  }

  // Getters
  List<LiveStream> get allStreams => _allStreams;
  List<LiveStream> get liveStreams => _liveStreams;
  List<LiveStream> get filteredStreams => _filteredStreams;
  List<LiveStream> get followedStreams => _followedStreams;
  Set<String> get followedSlugs => _followedSlugs;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isLoadingFollowed => _isLoadingFollowed;
  String? get error => _error;
  int get currentViewerCount => _currentViewerCount;
  int get currentPeakViewers => _currentPeakViewers;
  int get currentTotalViews => _currentTotalViews;

  /// Get streams sorted with followed channels first
  List<LiveStream> get streamsWithFollowedFirst {
    if (_followedSlugs.isEmpty || _filteredStreams.isEmpty) {
      return _filteredStreams;
    }

    final followed = <LiveStream>[];
    final notFollowed = <LiveStream>[];

    for (final stream in _filteredStreams) {
      if (_followedSlugs.contains(stream.companySlug)) {
        followed.add(stream);
      } else {
        notFollowed.add(stream);
      }
    }

    return [...followed, ...notFollowed];
  }

  // Player getters
  LiveStream? get currentStream => _currentStream;
  CompanyLiveStreamDetail? get currentStreamDetails => _currentStreamDetails;
  bool get isPlayerOpen => _isPlayerOpen;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  bool get isConnecting => _isConnecting;
  String? get playerError => _playerError;
  bool get hasActivePlayer => _isPlayerOpen && _currentStream != null;

  /// Initialize streams data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch subscriptions first to know which companies user follows
      await _fetchSubscriptions();

      // Then fetch streams
      await _fetchActiveStreams();

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch user's subscriptions to know which companies they follow
  Future<void> _fetchSubscriptions() async {
    try {
      _isLoadingFollowed = true;
      notifyListeners();

      _followedSlugs = await _subscriptionsService.getSubscribedSlugs();
      print('API: Loaded ${_followedSlugs.length} followed company slugs');

      _isLoadingFollowed = false;
    } catch (e) {
      print('API: Failed to fetch subscriptions - $e');
      _followedSlugs = {};
      _isLoadingFollowed = false;
    }
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

      // Update followed streams list
      _followedStreams = getFollowedStreams();
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
    try {
      // Force refresh subscriptions from API. Network failures are handled here
      // so pull-to-refresh does not surface as an unhandled Flutter exception.
      await _subscriptionsService.getSubscriptions(forceRefresh: true);
      await _fetchSubscriptions();
      await _fetchActiveStreams();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('API: Refresh streams failed - $e');
      notifyListeners();
    }
  }

  /// Refresh subscriptions only
  Future<void> refreshSubscriptions() async {
    try {
      await _subscriptionsService.getSubscriptions(forceRefresh: true);
      await _fetchSubscriptions();
    } catch (e) {
      print('API: Refresh subscriptions failed - $e');
    }
    notifyListeners();
  }

  /// Check if a stream is from a followed company
  bool isStreamFromFollowedCompany(String companySlug) {
    return _followedSlugs.contains(companySlug);
  }

  /// Get streams from followed companies
  List<LiveStream> getFollowedStreams() {
    if (_followedSlugs.isEmpty) return [];
    return _allStreams
        .where((stream) => _followedSlugs.contains(stream.companySlug))
        .toList();
  }

  /// Get live streams from followed companies
  List<LiveStream> getLiveFollowedStreams() {
    return getFollowedStreams().where((stream) => stream.isLive).toList();
  }

  /// Handle errors
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    return 'Failed to load streams';
  }

  /// Immediately set player state to open & connecting so UI presents instant feedback
  bool prepareStream(LiveStream stream) {
    if (_liveStreamService.isStreamPlaying(stream.id)) {
      _isPlayerOpen = true;
      _isPlayerExpanded = true;
      notifyListeners();
      return true; // Indicates same stream already playing
    }

    _currentStream = stream;
    _isPlayerOpen = true;
    _isPlayerExpanded = true;
    _isPlaying = false;
    _isConnecting = true;
    _error = null;
    notifyListeners();
    return false;
  }

  /// Open a stream - handles single stream logic
  /// If same stream is already playing, shows continue listening
  /// If different stream, closes old one and plays new
  Future<bool> openStream(LiveStream stream) async {
    // Check if this is the same stream that's already playing
    if (_liveStreamService.isStreamPlaying(stream.id)) {
      // Same stream - show continue listening
      _isPlayerOpen = true;
      _isPlayerExpanded = true;
      _isPlaying = true;
      notifyListeners();
      return true; // Indicates same stream (continue listening)
    }

    // Different stream - close old one and play new (ensures single stream)
    _currentStream = stream;
    _isPlayerOpen = true;
    _isPlayerExpanded = true;
    _isPlaying = true;
    _isConnecting = true;
    _error = null;

    String? whepUrl = stream.whepUrl ?? stream.playbackUrl;

    // If WHEP URL is missing from the initial stream model, pre-fetch stream details from API
    if (whepUrl == null || whepUrl.isEmpty || whepUrl.contains('fake-stream.local')) {
      try {
        print('API: WHEP URL missing for ${stream.slug}, pre-fetching stream details...');
        final res = await _apiService.get(ApiConstants.getStreamEndpoint(stream.slug));
        if (res.data != null && res.data is Map<String, dynamic>) {
          final data = res.data as Map<String, dynamic>;
          whepUrl = data['cf_webrtc_playback_url'] ??
              data['webrtc_playback_url'] ??
              data['whep_url'] ??
              data['playback_url'];

          if (whepUrl != null && whepUrl.isNotEmpty) {
            _currentStream = stream.copyWith(
              whepUrl: whepUrl,
              playbackUrl: whepUrl,
            );
          }
        }
      } catch (e) {
        print('API: Error pre-fetching stream details for ${stream.slug}: $e');
      }
    }

    final activeStream = _currentStream ?? stream;

    // Convert to LiveStreamData and start stream
    final liveStreamData = LiveStreamData(
      id: activeStream.id,
      title: activeStream.title,
      slug: activeStream.slug,
      companyId: activeStream.companyId,
      companySlug: activeStream.companySlug,
      companyName: activeStream.companyName,
      companyLogoUrl: activeStream.companyLogoUrl,
      isLive: activeStream.isLive,
      viewerCount: activeStream.viewerCount,
      totalViews: activeStream.totalViews,
      thumbnailUrl: activeStream.thumbnailUrl,
      startedAt: activeStream.startedAt,
      whepUrl: whepUrl ?? activeStream.whepUrl,
      playbackUrl: whepUrl ?? activeStream.playbackUrl,
    );

    await _liveStreamService.switchStream(liveStreamData);

    _currentStream ??= activeStream;

    await startListeningToStream(activeStream.slug);

    notifyListeners();
    return false; // Indicates new stream
  }

  /// Check if a stream is currently playing
  bool isStreamPlaying(int streamId) {
    return _liveStreamService.isStreamPlaying(streamId);
  }

  /// Set stream details after fetching from API
  void setStreamDetails(CompanyLiveStreamDetail details) {
    _currentStreamDetails = details;
    notifyListeners();
  }

  /// Update connection state from WebRTC player
  void updateConnectionState({
    bool? isConnecting,
    bool? isPlaying,
    bool? isMuted,
    String? error,
  }) {
    if (isConnecting != null) _isConnecting = isConnecting;
    if (isPlaying != null) _isPlaying = isPlaying;
    if (isMuted != null) _isMuted = isMuted;
    if (error != null) _error = error;
    notifyListeners();
  }

  /// Minimize player to mini-player mode
  void minimize() {
    _isPlayerExpanded = false;
    notifyListeners();
  }

  /// Expand player to full-screen mode
  void expand() {
    _isPlayerExpanded = true;
    notifyListeners();
  }

  /// Close the player
  Future<void> closePlayer() async {
    // Stop polling first
    _stopViewerCountPolling();

    // This will cleanup WebRTC via the callback and stop the stream
    await _liveStreamService.stopStream();
    _isPlayerOpen = false;
    _isPlayerExpanded = true;
    _isPlaying = false;
    _isConnecting = false;
    _currentStream = null;
    _currentStreamDetails = null;
    _currentViewerCount = 0;
    _currentPeakViewers = 0;
    _currentTotalViews = 0;
    notifyListeners();

    debugPrint('Player closed, notifying ReviewManager of livestream end');

    ReviewManager().onLivestreamEnded();
  }

  /// Toggle play/pause
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    _liveStreamService.togglePlayPause();
    notifyListeners();
  }

  /// Toggle mute state (for UI, actual mute handled by WebRTC)
  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _viewerCountPollingTimer?.cancel();
    super.dispose();
  }

  /// Start listening to a stream - calls the API to record the view
  /// This should be called when the user starts playing a stream
  Future<void> startListeningToStream(String slug) async {
    try {
      print('API: Starting listen for stream $slug');

      final response = await _apiService.get(
        ApiConstants.getStreamEndpoint(slug),
      );

      final data = response.data as Map<String, dynamic>;
      _currentViewerCount = data['viewer_count'] ?? 0;
      _currentPeakViewers = data['peak_viewers'] ?? 0;
      _currentTotalViews = data['total_views'] ?? 0;

      print(
        'API: Stream data - viewer_count: $_currentViewerCount, total_views: $_currentTotalViews',
      );

      // Start polling for realtime updates
      _startViewerCountPolling(slug);

      notifyListeners();
    } on DioException catch (e) {
      print('API: Error starting listen - ${e.message}');
      // Still try to poll for counts even if this fails
      _startViewerCountPolling(slug);
    }
  }

  /// Fetch realtime viewer counts for a stream
  Future<void> _fetchRealtimeViewerCounts(String slug) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getStreamRealtimeEndpoint(slug),
      );

      final data = response.data as Map<String, dynamic>;
      final newViewerCount = data['viewer_count'] ?? 0;
      final newPeakViewers = data['peak_viewers'] ?? 0;
      final newTotalViews = data['total_views'] ?? 0;

      // Only update and notify if values changed
      if (_currentViewerCount != newViewerCount ||
          _currentTotalViews != newTotalViews) {
        _currentViewerCount = newViewerCount;
        _currentPeakViewers = newPeakViewers;
        _currentTotalViews = newTotalViews;

        if (_currentStream != null) {
          _currentStream = _currentStream!.copyWith(
            viewerCount: _currentViewerCount,
            totalViews: _currentTotalViews,
          );
        }

        notifyListeners();
        print(
          'API: Realtime update - viewer_count: $_currentViewerCount, total_views: $_currentTotalViews',
        );
      }
    } catch (e) {
      print('API: Error fetching realtime counts - $e');
    }
  }

  /// Start polling for realtime viewer counts
  void _startViewerCountPolling(String slug) {
    _viewerCountPollingTimer?.cancel();
    _viewerCountPollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchRealtimeViewerCounts(slug),
    );
  }

  /// Stop polling when stream is closed
  void _stopViewerCountPolling() {
    _viewerCountPollingTimer?.cancel();
    _viewerCountPollingTimer = null;
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
}
