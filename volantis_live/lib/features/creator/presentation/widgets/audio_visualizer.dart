import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/services/audio_mixer_engine.dart';

enum VisualizerType { bars, waveform }

class VisualizerConfig {
  final int fftSize;
  final double smoothingTimeConstant;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final double barRadius;
  final Color accentColor;
  final List<Color>? gradientColors;
  final bool useGradient;
  final double minAmplitude;
  final double maxAmplitude;
  final double animationSpeed;
  final VisualizerType type;
  final double waveformStrokeWidth;
  final Color? waveformColor;

  const VisualizerConfig({
    this.fftSize = 256,
    this.smoothingTimeConstant = 0.75,
    this.barCount = 64,
    this.barWidth = 6.0,
    this.barSpacing = 2.0,
    this.barRadius = 3.0,
    this.accentColor = const Color(0xFF6366F1),
    this.gradientColors,
    this.useGradient = true,
    this.minAmplitude = 0.05,
    this.maxAmplitude = 1.0,
    this.animationSpeed = 1.0,
    this.type = VisualizerType.bars,
    this.waveformStrokeWidth = 2.0,
    this.waveformColor,
  });

  VisualizerConfig copyWith({
    int? fftSize,
    double? smoothingTimeConstant,
    int? barCount,
    double? barWidth,
    double? barSpacing,
    double? barRadius,
    Color? accentColor,
    List<Color>? gradientColors,
    bool? useGradient,
    double? minAmplitude,
    double? maxAmplitude,
    double? animationSpeed,
    VisualizerType? type,
    double? waveformStrokeWidth,
    Color? waveformColor,
  }) {
    return VisualizerConfig(
      fftSize: fftSize ?? this.fftSize,
      smoothingTimeConstant: smoothingTimeConstant ?? this.smoothingTimeConstant,
      barCount: barCount ?? this.barCount,
      barWidth: barWidth ?? this.barWidth,
      barSpacing: barSpacing ?? this.barSpacing,
      barRadius: barRadius ?? this.barRadius,
      accentColor: accentColor ?? this.accentColor,
      gradientColors: gradientColors ?? this.gradientColors,
      useGradient: useGradient ?? this.useGradient,
      minAmplitude: minAmplitude ?? this.minAmplitude,
      maxAmplitude: maxAmplitude ?? this.maxAmplitude,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      type: type ?? this.type,
      waveformStrokeWidth: waveformStrokeWidth ?? this.waveformStrokeWidth,
      waveformColor: waveformColor ?? this.waveformColor,
    );
  }

  List<Color> get effectiveGradientColors =>
      gradientColors ??
      [
        accentColor.withOpacity(0.3),
        accentColor,
        accentColor.withOpacity(0.8),
      ];
}

class AudioFrequencyData {
  final List<double> frequencies;
  final double timestamp;

  const AudioFrequencyData({
    required this.frequencies,
    required this.timestamp,
  });

  factory AudioFrequencyData.empty(int binCount) {
    return AudioFrequencyData(
      frequencies: List.filled(binCount, 0.0),
      timestamp: 0,
    );
  }

  double get magnitude {
    if (frequencies.isEmpty) return 0.0;
    return frequencies.reduce((a, b) => a + b) / frequencies.length;
  }
}

class AudioVisualizer extends StatefulWidget {
  final AudioMixerEngine? audioEngine;
  final String? channelId;
  final Stream<AudioFrequencyData>? frequencyStream;
  final VisualizerConfig config;
  final double width;
  final double height;
  final bool isActive;
  final bool showPlaceholder;
  final Widget? placeholder;

  const AudioVisualizer({
    super.key,
    this.audioEngine,
    this.channelId,
    this.frequencyStream,
    this.config = const VisualizerConfig(),
    this.width = 800,
    this.height = 128,
    this.isActive = true,
    this.showPlaceholder = true,
    this.placeholder,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  List<double> _smoothedFrequencies = [];
  List<double> _targetFrequencies = [];
  final List<double> _waveformHistory = [];
  double _lastTimestamp = 0;

  StreamSubscription? _frequencySubscription;
  StreamSubscription? _audioLevelSubscription;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeFrequencies();
    _setupTicker();
    _setupAudioStream();
  }

  void _initializeFrequencies() {
    final binCount = widget.config.fftSize ~/ 2;
    _smoothedFrequencies = List.filled(binCount, 0.0);
    _targetFrequencies = List.filled(binCount, 0.0);
  }

  void _setupTicker() {
    _ticker = createTicker(_onTick);
    if (widget.isActive) {
      _ticker.start();
    }
  }

  void _setupAudioStream() {
    if (widget.frequencyStream != null) {
      _frequencySubscription = widget.frequencyStream!.listen(_onFrequencyData);
    } else if (widget.audioEngine != null) {
      _setupFromAudioEngine();
    } else {
      _startDemoMode();
    }
  }

  void _setupFromAudioEngine() {
    final engine = widget.audioEngine!;
    final stream = widget.channelId != null
        ? engine.getChannelAudioLevelStream(widget.channelId!)
        : engine.masterAudioLevelStream;

    _audioLevelSubscription = stream.listen((level) {
      if (mounted) {
        _onAudioLevel(level / 100.0);
      }
    });
  }

  void _startDemoMode() {
    _frequencySubscription = Stream.periodic(const Duration(milliseconds: 50))
        .listen((_) {
      if (mounted && widget.isActive) {
        _generateDemoFrequencies();
      }
    });
  }

  void _generateDemoFrequencies() {
    final binCount = widget.config.fftSize ~/ 2;
    final target = List.generate(binCount, (i) {
      final baseFreq = i / binCount;
      final amplitude = pow(2, -baseFreq * 2).toDouble();
      final noise = _random.nextDouble() * 0.3;
      final level = widget.audioEngine?.masterAudioLevel ?? 50.0;
      return (amplitude * (level / 100.0) + noise).clamp(0.0, 1.0);
    });
    _updateTargetFrequencies(target);
  }

  void _onFrequencyData(AudioFrequencyData data) {
    _updateTargetFrequencies(data.frequencies);
  }

  void _onAudioLevel(double level) {
    final binCount = widget.config.fftSize ~/ 2;
    final frequencies = List.generate(binCount, (i) {
      final baseFreq = i / binCount;
      final amplitude = pow(2, -baseFreq * 2).toDouble();
      return amplitude * level * (0.8 + _random.nextDouble() * 0.4);
    });
    _updateTargetFrequencies(frequencies);
  }

  void _updateTargetFrequencies(List<double> target) {
    if (target.length != _targetFrequencies.length) {
      _initializeFrequencies();
    }
    _targetFrequencies = List.from(target);
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !widget.isActive) return;

    final dt = _lastTimestamp == 0
        ? 0.016
        : (elapsed.inMicroseconds - _lastTimestamp) / 1000000.0;
    _lastTimestamp = elapsed.inMicroseconds.toDouble();

    final smoothing = widget.config.smoothingTimeConstant;
    final speed = widget.config.animationSpeed;

    for (int i = 0; i < _smoothedFrequencies.length; i++) {
      final target = i < _targetFrequencies.length ? _targetFrequencies[i] : 0.0;
      final current = _smoothedFrequencies[i];
      final smoothed = current + (target - current) * (smoothing * speed * dt * 60);
      _smoothedFrequencies[i] = smoothed.clamp(0.0, 1.0);
    }

    if (widget.config.type == VisualizerType.waveform) {
      final avg = _smoothedFrequencies.isEmpty
          ? 0.0
          : _smoothedFrequencies.reduce((a, b) => a + b) / _smoothedFrequencies.length;
      _waveformHistory.add(avg);
      if (_waveformHistory.length > widget.width.toInt()) {
        _waveformHistory.removeAt(0);
      }
    }

    setState(() {});
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _ticker.start();
      } else {
        _ticker.stop();
      }
    }

    if (widget.config.fftSize != oldWidget.config.fftSize ||
        widget.config.barCount != oldWidget.config.barCount) {
      _initializeFrequencies();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frequencySubscription?.cancel();
    _audioLevelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && widget.showPlaceholder) {
      return widget.placeholder ?? _buildPlaceholder();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _AudioVisualizerPainter(
          frequencies: _smoothedFrequencies,
          waveformHistory: _waveformHistory,
          config: widget.config,
        ),
        size: Size(widget.width, widget.height),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.config.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'Audio Visualizer',
          style: TextStyle(
            color: widget.config.accentColor.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _AudioVisualizerPainter extends CustomPainter {
  final List<double> frequencies;
  final List<double> waveformHistory;
  final VisualizerConfig config;

  _AudioVisualizerPainter({
    required this.frequencies,
    required this.waveformHistory,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (config.type) {
      case VisualizerType.bars:
        _paintBars(canvas, size);
        break;
      case VisualizerType.waveform:
        _paintWaveform(canvas, size);
        break;
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    if (frequencies.isEmpty) return;

    final barCount = config.barCount;
    final barWidth = config.barWidth;
    final barSpacing = config.barSpacing;
    final totalBarWidth = barWidth + barSpacing;
    final startX = (size.width - (barCount * totalBarWidth - barSpacing)) / 2;
    final centerY = size.height / 2;

    final gradientColors = config.effectiveGradientColors;
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: gradientColors,
   );

    final frequenciesPerBar = frequencies.length / barCount;

    for (int i = 0; i < barCount; i++) {
      final freqIndex = (i * frequenciesPerBar).floor();
      final freqEndIndex = ((i + 1) * frequenciesPerBar).floor().clamp(0, frequencies.length);

      double avgFreq = 0.0;
      if (freqIndex < freqEndIndex) {
        for (int j = freqIndex; j < freqEndIndex; j++) {
          avgFreq += frequencies[j];
        }
        avgFreq /= (freqEndIndex - freqIndex);
      }

      final amplitude = avgFreq.clamp(config.minAmplitude, config.maxAmplitude);
      final barHeight = amplitude * size.height * 0.9;

      final x = startX + i * totalBarWidth;
      final topY = centerY - barHeight / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, topY, barWidth, barHeight),
        Radius.circular(config.barRadius),
      );

      final paint = Paint()
        ..shader = config.useGradient
            ? gradient.createShader(Rect.fromLTWH(x, topY, barWidth, barHeight))
            : null
        ..color = config.useGradient
            ? config.accentColor
            : config.accentColor.withOpacity(amplitude);

      if (!config.useGradient) {
        paint.color = paint.color.withOpacity(0.3 + (amplitude * 0.7));
      }

      canvas.drawRRect(rect, paint);
    }
  }

  void _paintWaveform(Canvas canvas, Size size) {
    if (waveformHistory.isEmpty) return;

    final path = Path();
    final waveformColor = config.waveformColor ?? config.accentColor;
    final strokeWidth = config.waveformStrokeWidth;

    final stepX = size.width / waveformHistory.length;
    final centerY = size.height / 2;

    for (int i = 0; i < waveformHistory.length; i++) {
      final x = i * stepX;
      final amplitude = waveformHistory[i].clamp(0.0, 1.0);
      final y = centerY - (amplitude * size.height * 0.4);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = waveformColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);

    final reflectedPath = Path();
    for (int i = 0; i < waveformHistory.length; i++) {
      final x = i * stepX;
      final amplitude = waveformHistory[i].clamp(0.0, 1.0);
      final y = centerY + (amplitude * size.height * 0.4);

      if (i == 0) {
        reflectedPath.moveTo(x, y);
      } else {
        reflectedPath.lineTo(x, y);
      }
    }

    final reflectedPaint = Paint()
      ..color = waveformColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(reflectedPath, reflectedPaint);
  }

  @override
  bool shouldRepaint(covariant _AudioVisualizerPainter oldDelegate) {
    return frequencies != oldDelegate.frequencies ||
        waveformHistory != oldDelegate.waveformHistory ||
        config != oldDelegate.config;
  }
}

class AudioVisualizerController {
  final VisualizerConfig config;
  final BehaviorSubject<AudioFrequencyData> _frequencySubject;
  bool _isActive = false;

  AudioVisualizerController({
    VisualizerConfig? config,
    int fftSize = 256,
  })  : config = config ?? const VisualizerConfig(),
        _frequencySubject = BehaviorSubject.seeded(
          AudioFrequencyData.empty(fftSize ~/ 2),
        );

  Stream<AudioFrequencyData> get frequencyStream => _frequencySubject.stream;

  bool get isActive => _isActive;

  void updateFrequencies(List<double> frequencies) {
    _frequencySubject.add(AudioFrequencyData(
      frequencies: frequencies,
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
    ));
  }

  void updateFromAudioLevel(double level) {
    final binCount = config.fftSize ~/ 2;
    final frequencies = List.generate(binCount, (i) {
      final baseFreq = i / binCount;
      final amplitude = pow(2, -baseFreq * 2).toDouble();
      return amplitude * level.clamp(0.0, 1.0);
    });
    updateFrequencies(frequencies);
  }

  void start() {
    _isActive = true;
  }

  void stop() {
    _isActive = false;
  }

  void dispose() {
    _frequencySubject.close();
  }
}

class CompactAudioVisualizer extends StatelessWidget {
  final AudioMixerEngine? audioEngine;
  final String? channelId;
  final double height;
  final Color? color;

  const CompactAudioVisualizer({
    super.key,
    this.audioEngine,
    this.channelId,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AudioVisualizer(
        audioEngine: audioEngine,
        channelId: channelId,
        config: VisualizerConfig(
          barCount: 16,
          barWidth: 4,
          barSpacing: 2,
          barRadius: 2,
          accentColor: color ?? const Color(0xFF6366F1),
          useGradient: false,
          type: VisualizerType.bars,
        ),
        width: double.infinity,
        height: height,
      ),
    );
  }
}