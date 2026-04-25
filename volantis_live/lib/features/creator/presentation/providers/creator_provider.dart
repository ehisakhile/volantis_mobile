import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/creator_stream_model.dart';
import '../../data/services/creator_streaming_service.dart';

enum CreatorState { initial, loading, loaded, error, streaming }

class CreatorProvider extends ChangeNotifier {
  final CreatorStreamingService _service = CreatorStreamingService();

  CreatorState _state = CreatorState.initial;
  CreatorStream? _currentStream;
  List<CreatorStream> _pastStreams = [];
  List<ChatMessage> _chatMessages = [];
  StreamStats? _streamStats;
  String? _errorMessage;
  int _streamDuration = 0;
  Timer? _durationTimer;
  Timer? _viewerCountTimer;
  Timer? _chatPollingTimer;

  CreatorState get state => _state;
  CreatorStream? get currentStream => _currentStream;
  List<CreatorStream> get pastStreams => _pastStreams;
  List<ChatMessage> get chatMessages => _chatMessages;
  StreamStats? get streamStats => _streamStats;
  String? get errorMessage => _errorMessage;
  int get streamDuration => _streamDuration;
  bool get isStreaming => _currentStream?.isActive ?? false;

  Future<void> init() async {
    _state = CreatorState.loading;
    notifyListeners();

    try {
      _currentStream = await _service.getActiveStream();
      if (_currentStream != null) {
        _state = CreatorState.streaming;
        _startTimers();
      } else {
        await _loadPastStreams();
        _state = CreatorState.loaded;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = CreatorState.error;
    }
    notifyListeners();
  }

  Future<void> _loadPastStreams() async {
    try {
      _pastStreams = await _service.getUserStreams();
    } catch (e) {
      // Silently fail for past streams
    }
  }

  Future<bool> startAudioStream({
    required String title,
    String? description,
  }) async {
    _state = CreatorState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentStream = await _service.startAudioStream(
        title: title,
        description: description,
      );
      _state = CreatorState.streaming;
      _streamDuration = 0;
      _startTimers();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = CreatorState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> startVideoStream({
    required String title,
    String? description,
  }) async {
    _state = CreatorState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentStream = await _service.startVideoStream(
        title: title,
        description: description,
      );
      _state = CreatorState.streaming;
      _streamDuration = 0;
      _startTimers();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = CreatorState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopStream() async {
    if (_currentStream == null) return false;

    _state = CreatorState.loading;
    notifyListeners();

    try {
      _currentStream = await _service.stopStream(_currentStream!.slug);
      _stopTimers();
      await _loadPastStreams();
      _state = CreatorState.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = CreatorState.error;
      notifyListeners();
      return false;
    }
  }

  void _startTimers() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _streamDuration++;
      notifyListeners();
    });

    _viewerCountTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshViewerCount();
    });

    _chatPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshChat();
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _viewerCountTimer?.cancel();
    _chatPollingTimer?.cancel();
    _durationTimer = null;
    _viewerCountTimer = null;
    _chatPollingTimer = null;
  }

  Future<void> _refreshViewerCount() async {
    if (_currentStream == null) return;
    try {
      _streamStats = await _service.getViewerCount(
        _currentStream!.slug,
        _currentStream!.companyId,
      );
      notifyListeners();
    } catch (e) {
      // Silently fail for viewer count updates
    }
  }

  Future<void> _refreshChat() async {
    if (_currentStream == null) return;
    try {
      _chatMessages = await _service.getChatMessages(_currentStream!.slug);
      notifyListeners();
    } catch (e) {
      // Silently fail for chat updates
    }
  }

  Future<bool> sendChatMessage(String content) async {
    if (_currentStream == null) return false;
    try {
      final message = await _service.sendChatMessage(
        _currentStream!.slug,
        content,
      );
      _chatMessages.insert(0, message);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  String get formattedDuration {
    final hours = _streamDuration ~/ 3600;
    final minutes = (_streamDuration % 3600) ~/ 60;
    final seconds = _streamDuration % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
