import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_provider.dart';

/// Onboarding / Welcome screen — single scrollable page
/// Matches the VolantisLive HTML design: dark navy, sky-blue primary,
/// waveform decoration, value-prop list, and auth action buttons.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Brand colours (mirrors the HTML token set) ──────────────────────────
  static const Color _background = Color(0xFF0B1326);
  static const Color _surface = Color(0xFF131B2E);
  static const Color _surfaceHigh = Color(0xFF222A3D);
  static const Color _primary = Color(0xFF89CEFF);
  static const Color _primaryContainer = Color(0xFF0EA5E9);
  static const Color _secondary = Color(0xFFD2BBFF);
  static const Color _tertiary = Color(0xFFFFB3AD);
  static const Color _onSurface = Color(0xFFDAE2FD);
  static const Color _onSurfaceVariant = Color(0xFFBEC8D2);
  static const Color _outlineVariant = Color(0xFF3E4850);
  static const Color _onPrimaryFixed = Color(0xFF001E2F);

  // ── Value propositions ───────────────────────────────────────────────────
  static const List<_ValueProp> _props = [
    _ValueProp(
      icon: Icons.podcasts_rounded,
      color: _primary,
      text: 'Listen to live audio from anyone, anywhere',
    ),
    _ValueProp(
      icon: Icons.auto_awesome_rounded,
      color: _secondary,
      text: 'AI-powered tools that make streaming effortless',
    ),
    _ValueProp(
      icon: Icons.videocam_rounded,
      color: _tertiary,
      text: 'Video streaming coming soon',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    context.read<OnboardingProvider>().completeOnboarding();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          // ── Scrollable body ──────────────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              children: [
                _HeroSection(pulseAnimation: _pulseAnimation),
                _ContentSection(
                  props: _props,
                  onGoogle: _completeOnboarding,
                  onApple: _completeOnboarding,
                  onEmail: _completeOnboarding,
                  onGuest: _completeOnboarding,
                ),
              ],
            ),
          ),

          // ── Fixed header ─────────────────────────────────────────────────
          _Header(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060E20), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 20,
        ),
        child: const Center(
          child: Text(
            'VolantisLive',
            style: TextStyle(
              color: _OnboardingColors.primary,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              fontSize: 28,
              letterSpacing: -1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Hero / decorative top section
// ──────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _HeroSection({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 353 + top,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), _OnboardingColors.background],
                ),
              ),
            ),
          ),

          // SVG-style waveform painted by CustomPainter
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _WaveformPainter(),
            ),
          ),

          // Pulsing mic orb
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, __) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: top - 30),
                  _PulseOrb(scale: pulseAnimation.value),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PulseOrb extends StatelessWidget {
  final double scale;

  const _PulseOrb({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _OnboardingColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _OnboardingColors.primary.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.mic_external_on_rounded,
              color: _OnboardingColors.primary,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Content section
// ──────────────────────────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final List<_ValueProp> props;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onEmail;
  final VoidCallback onGuest;

  const _ContentSection({
    required this.props,
    required this.onGoogle,
    required this.onApple,
    required this.onEmail,
    required this.onGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // ── Headline ─────────────────────────────────────────────────────
          const Text(
            'Your world. \nLive.',
            style: TextStyle(
              color: _OnboardingColors.onSurface,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          const Text(
            'Stream, listen, and connect with your people.',
            style: TextStyle(
              color: _OnboardingColors.onSurfaceVariant,
              fontSize: 24,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 36),

          // ── Value props ───────────────────────────────────────────────────
          ...props.map((p) => _ValuePropTile(prop: p)),

          const SizedBox(height: 36),

          // ── Action buttons ────────────────────────────────────────────────
          // _GoogleButton(onTap: onGoogle),
          // const SizedBox(height: 12),
          // _AppleButton(onTap: onApple),
          const SizedBox(height: 12),
          _EmailButton(onTap: onEmail),

          // const SizedBox(height: 20),
          // _GuestLink(onTap: onGuest),
          const SizedBox(height: 32),

          // ── Footer ────────────────────────────────────────────────────────
          Opacity(
            opacity: 0.4,
            child: Text(
              'PREMIUM LIVE EXPERIENCE  •  EST. 2026',
              style: TextStyle(
                color: _OnboardingColors.onSurfaceVariant,
                fontSize: 9,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Value prop row
// ──────────────────────────────────────────────────────────────────────────────

class _ValuePropTile extends StatelessWidget {
  final _ValueProp prop;

  const _ValuePropTile({required this.prop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _OnboardingColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(prop.icon, color: prop.color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              prop.text,
              style: const TextStyle(
                color: _OnboardingColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Auth buttons
// ──────────────────────────────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: onTap,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _OnboardingColors.primary,
            _OnboardingColors.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _OnboardingColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleLogo(),
          const SizedBox(width: 12),
          const Text(
            'Continue with Google',
            style: TextStyle(
              color: _OnboardingColors.onPrimaryFixed,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AppleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: onTap,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.apple_rounded, color: Colors.black, size: 22),
          SizedBox(width: 10),
          Text(
            'Continue with Apple',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EmailButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: onTap,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _OnboardingColors.primary,
            _OnboardingColors.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OnboardingColors.outlineVariant),
      ),
      child: const Text(
        'Continue with Email',
        style: TextStyle(
          color: _OnboardingColors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final VoidCallback onTap;
  final BoxDecoration decoration;
  final Widget child;

  const _AuthButton({
    required this.onTap,
    required this.decoration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 56,
        decoration: decoration,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _GuestLink extends StatelessWidget {
  final VoidCallback onTap;

  const _GuestLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Browse without account',
            style: TextStyle(
              color: _OnboardingColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.arrow_right_alt_rounded,
            color: _OnboardingColors.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Google logo painter (4-colour SVG path recreation)
// ──────────────────────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20);
  }
}
// ──────────────────────────────────────────────────────────────────────────────
// Waveform painter
// ──────────────────────────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final primary = Paint()
      ..color = const Color(0xFF89CEFF).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final secondary = Paint()
      ..color = const Color(0xFFD2BBFF).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Primary wave
    final p1 = Path();
    p1.moveTo(0, h * 0.5);
    p1.cubicTo(w * 0.12, h * 0.1, w * 0.25, h * 0.9, w * 0.375, h * 0.5);
    p1.cubicTo(w * 0.5, h * 0.1, w * 0.625, h * 0.9, w * 0.75, h * 0.5);
    p1.cubicTo(w * 0.875, h * 0.1, w * 0.95, h * 0.7, w, h * 0.3);
    canvas.drawPath(p1, primary);

    // Secondary wave (offset)
    final p2 = Path();
    p2.moveTo(0, h * 0.6);
    p2.cubicTo(w * 0.15, h * 0.3, w * 0.3, h * 0.85, w * 0.45, h * 0.6);
    p2.cubicTo(w * 0.6, h * 0.35, w * 0.75, h * 0.75, w, h * 0.4);
    canvas.drawPath(p2, secondary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared colour constants (avoids referencing app_colors for isolated use)
// ──────────────────────────────────────────────────────────────────────────────

abstract class _OnboardingColors {
  static const background = Color(0xFF0B1326);
  static const surfaceHigh = Color(0xFF222A3D);
  static const primary = Color(0xFF89CEFF);
  static const primaryContainer = Color(0xFF0EA5E9);
  static const onPrimaryFixed = Color(0xFF001E2F);
  static const secondary = Color(0xFFD2BBFF);
  static const tertiary = Color(0xFFFFB3AD);
  static const onSurface = Color(0xFFDAE2FD);
  static const onSurfaceVariant = Color(0xFFBEC8D2);
  static const outlineVariant = Color(0xFF3E4850);
}

// ──────────────────────────────────────────────────────────────────────────────
// Data model
// ──────────────────────────────────────────────────────────────────────────────

class _ValueProp {
  final IconData icon;
  final Color color;
  final String text;

  const _ValueProp({
    required this.icon,
    required this.color,
    required this.text,
  });
}
