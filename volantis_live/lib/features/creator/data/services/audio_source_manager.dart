import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart';

enum AudioSourceType { microphone }

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
          runtimeType == runtimeType &&
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

  AudioConfiguration _configuration;
  AudioDevice? _selectedInputDevice;
  List<AudioDevice> _availableInputDevices = [];

  MediaStream? _microphoneStream;

  final _inputDevicesController =
      StreamController<List<AudioDevice>>.broadcast();
  final _sourceStateController =
      StreamController<Map<AudioSourceType, AudioSourceState>>.broadcast();
  final _configurationController =
      StreamController<AudioConfiguration>.broadcast();

  AudioSourceManager._internal(AudioConfiguration configuration)
    : _configuration = configuration {
    _sourceStates[AudioSourceType.microphone] = AudioSourceState.idle;
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

  bool get isMicrophoneActive =>
      _sourceStates[AudioSourceType.microphone] == AudioSourceState.running;

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
        'audio': true,
        'video': false,
      };

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

  Future<void> stopMicrophoneCapture() async {
    if (_microphoneStream != null) {
      _microphoneStream!.getTracks().forEach((track) {
        track.stop();
      });
      _microphoneStream = null;
    }

    _updateSourceState(AudioSourceType.microphone, AudioSourceState.stopped);
  }

  Future<void> restartMicrophone() async {
    if (isMicrophoneActive) {
      await stopMicrophoneCapture();
      await startMicrophoneCapture();
    }
  }

  Future<void> stopAll() async {
    await stopMicrophoneCapture();
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (enabled && !isMicrophoneActive) {
      await startMicrophoneCapture();
    } else if (!enabled && isMicrophoneActive) {
      await stopMicrophoneCapture();
    }
  }

  MediaStream? getMicrophoneStream() => _microphoneStream;

  double getMicrophoneVolume() {
    return 100.0;
  }

  Future<void> setMicrophoneVolume(double volume) async {}

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