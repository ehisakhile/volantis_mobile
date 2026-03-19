import 'dart:math' as math;
import 'package:flutter/material.dart';

/// VolantisLive Splash Screen
/// Matches the HTML design: radial blue gradient, bold wordmark,
/// animated waveform bars, and bottom tagline.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    // Navigation handled by router redirect logic
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFF0EA5E9), // sky-500 center
              Color(0xFF0369A1), // sky-700 edge
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative glow blobs (matching HTML opacity-20 blurs)
            Positioned(
              top: -80,
              left: -80,
              child: _GlowBlob(
                color: Colors.white.withOpacity(0.08),
                size: 340,
              ),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: _GlowBlob(
                color: const Color(0xFF7DD3FC).withOpacity(0.08),
                size: 340,
              ),
            ),

            // Center content: wordmark + waveform
            Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wordmark
                    const Text(
                      'VolantisLive',
                      style: TextStyle(
                        fontFamily: 'Georgia', // serif for editorial weight
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Animated waveform
                    SizedBox(
                      height: 64,
                      child: _AnimatedWaveform(controller: _controller),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom tagline
            Positioned(
              bottom: 64,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeIn,
                child: const Text(
                  'Fly. Broadcast. Connect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xE6FFFFFF), // white/90
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated waveform: 20 bars that pulse continuously
class _AnimatedWaveform extends StatefulWidget {
  final AnimationController controller;

  const _AnimatedWaveform({required this.controller});

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  // Static heights matching the HTML (normalized 0.0–1.0 from the bar heights)
  static const List<double> _baseHeights = [
    4,
    8,
    12,
    6,
    10,
    14,
    8,
    12,
    16,
    10,
    6,
    12,
    8,
    14,
    10,
    6,
    12,
    8,
    4,
    2,
  ];
  static const double _maxBarPx = 64.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_baseHeights.length, (i) {
            final phase = _waveController.value - (i * 0.05);
            final sine = (math.sin(phase * math.pi * 2) + 1) / 2; // 0..1
            final baseNorm = _baseHeights[i] / 16.0; // normalize to max 16
            final animHeight = (_baseHeights[i] + sine * 8).clamp(
              2.0,
              _maxBarPx,
            );

            return Container(
              width: 4,
              height: animHeight,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Soft blurred glow blob (replaces CSS blur divs)
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
      ),
    );
  }
}
