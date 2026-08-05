import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'whep_audio_handler.dart';

enum AudioSourceType {
  none,
  liveStream,
  recording,
}

class AudioState {
  final AudioSourceType sourceType;
  final String? title;
  final String? artist;
  final String? artworkUrl;
  final bool isPlaying;
  final bool isConnecting;
  final String? error;
  final Duration? position;
  final Duration? duration;
  final bool isLive;
  final int? sourceId;

  const AudioState({
    this.sourceType = AudioSourceType.none,
    this.title,
    this.artist,
    this.artworkUrl,
    this.isPlaying = false,
    this.isConnecting = false,
    this.error,
    this.position,
    this.duration,
    this.isLive = false,
    this.sourceId,
  });

  AudioState copyWith({
    AudioSourceType? sourceType,
    String? title,
    String? artist,
    String? artworkUrl,
    bool? isPlaying,
    bool? isConnecting,
    String? error,
    Duration? position,
    Duration? duration,
    bool? isLive,
    int? sourceId,
    bool clearError = false,
  }) {
    return AudioState(
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isPlaying: isPlaying ?? this.isPlaying,
      isConnecting: isConnecting ?? this.isConnecting,
      error: clearError ? null : (error ?? this.error),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLive: isLive ?? this.isLive,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  bool get hasActivePlayback => sourceType != AudioSourceType.none;
}

class AudioManager extends ChangeNotifier {
  static AudioManager? _instance;
  static AudioManager get instance {
    _instance ??= AudioManager._();
    return _instance!;
  }

  AudioManager._();

  final _stateController = StreamController<AudioState>.broadcast();
  Stream<AudioState> get stateStream => _stateController.stream;

  AudioState _currentState = const AudioState();
  AudioState get currentState => _currentState;

  WhepAudioHandler? _whepHandler;
  WhepAudioHandler? get whepHandler => _whepHandler;

  AudioPlayer? _recordingPlayer;
  AudioSession? _audioSession;
  bool _isInitialized = false;

  StreamSubscription? _recordingPositionSubscription;
  StreamSubscription? _recordingStateSubscription;
  Timer? _positionTimer;
  static const _positionInterval = Duration(seconds: 30);

  AudioSourceType get currentSourceType => _currentState.sourceType;
  bool get isPlaying => _currentState.isPlaying;
  bool get hasActivePlayback => _currentState.sourceType != AudioSourceType.none;
  bool get isLiveStreamActive => _currentState.sourceType == AudioSourceType.liveStream;
  bool get isRecordingActive => _currentState.sourceType == AudioSourceType.recording;

  Duration get position => _recordingPlayer?.position ?? Duration.zero;
  Duration? get duration => _recordingPlayer?.duration;

  Stream<Duration?> get positionStream =>
      _recordingPlayer?.positionStream ?? Stream.value(Duration.zero);
  Stream<Duration?> get durationStream =>
      _recordingPlayer?.durationStream ?? Stream.value(null);

  double get progress {
    if (duration == null || duration!.inSeconds == 0) return 0.0;
    return position.inSeconds / duration!.inSeconds;
  }

  Future<void> init({required WhepAudioHandler whepHandler}) async {
    if (_isInitialized) return;

    _whepHandler = whepHandler;
    _recordingPlayer = AudioPlayer();

    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      _recordingPlayer!.playerStateStream.listen(_onRecordingPlayerState);
      _recordingPlayer!.positionStream.listen(_onRecordingPosition);
      _whepHandler?.playbackState.listen(_onLiveStreamState);

      _isInitialized = true;
      debugPrint('AudioManager initialized');
    } catch (e) {
      debugPrint('Error initializing AudioManager: $e');
    }
  }

  void _onRecordingPlayerState(PlayerState state) {
    if (_currentState.sourceType != AudioSourceType.recording) return;

    final isConnecting = state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
    final isPlaying = state.playing;

    if (state.processingState == ProcessingState.completed) {
      _stopPositionTimer();
      _currentState = _currentState.copyWith(
        isPlaying: false,
        isConnecting: false,
        sourceType: AudioSourceType.none,
      );
      _whepHandler?.resetToLiveStreamMode();
    } else {
      if (isPlaying) {
        _startPositionTimer();
      } else {
        _stopPositionTimer();
      }
      
      _currentState = _currentState.copyWith(
        isPlaying: isPlaying,
        isConnecting: isConnecting,
      );
      _whepHandler?.updateRecordingPlaybackState(
        playing: isPlaying,
        position: _recordingPlayer?.position,
        bufferedPosition: _recordingPlayer?.bufferedPosition,
        speed: _recordingPlayer?.speed ?? 1.0,
      );
    }
    _stateController.add(_currentState);
    notifyListeners();
  }

  void _onLiveStreamState(PlaybackState state) {
    if (_currentState.sourceType != AudioSourceType.liveStream) return;

    final isConnecting = state.processingState == AudioProcessingState.loading ||
        state.processingState == AudioProcessingState.buffering ||
        state.processingState == AudioProcessingState.error; // We auto-reconnect on error, so it's still connecting

    final isPlaying = state.playing || isConnecting; // If connecting, we consider it "trying to play"

    if (state.processingState == AudioProcessingState.completed) {
      _currentState = _currentState.copyWith(
        isPlaying: false,
        isConnecting: false,
        sourceType: AudioSourceType.none,
        error: 'stream_ended',
      );
      _whepHandler?.resetToLiveStreamMode();
    } else {
      _currentState = _currentState.copyWith(
        isPlaying: isPlaying,
        isConnecting: isConnecting,
      );
    }
    _stateController.add(_currentState);
    notifyListeners();
  }

  void _onRecordingPosition(Duration position) {
    _currentState = _currentState.copyWith(position: position);
    _stateController.add(_currentState);
  }

  Future<void> _stopAllAndClear({bool clearSourceType = true}) async {
    debugPrint('[AudioManager] _stopAllAndClear() called');

    if (_currentState.sourceType == AudioSourceType.recording) {
      _stopPositionTimer();
      if (_recordingPlayer != null) {
        await _recordingPlayer!.stop();
      }
    }

    if (_currentState.sourceType == AudioSourceType.liveStream) {
      _whepHandler?.unregisterExternalPlaybackControls();
      _whepHandler?.resetToLiveStreamMode();
      await _whepHandler?.stop();
    }

    _whepHandler?.unregisterExternalPlaybackControls();

    if (clearSourceType) {
      _currentState = const AudioState();
    } else {
      _currentState = _currentState.copyWith(
        isPlaying: false,
        isConnecting: false,
        sourceType: AudioSourceType.none,
      );
    }
    _stateController.add(_currentState);
    notifyListeners();
  }

  Future<void> playLiveStream({
    required String streamUrl,
    required String title,
    required String artist,
    String? artworkUrl,
    int? streamId,
  }) async {
    debugPrint('[AudioManager] Playing live stream: $title');

    try {
      await _stopAllAndClear(clearSourceType: false);

      _currentState = AudioState(
        sourceType: AudioSourceType.liveStream,
        title: title,
        artist: artist,
        artworkUrl: artworkUrl,
        isConnecting: true,
        isLive: true,
        sourceId: streamId,
      );
      _stateController.add(_currentState);
      notifyListeners();

      await _audioSession?.setActive(true);

      await _whepHandler?.initStream(
        streamUrl: streamUrl,
        title: title,
        artist: artist,
        artworkUrl: artworkUrl,
      );

      debugPrint('[AudioManager] initStream done, calling play()...');
      await _whepHandler?.play();
      debugPrint('[AudioManager] play() called. Relying on _onLiveStreamState for updates.');
    } catch (e, st) {
      debugPrint('Error playing live stream: $e\n$st');
      _currentState = _currentState.copyWith(
        error: e.toString(),
        isConnecting: false,
        isPlaying: false,
        sourceType: AudioSourceType.none,
      );
      _stateController.add(_currentState);
      notifyListeners();
    }
  }

  Future<void> playRecording({
    required int recordingId,
    required String title,
    required String artist,
    String? artworkUrl,
    required String audioUrl,
    Duration? duration,
    Duration? startPosition,
  }) async {
    debugPrint('[AudioManager] Playing recording: $title');

    try {
      await _stopAllAndClear(clearSourceType: false);

      _currentState = AudioState(
        sourceType: AudioSourceType.recording,
        title: title,
        artist: artist,
        artworkUrl: artworkUrl,
        isPlaying: true,
        isLive: false,
        sourceId: recordingId,
        duration: duration,
      );
      _stateController.add(_currentState);
      notifyListeners();

      await _audioSession?.setActive(true);

      _whepHandler?.registerExternalPlaybackControls(
        play: () async {
          if (_recordingPlayer?.playing != true) {
            _recordingPlayer?.play(); // do not await
          }
        },
        pause: () async {
          if (_recordingPlayer?.playing == true) {
            await _recordingPlayer?.pause();
            _saveRecordingPosition();
          }
        },
        stop: () async {
          await _stopAllAndClear();
        },
      );

      final mediaItem = MediaItem(
        id: recordingId.toString(),
        title: title,
        artist: artist,
        artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
        duration: duration,
        extras: const {'isLive': false},
      );

      if (audioUrl.startsWith('/') || audioUrl.startsWith('file://')) {
        final filePath = audioUrl.startsWith('file://')
            ? audioUrl.substring(7)
            : audioUrl;
        await _recordingPlayer?.setAudioSource(
          AudioSource.file(filePath, tag: mediaItem),
        );
      } else {
        await _recordingPlayer?.setAudioSource(
          AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem),
        );
      }

      _whepHandler?.updateRecordingMediaItem(mediaItem, playing: true);
      debugPrint('[AudioManager] Recording MediaItem set: ${mediaItem.title}');

      if (startPosition != null && startPosition.inSeconds > 0) {
        await _recordingPlayer?.seek(startPosition);
      }

      _recordingPlayer?.play(); // do not await
      debugPrint('[AudioManager] Recording playback started');
      _startPositionTimer();

      _currentState = _currentState.copyWith(clearError: true);
      _stateController.add(_currentState);
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error playing recording: $e\n$st');
      _currentState = _currentState.copyWith(
        error: e.toString(),
        isPlaying: false,
        sourceType: AudioSourceType.none,
      );
      _stateController.add(_currentState);
      notifyListeners();
    }
  }

  Duration _lastNativePosition = Duration.zero;
  int _stuckCount = 0;

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _lastNativePosition = _recordingPlayer?.position ?? Duration.zero;
    _stuckCount = 0;

    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_recordingPlayer != null) {
        var pos = _recordingPlayer!.position;
        
        if (pos == _lastNativePosition) {
          _stuckCount++;
          if (_stuckCount >= 2 && _currentState.position != null) {
            pos = _currentState.position! + const Duration(milliseconds: 500);
          }
        } else {
          _lastNativePosition = pos;
          _stuckCount = 0;
        }

        _currentState = _currentState.copyWith(position: pos);
        _stateController.add(_currentState);
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _saveRecordingPosition() {
    if (_recordingPlayer == null) return;
    debugPrint('Recording position: ${_recordingPlayer!.position.inSeconds}s');
  }

  Future<void> pause() async {
    debugPrint('[AudioManager] pause() called');

    if (_currentState.sourceType == AudioSourceType.liveStream) {
      await _whepHandler?.pause();
    } else if (_currentState.sourceType == AudioSourceType.recording) {
      await _recordingPlayer?.pause();
      _saveRecordingPosition();
    }

    _currentState = _currentState.copyWith(isPlaying: false);
    _stateController.add(_currentState);
    notifyListeners();
  }

  Future<void> resume() async {
    debugPrint('[AudioManager] resume() called');

    if (_currentState.sourceType == AudioSourceType.liveStream) {
      await _whepHandler?.play();
    } else if (_currentState.sourceType == AudioSourceType.recording) {
      _recordingPlayer?.play(); // do not await
    }

    _currentState = _currentState.copyWith(isPlaying: true);
    _stateController.add(_currentState);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    debugPrint('[AudioManager] togglePlayPause() - isPlaying: $isPlaying');
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> stop() async {
    debugPrint('[AudioManager] stop() called');
    await _stopAllAndClear();
    await _audioSession?.setActive(false);
  }

  Future<void> seek(Duration position) async {
    if (_currentState.sourceType == AudioSourceType.recording) {
      await _recordingPlayer?.seek(position);
      _currentState = _currentState.copyWith(position: position);
      _stateController.add(_currentState);
    }
  }

  Future<void> skipBack(int seconds) async {
    if (_currentState.sourceType == AudioSourceType.recording) {
      final currentPosition = _recordingPlayer?.position ?? Duration.zero;
      final dur = _recordingPlayer?.duration ?? Duration.zero;
      final newPosition = currentPosition - Duration(seconds: seconds);
      final clamped = newPosition < Duration.zero ? Duration.zero :
                     (newPosition > dur ? dur : newPosition);
      await seek(clamped);
    }
  }

  Future<void> skipForward(int seconds) async {
    if (_currentState.sourceType == AudioSourceType.recording) {
      final currentPosition = _recordingPlayer?.position ?? Duration.zero;
      final dur = _recordingPlayer?.duration ?? Duration.zero;
      final newPosition = currentPosition + Duration(seconds: seconds);
      final clamped = newPosition > dur ? dur : newPosition;
      await seek(clamped);
    }
  }

  Future<void> setSpeed(double speed) async {
    if (_currentState.sourceType == AudioSourceType.recording) {
      await _recordingPlayer?.setSpeed(speed);
    }
  }

  double get currentSpeed => _recordingPlayer?.speed ?? 1.0;
  Stream<double> get speedStream =>
      _recordingPlayer?.speedStream ?? Stream.value(1.0);

  void setMuted(bool muted) {
    _whepHandler?.setMuted(muted);
  }

  bool get isMuted => _whepHandler != null && _whepHandler!.audioTrack != null
      ? !_whepHandler!.audioTrack!.enabled
      : false;

  void toggleMute() {
    if (_whepHandler?.audioTrack != null) {
      _whepHandler!.setMuted(!isMuted);
    }
  }

  void reset() {
    debugPrint('[AudioManager] reset() called');
    _stopAllAndClear();
  }

  @override
  void dispose() {
    _stopPositionTimer();
    _recordingPositionSubscription?.cancel();
    _recordingStateSubscription?.cancel();
    _recordingPlayer?.dispose();
    _recordingPlayer = null;
    _stateController.close();
    _isInitialized = false;
    _instance = null;
    super.dispose();
  }
}