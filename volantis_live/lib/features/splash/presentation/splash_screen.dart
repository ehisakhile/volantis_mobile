import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/app_update_manager.dart';

/// Shared VolantisLive and VolantisConnect splash screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runUpdateCheck();
    });
  }

  Future<void> _runUpdateCheck() async {
    await AppUpdateManager().initialize();
    if (!mounted) return;
    try {
      await AppUpdateManager().checkForUpdates(
        context,
        onComplete: () {
          if (mounted) {
            context.go('/');
          }
        },
      );
    } catch (_) {}
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0B1326),
              const Color(0xFF131B2E),
              const Color(0xFF0B1326),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -100,
              child: _GlowBlob(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -120,
              right: -120,
              child: _GlowBlob(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                size: 350,
              ),
            ),
            Positioned(
              top: 100,
              right: -50,
              child: _GlowBlob(
                color: const Color(0xFFD2BBFF).withValues(alpha: 0.08),
                size: 200,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    children: [
                      const Spacer(),
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: const _VolantisMark(),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Broadcast widely.\nConnect personally.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF4F7FF),
                          fontSize: 34,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Two ways to bring people together, all in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFBEC8D2),
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Row(
                        children: [
                          Expanded(
                            child: _ProductCard(
                              icon: Icons.podcasts_rounded,
                              color: Color(0xFF89CEFF),
                              name: 'VolantisLive',
                              purpose: 'Broadcast & discover',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _ProductCard(
                              icon: Icons.video_call_rounded,
                              color: Color(0xFFD2BBFF),
                              name: 'VolantisConnect',
                              purpose: 'Meet & collaborate',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'ONE APP · TWO EXPERIENCES',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF88929B),
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
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

class _VolantisMark extends StatelessWidget {
  const _VolantisMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.20),
            blurRadius: 40,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: const Row(
          children: [
            Expanded(
              child: ColoredBox(
                color: Color(0xFF0EA5E9),
                child: Center(
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFF001E2F),
                    size: 30,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Color(0xFF8B5CF6),
                child: Center(
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 28,
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

class _ProductCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String purpose;

  const _ProductCard({
    required this.icon,
    required this.color,
    required this.name,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFF4F7FF),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            purpose,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA8B5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 40)],
      ),
    );
  }
}
