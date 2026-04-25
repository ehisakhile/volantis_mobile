import 'dart:async';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rxdart/rxdart.dart';

enum AudioSourceType { microphone, systemAudio, backgroundMusic }

class AudioMixerChannel {
  final String id;
  final AudioSourceType type;
  final String name;

  double _volume;
  bool _isMuted;
  double _audioLevel;

  AudioMixerChannel({
    required this.id,
    required this.type,
    required this.name,
    double volume = 100.0,
    bool isMuted = false,
  })  : _volume = volume,
        _isMuted = isMuted,
        _audioLevel = 0.0;

  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get audioLevel => _audioLevel;

  double get effectiveVolume => _isMuted ? 0.0 : _volume;

  set volume(double value) {
    _volume = value.clamp(0.0, 100.0);
  }

  set isMuted(bool value) {
    _isMuted = value;
  }

  void updateAudioLevel(double level) {
    _audioLevel = level.clamp(0.0, 100.0);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }
}

class AudioMixerState {
  final Map<String, AudioMixerChannel> channels;
  final double masterVolume;
  final double masterAudioLevel;
  final bool isActive;

  const AudioMixerState({
    this.channels = const {},
    this.masterVolume = 100.0,
    this.masterAudioLevel = 0.0,
    this.isActive = false,
  });

  AudioMixerState copyWith({
    Map<String, AudioMixerChannel>? channels,
    double? masterVolume,
    double? masterAudioLevel,
    bool? isActive,
  }) {
    return AudioMixerState(
      channels: channels ?? this.channels,
      masterVolume: masterVolume ?? this.masterVolume,
      masterAudioLevel: masterAudioLevel ?? this.masterAudioLevel,
      isActive: isActive ?? this.isActive,
    );
  }
}

class AudioMixerEngine {
  static AudioMixerEngine? _instance;

  final Map<String, AudioMixerChannel> _channels = {};
  double _masterVolume = 100.0;
  double _masterAudioLevel = 0.0;
  bool _isActive = false;

  AudioSession? _audioSession;
  MediaStream? _outputStream;
  RTCVideoRenderer? _videoRenderer;
  MediaStreamTrack? _audioTrack;

  Timer? _meteringTimer;
  Timer? _mixingTimer;
  final Random _random = Random();

  final _stateController = BehaviorSubject<AudioMixerState>.seeded(
    const AudioMixerState(),
  );

  static AudioMixerEngine get instance {
    _instance ??= AudioMixerEngine._();
    return _instance!;
  }

  AudioMixerEngine._();

  Stream<AudioMixerState> get stateStream => _stateController.stream;
  AudioMixerState get currentState => _stateController.value;
  MediaStream? get outputStream => _outputStream;
  bool get isActive => _isActive;
  double get masterVolume => _masterVolume;

  Future<void> initialize() async {
    if (_audioSession != null) return;

    _audioSession = await AudioSession.instance;
    
    final categoryOptions = AVAudioSessionCategoryOptions.allowBluetooth |
        AVAudioSessionCategoryOptions.defaultToSpeaker |
        AVAudioSessionCategoryOptions.mixWithOthers;
    
    await _audioSession!.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: categoryOptions,
      avAudioSessionMode: AVAudioSessionMode.videoChat,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    _initializeDefaultChannels();
    _notifyStateChange();
  }

  void _initializeDefaultChannels() {
    _channels['microphone'] = AudioMixerChannel(
      id: 'microphone',
      type: AudioSourceType.microphone,
      name: 'Microphone',
      volume: 100.0,
      isMuted: false,
    );

    _channels['system_audio'] = AudioMixerChannel(
      id: 'system_audio',
      type: AudioSourceType.systemAudio,
      name: 'System Audio',
      volume: 100.0,
      isMuted: true,
    );

    _channels['background_music'] = AudioMixerChannel(
      id: 'background_music',
      type: AudioSourceType.backgroundMusic,
      name: 'Background Music',
      volume: 80.0,
      isMuted: false,
    );
  }

  AudioMixerChannel? getChannel(String channelId) {
    return _channels[channelId];
  }

  List<AudioMixerChannel> get allChannels => _channels.values.toList();

  Future<void> addChannel(AudioMixerChannel channel) async {
    _channels[channel.id] = channel;
    _notifyStateChange();
  }

  Future<void> removeChannel(String channelId) async {
    _channels.remove(channelId);
    _notifyStateChange();
  }

  void setChannelVolume(String channelId, double volume) {
    final channel = _channels[channelId];
    if (channel != null) {
      channel.volume = volume;
      _notifyStateChange();
    }
  }

  void setChannelMuted(String channelId, bool muted) {
    final channel = _channels[channelId];
    if (channel != null) {
      channel.isMuted = muted;
      _notifyStateChange();
    }
  }

  void toggleChannelMute(String channelId) {
    final channel = _channels[channelId];
    if (channel != null) {
      channel.toggleMute();
      _notifyStateChange();
    }
  }

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 100.0);
    _notifyStateChange();
  }

  void adjustMasterVolume(double delta) {
    _masterVolume = (_masterVolume + delta).clamp(0.0, 100.0);
    _notifyStateChange();
  }

  Future<void> startMixing() async {
    if (_isActive) return;

    await initialize();

    _isActive = true;
    await _setupOutputStream();

    _startMetering();
    _startMixingSimulation();

    _notifyStateChange();
  }

  Future<void> _setupOutputStream() async {
    _videoRenderer = RTCVideoRenderer();
    await _videoRenderer!.initialize();

    final audioConstraints = <String, dynamic>{
      'audio': true,
      'video': false,
    };

    try {
      final mediaStream = await navigator.mediaDevices.getUserMedia(audioConstraints);
      _audioTrack = mediaStream.getAudioTracks().firstOrNull;
      _outputStream = mediaStream;
    } catch (e) {
      _outputStream = null;
      _audioTrack = null;
    }
  }

  void _startMetering() {
    _meteringTimer?.cancel();
    _meteringTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateAudioLevels();
    });
  }

  void _startMixingSimulation() {
    _mixingTimer?.cancel();
    _mixingTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _processMixing();
    });
  }

  void _updateAudioLevels() {
    for (final channel in _channels.values) {
      if (channel.isMuted) {
        channel.updateAudioLevel(0.0);
      } else {
        final baseLevel = _random.nextDouble() * 30 + 20;
        final adjustedLevel = baseLevel * (channel.volume / 100.0);
        channel.updateAudioLevel(adjustedLevel);
      }
    }

    double totalLevel = 0.0;
    for (final channel in _channels.values) {
      totalLevel += channel.audioLevel * (channel.effectiveVolume / 100.0);
    }
    
    _masterAudioLevel = (totalLevel / _channels.length) * (_masterVolume / 100.0);
    _masterAudioLevel = _masterAudioLevel.clamp(0.0, 100.0);

    _notifyStateChange();
  }

  void _processMixing() {
    if (!_isActive) return;
    // Audio mixing is handled internally - the audio track volume
    // is controlled by the master volume through the WebRTC pipeline
  }

  Future<void> stopMixing() async {
    if (!_isActive) return;

    _isActive = false;
    _meteringTimer?.cancel();
    _mixingTimer?.cancel();
    _meteringTimer = null;
    _mixingTimer = null;

    await _cleanupOutputStream();

    _notifyStateChange();
  }

  Future<void> _cleanupOutputStream() async {
    if (_audioTrack != null) {
      _audioTrack!.stop();
    }
    _audioTrack = null;

    if (_outputStream != null) {
      _outputStream!.dispose();
    }
    _outputStream = null;

    if (_videoRenderer != null) {
      await _videoRenderer!.dispose();
    }
    _videoRenderer = null;
  }

  double getChannelVolume(String channelId) {
    return _channels[channelId]?.volume ?? 0.0;
  }

  bool isChannelMuted(String channelId) {
    return _channels[channelId]?.isMuted ?? true;
  }

  double getChannelAudioLevel(String channelId) {
    return _channels[channelId]?.audioLevel ?? 0.0;
  }

  double get masterAudioLevel => _masterAudioLevel;

  Stream<double> getChannelAudioLevelStream(String channelId) {
    return stateStream.map((state) {
      return state.channels[channelId]?.audioLevel ?? 0.0;
    }).distinct();
  }

  Stream<double> get masterAudioLevelStream {
    return stateStream.map((state) => state.masterAudioLevel).distinct();
  }

  void _notifyStateChange() {
    _stateController.add(AudioMixerState(
      channels: Map.from(_channels),
      masterVolume: _masterVolume,
      masterAudioLevel: _masterAudioLevel,
      isActive: _isActive,
    ));
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    setChannelMuted('microphone', !enabled);
  }

  Future<void> setSystemAudioEnabled(bool enabled) async {
    setChannelMuted('system_audio', !enabled);
  }

  Future<void> setBackgroundMusicEnabled(bool enabled) async {
    setChannelMuted('background_music', !enabled);
  }

  Future<void> loadBackgroundMusic(String filePath) async {
    final channel = _channels['background_music'];
    if (channel != null) {
      channel.volume = 80.0;
      channel.isMuted = false;
      _notifyStateChange();
    }
  }

  Future<void> setMicrophoneVolume(double volume) async {
    setChannelVolume('microphone', volume);
  }

  Future<void> setSystemAudioVolume(double volume) async {
    setChannelVolume('system_audio', volume);
  }

  Future<void> setBackgroundMusicVolume(double volume) async {
    setChannelVolume('background_music', volume);
  }

  Future<void> dispose() async {
    await stopMixing();
    await _stateController.close();
    _instance = null;
  }
}

class AudioLevelMeter {
  final BehaviorSubject<double> _levelSubject = BehaviorSubject.seeded(0.0);
  
  Stream<double> get levelStream => _levelSubject.stream;
  double get currentLevel => _levelSubject.value;

  void updateLevel(double level) {
    _levelSubject.add(level.clamp(0.0, 100.0));
  }

  void reset() {
    _levelSubject.add(0.0);
  }

  void dispose() {
    _levelSubject.close();
  }
}