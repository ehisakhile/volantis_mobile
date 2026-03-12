import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../../../streams/presentation/providers/streams_provider.dart';

/// Home provider for managing home screen state
class HomeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  
  List<LiveStream> _liveStreams = [];
  List<LiveStream> _recentStreams = [];
  LiveStream? _currentlyListening;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LiveStream> get liveStreams => _liveStreams;
  List<LiveStream> get recentStreams => _recentStreams;
  LiveStream? get currentlyListening => _currentlyListening;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCurrentlyListening => _currentlyListening != null;

  /// Initialize home data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _fetchLiveStreams();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch live streams
  Future<void> _fetchLiveStreams() async {
    try {
      print('API: Fetching home live streams from ${ApiConstants.activeLivestreams}');
      
      final response = await _apiService.get(ApiConstants.activeLivestreams);
      
      print('API: Home streams response: ${response.data}');
      
      final data = response.data as Map<String, dynamic>;
      final streams = data['streams'] as List<dynamic>? ?? [];
      
      _liveStreams = streams.map((json) => LiveStream.fromJson(json)).toList();
      
      // Use all live streams as recent for now
      _recentStreams = _liveStreams;
      
    } on DioException catch (e) {
      print('API: Error fetching home streams - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Set currently listening stream
  void setCurrentlyListening(LiveStream stream) {
    _currentlyListening = stream;
    notifyListeners();
  }

  /// Clear currently listening
  void clearCurrentlyListening() {
    _currentlyListening = null;
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
    return 'Failed to load streams';
  }
}