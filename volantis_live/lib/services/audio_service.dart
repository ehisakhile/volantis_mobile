import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Audio service for streaming playback
class AudioPlayerService {
  static AudioPlayerService? _instance;
  late final AudioPlayer _player;
  
  // Current track info
  String? _currentChannelId;
  String? _currentChannelName;
  String? _currentChannelImage;
  String? _currentStreamUrl;
  bool _isLive = false;

  AudioPlayerService._() {
    _player = AudioPlayer();
  }

  static AudioPlayerService get instance {
    _instance ??= AudioPlayerService._();
    return _instance!;
  }

  // Getters
  AudioPlayer get player => _player;
  bool get isPlaying => _player.playing;
  String? get currentChannelId => _currentChannelId;
  String? get currentChannelName => _currentChannelName;
  String? get currentChannelImage => _currentChannelImage;
  bool get isLive => _isLive;
  String? get currentStreamUrl => _currentStreamUrl;

  // Stream of player state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<double> get speedStream => _player.speedStream;

  // Combined stream for UI
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration?, Duration?, PlayerState?, PositionData>(
        _player.positionStream,
        _player.durationStream,
        _player.playerStateStream,
        (position, duration, state) => PositionData(
          position ?? Duration.zero,
          duration ?? Duration.zero,
          state ?? _player.playerState,
        ),
      );

  /// Load and play a stream
  Future<void> playStream({
    required String channelId,
    required String channelName,
    required String streamUrl,
    String? channelImage,
    bool isLive = false,
  }) async {
    try {
      _currentChannelId = channelId;
      _currentChannelName = channelName;
      _currentChannelImage = channelImage;
      _currentStreamUrl = streamUrl;
      _isLive = isLive;

      // For live streams, use the URL directly
      await _player.setUrl(streamUrl);
      await _player.play();
    } catch (e) {
      print('Error playing stream: $e');
      rethrow;
    }
  }

  /// Play
  Future<void> play() async {
    await _player.play();
  }

  /// Pause
  Future<void> pause() async {
    await _player.pause();
  }

  /// Stop
  Future<void> stop() async {
    await _player.stop();
    _currentChannelId = null;
    _currentChannelName = null;
    _currentChannelImage = null;
    _currentStreamUrl = null;
    _isLive = false;
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Dispose
  Future<void> dispose() async {
    await _player.dispose();
    _instance = null;
  }
}

/// Position data for combined stream
class PositionData {
  final Duration position;
  final Duration duration;
  final PlayerState playerState;

  PositionData(this.position, this.duration, this.playerState);
}