import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'creator_streaming_service.dart';

enum RecordingFormat { mp4, m4a, webm }

enum RecordingPromptState { notAsked, asked, accepted, acceptedWithAutoUpload, declined }

class StreamRecorderState {
  final RecordingPromptState promptState;
  final bool isRecording;
  final Duration recordingDuration;
  final String? recordedFilePath;
  final bool isUploading;
  final double uploadProgress;
  final bool isUploaded;
  final String? uploadedUrl;
  final String? errorMessage;

  const StreamRecorderState({
    this.promptState = RecordingPromptState.notAsked,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.recordedFilePath,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.isUploaded = false,
    this.uploadedUrl,
    this.errorMessage,
  });

  bool get autoUpload => promptState == RecordingPromptState.acceptedWithAutoUpload;

  StreamRecorderState copyWith({
    RecordingPromptState? promptState,
    bool? isRecording,
    Duration? recordingDuration,
    String? recordedFilePath,
    bool? isUploading,
    double? uploadProgress,
    bool? isUploaded,
    String? uploadedUrl,
    String? errorMessage,
    bool clearFilePath = false,
    bool clearUploadedUrl = false,
    bool clearError = false,
  }) {
    return StreamRecorderState(
      promptState: promptState ?? this.promptState,
      isRecording: isRecording ?? this.isRecording,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      recordedFilePath: clearFilePath ? null : (recordedFilePath ?? this.recordedFilePath),
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadedUrl: clearUploadedUrl ? null : (uploadedUrl ?? this.uploadedUrl),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class StreamRecorder extends ChangeNotifier {
  final CreatorStreamingService _streamingService;

  StreamRecorderState _state = const StreamRecorderState();
  Timer? _durationTimer;
  String? _currentSlug;

  final _stateController = BehaviorSubject<StreamRecorderState>.seeded(
    const StreamRecorderState(),
  );

  StreamRecorder({CreatorStreamingService? streamingService})
      : _streamingService = streamingService ?? CreatorStreamingService();

  Stream<StreamRecorderState> get stateStream => _stateController.stream;
  StreamRecorderState get currentState => _stateController.value;

  bool get wantsToRecord {
    final s = _state.promptState;
    return s == RecordingPromptState.accepted || s == RecordingPromptState.acceptedWithAutoUpload;
  }

  bool get isRecording => _state.isRecording;
  Duration get recordingDuration => _state.recordingDuration;
  String? get recordedFilePath => _state.recordedFilePath;
  bool get isUploading => _state.isUploading;
  double get uploadProgress => _state.uploadProgress;
  bool get isUploaded => _state.isUploaded;
  bool get autoUpload => _state.autoUpload;

  void promptRecording() {
    _updateState(_state.copyWith(
      promptState: RecordingPromptState.asked,
      clearError: true,
    ));
  }

  void acceptRecording() {
    _updateState(_state.copyWith(
      promptState: RecordingPromptState.accepted,
      clearError: true,
    ));
  }

  void acceptRecordingWithAutoUpload() {
    _updateState(_state.copyWith(
      promptState: RecordingPromptState.acceptedWithAutoUpload,
      clearError: true,
    ));
  }

  void declineRecording() {
    _updateState(_state.copyWith(
      promptState: RecordingPromptState.declined,
      clearError: true,
    ));
  }

  Future<bool> startRecording({String? slug}) async {
    if (_state.promptState != RecordingPromptState.accepted &&
        _state.promptState != RecordingPromptState.acceptedWithAutoUpload) {
      _updateState(_state.copyWith(
        errorMessage: 'Recording not accepted by user',
      ));
      return false;
    }

    try {
      _currentSlug = slug;

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final format = _getFormatExtension(RecordingFormat.m4a);
      final filePath = '${directory.path}/recording_$timestamp.$format';

      _updateState(_state.copyWith(
        isRecording: true,
        recordingDuration: Duration.zero,
        recordedFilePath: filePath,
        clearError: true,
      ));

      _startDurationTimer();
      return true;
    } catch (e) {
      _updateState(_state.copyWith(
        errorMessage: 'Failed to start recording: $e',
      ));
      return false;
    }
  }

  Future<bool> stopRecording() async {
    if (!_state.isRecording) {
      return false;
    }

    try {
      _stopDurationTimer();

      final path = _state.recordedFilePath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          _updateState(_state.copyWith(
            isRecording: false,
            recordedFilePath: path,
          ));

          if (_state.autoUpload && _currentSlug != null) {
            await uploadRecording();
          }
          return true;
        }
      }

      _updateState(_state.copyWith(
        isRecording: false,
        errorMessage: 'Recording file not found',
      ));
      return false;
    } catch (e) {
      _stopDurationTimer();
      _updateState(_state.copyWith(
        isRecording: false,
        errorMessage: 'Failed to stop recording: $e',
      ));
      return false;
    }
  }

  Future<bool> uploadRecording({String? slug, String? description}) async {
    if (_state.recordedFilePath == null) {
      _updateState(_state.copyWith(
        errorMessage: 'No recording file available',
      ));
      return false;
    }

    final targetSlug = slug ?? _currentSlug;
    if (targetSlug == null) {
      _updateState(_state.copyWith(
        errorMessage: 'No stream slug available for upload',
      ));
      return false;
    }

    try {
      _updateState(_state.copyWith(
        isUploading: true,
        uploadProgress: 0.0,
        clearError: true,
      ));

      final recording = File(_state.recordedFilePath!);
      final durationSeconds = _state.recordingDuration.inSeconds;

      final url = await _streamingService.uploadRecording(
        slug: targetSlug,
        recording: recording,
        description: description,
        durationSeconds: durationSeconds > 0 ? durationSeconds : null,
      );

      _updateState(_state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        isUploaded: true,
        uploadedUrl: url,
      ));

      return true;
    } catch (e) {
      _updateState(_state.copyWith(
        isUploading: false,
        uploadProgress: 0.0,
        errorMessage: 'Upload failed: $e',
      ));
      return false;
    }
  }

  Future<bool> downloadRecording({String? destinationPath}) async {
    if (_state.recordedFilePath == null) {
      _updateState(_state.copyWith(
        errorMessage: 'No recording file available',
      ));
      return false;
    }

    try {
      final sourceFile = File(_state.recordedFilePath!);
      if (!await sourceFile.exists()) {
        _updateState(_state.copyWith(
          errorMessage: 'Recording file not found',
        ));
        return false;
      }

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        _updateState(_state.copyWith(
          errorMessage: 'Could not access downloads directory',
        ));
        return false;
      }

      final fileName = _state.recordedFilePath!.split('/').last;
      final targetPath = destinationPath ?? '${downloadsDir.path}/$fileName';

      await sourceFile.copy(targetPath);
      return true;
    } catch (e) {
      _updateState(_state.copyWith(
        errorMessage: 'Download failed: $e',
      ));
      return false;
    }
  }

  void reset() {
    _stopDurationTimer();
    _currentSlug = null;
    _updateState(const StreamRecorderState());
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateState(_state.copyWith(
        recordingDuration: _state.recordingDuration + const Duration(seconds: 1),
      ));
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _updateState(StreamRecorderState newState) {
    _state = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  String _getFormatExtension(RecordingFormat format) {
    switch (format) {
      case RecordingFormat.mp4:
        return 'mp4';
      case RecordingFormat.m4a:
        return 'm4a';
      case RecordingFormat.webm:
        return 'webm';
    }
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _stateController.close();
    super.dispose();
  }
}