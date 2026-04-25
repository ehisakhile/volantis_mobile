import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

enum AudioSourceType { microphone, system, background }

enum AudioSourceState { idle, starting, running, stopped, error }

class AudioDevice {
  final String deviceId;
  final String label;
  final String kind;

  AudioDevice({
    required this.deviceId,
    required this.label,
    required this.kind,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

class AudioConfiguration {
  final bool echoCancellation;
  final bool noiseSuppression;
  final bool autoGainControl;
  final int sampleRate;
  final int channelCount;

  const AudioConfiguration({
    this.echoCancellation = true,
    this.noiseSuppression = true,
    this.autoGainControl = true,
    this.sampleRate = 48000,
    this.channelCount = 1,
  });

  Map<String, dynamic> toWebRtcConstraints() {
    return {
      'echoCancellation': echoCancellation,
      'noiseSuppression': noiseSuppression,
      'autoGainControl': autoGainControl,
      'sampleRate': sampleRate,
      'channelCount': channelCount,
    };
  }

  AudioConfiguration copyWith({
    bool? echoCancellation,
    bool? noiseSuppression,
    bool? autoGainControl,
    int? sampleRate,
    int? channelCount,
  }) {
    return AudioConfiguration(
      echoCancellation: echoCancellation ?? this.echoCancellation,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      autoGainControl: autoGainControl ?? this.autoGainControl,
      sampleRate: sampleRate ?? this.sampleRate,
      channelCount: channelCount ?? this.channelCount,
    );
  }
}

class AudioSourceManager {
  static AudioSourceManager? _instance;

  AudioSession? _audioSession;
  final Map<AudioSourceType, AudioSourceState> _sourceStates = {};
  final Map<AudioSourceType, StreamSubscription?> _sourceSubscriptions = {};

  AudioConfiguration _configuration;
  AudioDevice? _selectedInputDevice;
  List<AudioDevice> _availableInputDevices = [];

  AudioPlayer? _backgroundPlayer;
  MediaStream? _microphoneStream;
  MediaStreamTrack? _systemAudioTrack;
  bool _isSystemAudioSupported = false;

  final _inputDevicesController =
      StreamController<List<AudioDevice>>.broadcast();
  final _sourceStateController =
      StreamController<Map<AudioSourceType, AudioSourceState>>.broadcast();
  final _configurationController =
      StreamController<AudioConfiguration>.broadcast();

  AudioSourceManager._internal(AudioConfiguration configuration)
    : _configuration = configuration {
    _sourceStates[AudioSourceType.microphone] = AudioSourceState.idle;
    _sourceStates[AudioSourceType.system] = AudioSourceState.idle;
    _sourceStates[AudioSourceType.background] = AudioSourceState.idle;
    _initializeSystemAudioSupport();
  }

  factory AudioSourceManager({
    AudioConfiguration configuration = const AudioConfiguration(),
  }) {
    _instance ??= AudioSourceManager._internal(configuration);
    return _instance!;
  }

  static AudioSourceManager get instance {
    if (_instance == null) {
      throw StateError(
        'AudioSourceManager not initialized. Call AudioSourceManager() first.',
      );
    }
    return _instance!;
  }

  bool get isInitialized => _instance != null;

  AudioConfiguration get configuration => _configuration;
  AudioDevice? get selectedInputDevice => _selectedInputDevice;
  List<AudioDevice> get availableInputDevices =>
      List.unmodifiable(_availableInputDevices);

  Stream<List<AudioDevice>> get inputDevicesStream =>
      _inputDevicesController.stream;
  Stream<Map<AudioSourceType, AudioSourceState>> get sourceStateStream =>
      _sourceStateController.stream;
  Stream<AudioConfiguration> get configurationStream =>
      _configurationController.stream;

  AudioSourceState getMicrophoneState() =>
      _sourceStates[AudioSourceType.microphone] ?? AudioSourceState.idle;
  AudioSourceState getSystemAudioState() =>
      _sourceStates[AudioSourceType.system] ?? AudioSourceState.idle;
  AudioSourceState getBackgroundAudioState() =>
      _sourceStates[AudioSourceType.background] ?? AudioSourceState.idle;

  bool get isMicrophoneActive =>
      _sourceStates[AudioSourceType.microphone] == AudioSourceState.running;
  bool get isSystemAudioActive =>
      _sourceStates[AudioSourceType.system] == AudioSourceState.running;
  bool get isBackgroundAudioActive =>
      _sourceStates[AudioSourceType.background] == AudioSourceState.running;

  Future<void> _initializeSystemAudioSupport() async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _isSystemAudioSupported = true;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      _isSystemAudioSupported = await _checkAndroidSystemAudioSupport();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      _isSystemAudioSupported = false;
    }
  }

  Future<bool> _checkAndroidSystemAudioSupport() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      return devices.any((device) => device.kind == 'audiooutput');
    } catch (_) {
      return false;
    }
  }

  bool get isSystemAudioSupported => _isSystemAudioSupported;

  Future<void> updateConfiguration(AudioConfiguration newConfiguration) async {
    _configuration = newConfiguration;
    _configurationController.add(_configuration);

    if (isMicrophoneActive) {
      await restartMicrophone();
    }
  }

  Future<void> initialize() async {
    _audioSession ??= await AudioSession.instance;
    await _audioSession!.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    await enumerateInputDevices();
  }

  Future<void> enumerateInputDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      _availableInputDevices = devices
          .where((device) => device.kind == 'audioinput')
          .map(
            (device) => AudioDevice(
              deviceId: device.deviceId,
              label: device.label.isNotEmpty
                  ? device.label
                  : 'Microphone ${_availableInputDevices.length + 1}',
              kind: device.kind ?? 'audioinput',
            ),
          )
          .toList();

      if (_selectedInputDevice == null && _availableInputDevices.isNotEmpty) {
        _selectedInputDevice = _availableInputDevices.first;
      }

      _inputDevicesController.add(_availableInputDevices);
    } catch (e) {
      debugPrint('Error enumerating audio devices: $e');
      _availableInputDevices = [];
      _inputDevicesController.add(_availableInputDevices);
    }
  }

  Future<void> selectInputDevice(AudioDevice device) async {
    if (!_availableInputDevices.contains(device)) {
      throw ArgumentError('Device not in available devices list');
    }

    final wasActive = isMicrophoneActive;
    if (wasActive) {
      await stopMicrophoneCapture();
    }

    _selectedInputDevice = device;

    if (wasActive) {
      await startMicrophoneCapture();
    }
  }

  Future<MediaStream?> startMicrophoneCapture() async {
    if (_sourceStates[AudioSourceType.microphone] == AudioSourceState.running) {
      return _microphoneStream;
    }

    _updateSourceState(AudioSourceType.microphone, AudioSourceState.starting);

    try {
      _audioSession ??= await AudioSession.instance;
      await _audioSession!.setActive(true);

      final constraints = <String, dynamic>{
        'audio': _configuration.toWebRtcConstraints(),
        'video': false,
      };

      if (_selectedInputDevice != null) {
        constraints['audio'] = {
          ...constraints['audio'] as Map<String, dynamic>,
          'deviceId': {'exact': _selectedInputDevice!.deviceId},
        };
      }

      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      _microphoneStream = stream;

      _updateSourceState(AudioSourceType.microphone, AudioSourceState.running);
      return stream;
    } catch (e) {
      _updateSourceState(AudioSourceType.microphone, AudioSourceState.error);
      debugPrint('Error starting microphone capture: $e');
      rethrow;
    }
  }

  Future<MediaStream?> startSystemAudioCapture() async {
    if (!_isSystemAudioSupported) {
      throw UnsupportedError(
        'System audio capture is not supported on this platform',
      );
    }

    if (_sourceStates[AudioSourceType.system] == AudioSourceState.running) {
      return null;
    }

    _updateSourceState(AudioSourceType.system, AudioSourceState.starting);

    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': false,
          'noiseSuppression': false,
          'autoGainControl': false,
          'sampleRate': _configuration.sampleRate,
          'channelCount': _configuration.channelCount,
          'deviceId': {'exact': 'default'},
          'mandatory': {
            'goToEchoCancellation': false,
            'goToNoiseSuppression': false,
            'goToAutoGainControl': false,
          },
        },
        'video': false,
      };

      final stream = await navigator.mediaDevices.getDisplayMedia(constraints);

      _updateSourceState(AudioSourceType.system, AudioSourceState.running);

      final audioTrack = stream.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        _systemAudioTrack = audioTrack;
        audioTrack.onEnded = () {
          stopSystemAudioCapture();
        };
      }

      return stream;
    } catch (e) {
      _updateSourceState(AudioSourceType.system, AudioSourceState.error);
      debugPrint('Error starting system audio capture: $e');
      rethrow;
    }
  }

  Future<void> startBackgroundAudio(String filePath) async {
    if (_sourceStates[AudioSourceType.background] == AudioSourceState.running) {
      return;
    }

    _updateSourceState(AudioSourceType.background, AudioSourceState.starting);

    try {
      _audioSession ??= await AudioSession.instance;
      await _audioSession!.setActive(true);

      _backgroundPlayer = AudioPlayer();
      await _backgroundPlayer!.setFilePath(filePath);
      await _backgroundPlayer!.setLoopMode(LoopMode.one);
      await _backgroundPlayer!.play();

      _updateSourceState(AudioSourceType.background, AudioSourceState.running);
    } catch (e) {
      _updateSourceState(AudioSourceType.background, AudioSourceState.error);
      debugPrint('Error starting background audio: $e');
      await _backgroundPlayer?.dispose();
      _backgroundPlayer = null;
      rethrow;
    }
  }

  Future<void> stopMicrophoneCapture() async {
    if (_microphoneStream != null) {
      _microphoneStream!.getTracks().forEach((track) {
        track.stop();
      });
      _microphoneStream = null;
    }

    _updateSourceState(AudioSourceType.microphone, AudioSourceState.stopped);
  }

  Future<void> stopSystemAudioCapture() async {
    await _sourceSubscriptions[AudioSourceType.system]?.cancel();
    _sourceSubscriptions[AudioSourceType.system] = null;

    _systemAudioTrack?.onEnded = null;
    _systemAudioTrack = null;

    _updateSourceState(AudioSourceType.system, AudioSourceState.stopped);
  }

  Future<void> stopBackgroundAudio() async {
    await _backgroundPlayer?.stop();
    await _backgroundPlayer?.dispose();
    _backgroundPlayer = null;

    _updateSourceState(AudioSourceType.background, AudioSourceState.stopped);
  }

  Future<void> restartMicrophone() async {
    if (isMicrophoneActive) {
      await stopMicrophoneCapture();
      await startMicrophoneCapture();
    }
  }

  Future<void> stopAll() async {
    await stopMicrophoneCapture();
    await stopSystemAudioCapture();
    await stopBackgroundAudio();
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (enabled && !isMicrophoneActive) {
      await startMicrophoneCapture();
    } else if (!enabled && isMicrophoneActive) {
      await stopMicrophoneCapture();
    }
  }

  Future<void> setSystemAudioEnabled(bool enabled) async {
    if (!_isSystemAudioSupported) return;

    if (enabled && !isSystemAudioActive) {
      await startSystemAudioCapture();
    } else if (!enabled && isSystemAudioActive) {
      await stopSystemAudioCapture();
    }
  }

  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    if (enabled && !isBackgroundAudioActive) {
      throw StateError(
        'Background audio file not set. Call startBackgroundAudio first.',
      );
    } else if (!enabled && isBackgroundAudioActive) {
      await stopBackgroundAudio();
    }
  }

  MediaStream? getMicrophoneStream() => _microphoneStream;
  AudioPlayer? getBackgroundPlayer() => _backgroundPlayer;

  double getMicrophoneVolume() {
    return 100.0;
  }

  Future<void> setMicrophoneVolume(double volume) async {}

  double getBackgroundAudioVolume() {
    return _backgroundPlayer?.volume ?? 0.0;
  }

  Future<void> setBackgroundAudioVolume(double volume) async {
    await _backgroundPlayer?.setVolume(volume.clamp(0.0, 1.0));
  }

  void _updateSourceState(AudioSourceType type, AudioSourceState state) {
    _sourceStates[type] = state;
    _sourceStateController.add(Map.from(_sourceStates));
  }

  Future<void> dispose() async {
    await stopAll();

    await _inputDevicesController.close();
    await _sourceStateController.close();
    await _configurationController.close();

    _instance = null;
  }
}
