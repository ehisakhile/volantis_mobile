import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_provider.dart';

/// Onboarding screen — paginated PageView with pinned CTA
/// • Users swipe through 3 value-prop slides
/// • "Continue with Email" button is always visible at the bottom
/// • Animated page indicator dots
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _currentPage = 0;
  static const int _totalPages = 3;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.mic_external_on_rounded,
      iconColor: _OC.primary,
      title: 'Your world.\nLive.',
      subtitle: 'Stream live audio to anyone, anywhere — in seconds.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_rounded,
      iconColor: _OC.secondary,
      title: 'AI that works\nfor you.',
      subtitle:
          'Smart tools handle the hard parts so you can focus on your audience.',
    ),
    _OnboardingPage(
      icon: Icons.videocam_rounded,
      iconColor: _OC.tertiary,
      title: 'Video is\ncoming.',
      subtitle:
          'Full video streaming is on the way. Be first in line when it drops.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    context.read<OnboardingProvider>().completeOnboarding();
    widget.onComplete?.call();
  }

  void _onPageChanged(int index) => setState(() => _currentPage = index);

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _OC.background,
      body: Column(
        children: [
          // ── Logo header ───────────────────────────────────────────────
          _LogoHeader(topPadding: top),

          // ── Swipeable page content ────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _totalPages,
              itemBuilder: (context, index) => _PageSlide(
                page: _pages[index],
                pulseAnimation: _pulseAnimation,
                isActive: index == _currentPage,
              ),
            ),
          ),

          // ── Page dots ─────────────────────────────────────────────────
          _PageDots(current: _currentPage, total: _totalPages),

          const SizedBox(height: 28),

          // ── Pinned CTA ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _PrimaryButton(
                  label: _currentPage == _totalPages - 1
                      ? 'Get Started'
                      : 'Continue with Email',
                  onTap: _nextPage,
                ),
                const SizedBox(height: 14),
                _SkipLink(onTap: _completeOnboarding),
              ],
            ),
          ),

          SizedBox(height: bottom + 24),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Logo header
// ──────────────────────────────────────────────────────────────────────────────

class _LogoHeader extends StatelessWidget {
  final double topPadding;

  const _LogoHeader({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 16, bottom: 8),
      child: const Center(
        child: Text(
          'VolantisLive',
          style: TextStyle(
            color: _OC.primary,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 26,
            letterSpacing: -1.2,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Individual page slide
// ──────────────────────────────────────────────────────────────────────────────

class _PageSlide extends StatelessWidget {
  final _OnboardingPage page;
  final Animation<double> pulseAnimation;
  final bool isActive;

  const _PageSlide({
    required this.page,
    required this.pulseAnimation,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Pulsing orb ───────────────────────────────────────────────
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, __) => _PulseOrb(
              icon: page.icon,
              iconColor: page.iconColor,
              scale: isActive ? pulseAnimation.value : 0.85,
            ),
          ),

          const SizedBox(height: 48),

          // ── Title ──────────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              page.title,
              key: ValueKey(page.title),
              style: const TextStyle(
                color: _OC.onSurface,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.8,
                height: 1.05,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // ── Subtitle ──────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              page.subtitle,
              key: ValueKey(page.subtitle),
              style: const TextStyle(
                color: _OC.onSurfaceVariant,
                fontSize: 17,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Pulse orb
// ──────────────────────────────────────────────────────────────────────────────

class _PulseOrb extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double scale;

  const _PulseOrb({
    required this.icon,
    required this.iconColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: iconColor.withOpacity(0.15), width: 1.5),
      ),
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.10),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.20),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 52),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Page dots indicator
// ──────────────────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int current;
  final int total;

  const _PageDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? _OC.primary : _OC.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Primary CTA button
// ──────────────────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_OC.primary, _OC.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _OC.primary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: const TextStyle(
              color: _OC.onPrimaryFixed,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Skip / guest link
// ──────────────────────────────────────────────────────────────────────────────

class _SkipLink extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Text(
        'Skip for now',
        style: TextStyle(
          color: _OC.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Colour constants
// ──────────────────────────────────────────────────────────────────────────────

abstract class _OC {
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

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}
