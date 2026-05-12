import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';

enum UpdateDecision { updateNow, later }

class AppUpdateManager extends ChangeNotifier {
  static final AppUpdateManager _instance = AppUpdateManager._internal();
  factory AppUpdateManager() => _instance;
  AppUpdateManager._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  static const _keyMinSupportedVersion = 'min_supported_version';
  static const _keyLatestVersion = 'latest_version';
  static const _keyForceUpdateMessage = 'force_update_message';
  static const _keyUpdateMessage = 'update_message';
  static const _keyAppStoreUrl = 'app_store_url';
  static const _keyPlayStoreUrl = 'play_store_url';

  static const _defaults = {
    _keyMinSupportedVersion: '1.0.0',
    _keyLatestVersion: '1.0.5',
    _keyForceUpdateMessage: 'Please update to continue using the app.',
    _keyUpdateMessage:
        'A new version is available. Update for the best experience.',
    _keyAppStoreUrl: 'https://apps.apple.com/us/app/volantislive/id6762115839',
    _keyPlayStoreUrl:
        'https://play.google.com/store/apps/details?id=com.volantislive.volantislive',
  };

  String? _currentVersion;
  bool _isInitialized = false;
  bool updateCheckComplete = false;
  bool get isUpdateCheckComplete => updateCheckComplete;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );

      await _remoteConfig.setDefaults(_defaults);

      try {
        await _remoteConfig.fetch();
        await _remoteConfig.activate();
      } catch (e) {
        debugPrint('[AppUpdateManager] Fetch error (using defaults): $e');
      }

      _isInitialized = true;
      debugPrint(
        '[AppUpdateManager] Initialized. Current version: $_currentVersion',
      );
    } catch (e) {
      debugPrint('[AppUpdateManager] Init error: $e');
    }
  }

  Future<bool> checkForUpdates(
    BuildContext context, {
    Function? onSkipAuth,
  }) async {
    if (updateCheckComplete) {
      debugPrint('[AppUpdateManager] Update check already complete, skipping');
      return true;
    }

    if (!_isInitialized) await initialize();

    final minVersion = _remoteConfig.getString(_keyMinSupportedVersion);
    final latestVersion = _remoteConfig.getString(_keyLatestVersion);
    final forceMessage = _remoteConfig.getString(_keyForceUpdateMessage);
    final updateMessage = _remoteConfig.getString(_keyUpdateMessage);

    debugPrint(
      '[AppUpdateManager] Remote Config - minVersion: $minVersion, latestVersion: $latestVersion',
    );
    debugPrint(
      '[AppUpdateManager] Remote Config - currentVersion: $_currentVersion',
    );

    final isBelowMin = _isVersionLower(_currentVersion!, minVersion);
    final isBelowLatest = _isVersionLower(_currentVersion!, latestVersion);
    debugPrint(
      '[AppUpdateManager] isBelowMin: $isBelowMin, isBelowLatest: $isBelowLatest',
    );

    if (isBelowMin) {
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          await _showForceUpdateDialog(context, forceMessage);
        }
      }
      // Don't set updateCheckComplete here for force update - user must update
      return false;
    }

    if (_isVersionLower(_currentVersion!, latestVersion)) {
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          final decision = await _showOptionalUpdatePage(
            context,
            message: updateMessage,
            latestVersion: latestVersion,
          );
          // Mark as complete after user makes a decision
          updateCheckComplete = true;
          notifyListeners();
          if (decision == UpdateDecision.updateNow) {
            await _openStore();
            // Don't auto-navigate - user went to store
            return false;
          }
          // User chose "Continue" - return true to allow navigation
          return true;
        }
      }
    }

    updateCheckComplete = true;
    notifyListeners();
    return true;
  }

  bool _isVersionLower(String current, String target) {
    try {
      final cleanCurrent = current.split('+').first.split('-').first;
      final cleanTarget = target.split('+').first.split('-').first;

      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final targetParts = cleanTarget.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final t = i < targetParts.length ? targetParts[i] : 0;
        if (c < t) return true;
        if (c > t) return false;
      }
      return false;
    } catch (e) {
      debugPrint('[AppUpdateManager] Version compare error: $e');
      return false;
    }
  }

  Future<void> _showForceUpdateDialog(
    BuildContext context,
    String message,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.system_update,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Update Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  updateCheckComplete = true;
                  notifyListeners();
                  _openStore();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Update Now',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> notifychanges(BuildContext context) async {
    notifyListeners();
  }

  Future<UpdateDecision> _showOptionalUpdatePage(
    BuildContext context, {
    required String message,
    required String latestVersion,
  }) async {
    final decision = await Navigator.of(context).push<UpdateDecision>(
      MaterialPageRoute(
        builder: (_) => UpdateAvailablePage(
          message: message,
          currentVersion: _currentVersion ?? 'Unknown',
          latestVersion: latestVersion,
        ),
      ),
    );
    return decision ?? UpdateDecision.later;
  }

  Future<void> _openStore() async {
    final String url;
    if (Platform.isIOS) {
      url = _remoteConfig.getString(_keyAppStoreUrl);
    } else {
      url = _remoteConfig.getString(_keyPlayStoreUrl);
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? get currentVersion => _currentVersion;
}
// Assumes AppColors is already imported from your colors file.
// import 'app_colors.dart';

class UpdateAvailablePage extends StatefulWidget {
  final String message;
  final String currentVersion;
  final String latestVersion;
  final List<String> changelog;
  final String fileSize;
  final Function(UpdateDecision)? onDecision;

  const UpdateAvailablePage({
    super.key,
    required this.message,
    required this.currentVersion,
    required this.latestVersion,
    this.changelog = const [
      'Improved live stream performance',
      'Bug fixes & stability improvements',
      'Refreshed player UI design',
    ],
    this.fileSize = '24.6 MB',
    this.onDecision,
  });

  @override
  State<UpdateAvailablePage> createState() => _UpdateAvailablePageState();
}

class _UpdateAvailablePageState extends State<UpdateAvailablePage>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _iconScale;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
      ),
    );

    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background decorative orbs
          _BackgroundOrbs(),

          // Grid pattern overlay
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // "NEW RELEASE" status pill
                      _StatusPill(),

                      const SizedBox(height: 28),

                      // Animated icon
                      ScaleTransition(
                        scale: _iconScale,
                        child: _AnimatedIcon(
                          orbitController: _orbitController,
                          pulseAnimation: _pulse,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Update Available',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Version badge
                      _VersionBadge(
                        current: widget.currentVersion,
                        latest: widget.latestVersion,
                      ),

                      const SizedBox(height: 16),

                      // Changelog
                      _ChangelogCard(items: widget.changelog),

                      const Spacer(),

                      // Update Now button
                      _PrimaryButton(
                        onTap: () {
                          widget.onDecision?.call(UpdateDecision.updateNow);
                          Navigator.of(context).pop(UpdateDecision.updateNow);
                        },
                      ),

                      const SizedBox(height: 10),

                      // Continue button
                      _SecondaryButton(
                        onTap: () {
                          widget.onDecision?.call(UpdateDecision.later);
                          Navigator.of(context).pop(UpdateDecision.later);
                        },
                      ),

                      const SizedBox(height: 10),

                      // File size tag
                      Text(
                        '${widget.fileSize} · FREE UPDATE',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _BackgroundOrbs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        'NEW RELEASE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _AnimatedIcon extends StatelessWidget {
  final AnimationController orbitController;
  final Animation<double> pulseAnimation;

  const _AnimatedIcon({
    required this.orbitController,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer spinning dashed ring
          AnimatedBuilder(
            animation: orbitController,
            builder: (_, __) => Transform.rotate(
              angle: orbitController.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(120, 120),
                painter: _DashedCirclePainter(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),

          // Mid ring
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),

          // Pulsing glow
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, __) => Container(
              width: 76 * pulseAnimation.value + 4,
              height: 76 * pulseAnimation.value + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Core icon circle
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.primaryGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.system_update_alt_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),

          // Cyan notification dot
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String current;
  final String latest;

  const _VersionBadge({required this.current, required this.latest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Old version with strikethrough
          Text(
            current,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLight,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.secondaryLight,
            ),
          ),

          const SizedBox(width: 12),

          // Arrow with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: AppColors.primaryGradient,
            ).createShader(bounds),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 12),

          // New version with gradient text
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: AppColors.primaryGradient,
            ).createShader(bounds),
            child: Text(
              latest,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  final List<String> items;

  const _ChangelogCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: AppColors.primaryGradient),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PrimaryButton({required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C63FF), Color(0xFF4A42CC)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle cyan sheen overlay
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 120,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.accent.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Update Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SecondaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textTertiary,
          overlayColor: AppColors.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: const Text(
          'Continue without updating',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1;
    const dashCount = 24;
    const dashLength = 0.18;
    const gapLength = 1 - dashLength;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * math.pi;
      final sweepAngle = dashLength * (2 * math.pi / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
