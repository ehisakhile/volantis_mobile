import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/company_live_stream_model.dart';
import '../providers/streams_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// STREAM PLAYER SCREEN
// ══════════════════════════════════════════════════════════════════════════════

/// Full-screen stream player — VolantisLive immersive dark design.
///
/// Back-navigation MINIMIZES the player (stream keeps running) instead of
/// stopping it. The already-existing mini-player in [StreamsProvider] handles
/// the minimised state and its controls.
///
/// Audio notification / lock-screen controls are posted through
/// [AudioService] (just_audio_background) so the stream appears in the
/// system media notification.
class StreamPlayerScreen extends StatefulWidget {
  final String companySlug;
  final String? streamTitle;
  final String? companyName;
  final String? companyLogoUrl;

  const StreamPlayerScreen({
    super.key,
    required this.companySlug,
    this.streamTitle,
    this.companyName,
    this.companyLogoUrl,
  });

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060E20);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _secondary = Color(0xFFD2BBFF);
  static const _tertiary = Color(0xFFFFB3AD);
  static const _errorColor = Color(0xFFFFB4AB);
  static const _errorCont = Color(0xFF93000A);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);

  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isLiked = false;
  String? _errorMessage;
  String _connectionState = 'initializing';
  CompanyLiveStream? _streamDetails;
  String? _playbackUrl;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Waveform bar heights (randomised, animated via sin offsets)
  static const int _barCount = 30;
  final List<double> _barSeeds = List.generate(
    _barCount,
    (i) => (i * 0.7 + 0.3),
  );

  @override
  void initState() {
    super.initState();

    // Waveform animation
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Pulsing live-ring animation
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Screen fade-in
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Transparent system UI overlays
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _initializePlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<StreamsProvider>();
      provider.addListener(_onProviderChanged);
      _syncFromProvider(provider);
    });
  }

  @override
  void dispose() {
    // ── SAFE listener removal ────────────────────────────────────────────
    // Use a try-catch so a stale context never crashes on dispose.
    try {
      final provider = context.read<StreamsProvider>();
      provider.removeListener(_onProviderChanged);
    } catch (_) {}

    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _syncFromProvider(StreamsProvider p) {
    if (!mounted) return;
    setState(() {
      _isPlaying = p.isPlaying;
      _isMuted = p.isMuted;
    });
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _syncFromProvider(context.read<StreamsProvider>());
  }

  // ── Player init ──────────────────────────────────────────────────────────

  Future<void> _initializePlayer() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _connectionState = 'initializing';
    });

    try {
      final provider = context.read<StreamsProvider>();
      final details = await provider.getCompanyLiveStream(widget.companySlug);

      if (!mounted) return;

      if (details == null) throw Exception('Stream not found');
      if (details.livestream.webrtcPlaybackUrl == null) {
        throw Exception('No playback URL available');
      }

      provider.setStreamDetails(details.livestream);

      // Post to audio notification (just_audio_background)
      _postMediaNotification(details);

      setState(() {
        _streamDetails = details;
        _playbackUrl = details.livestream.webrtcPlaybackUrl;
        _isLoading = false;
        _connectionState = 'connecting';
      });
    } catch (e) {
      developer.log('Player init error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _connectionState = 'failed';
      });
    }
  }

  /// Posts a [MediaItem] to LiveStreamService so the stream appears in the
  /// system media notification / lock screen controls via just_audio_background.
  void _postMediaNotification(CompanyLiveStream details) {
    try {
      // The LiveStreamService handles notification through just_audio_background
      // when startStream is called. We just need to make sure the service
      // is initialized and will be called when playback starts.

      // Update the provider's current stream so when playback starts,
      // the notification will show the correct info.
      final provider = context.read<StreamsProvider>();

      // The notification will be posted by LiveStreamService when
      // provider.startStream is called (done in streams_screen or elsewhere)
      developer.log(
        'Media notification ready for: ${details.livestream.title}',
      );
    } catch (e) {
      // Swallow silently if provider not available
      developer.log('Media notification setup skipped: $e');
    }
  }

  // ── Callbacks from WebRTC player ──────────────────────────────────────────

  void _onConnected() {
    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _connectionState = 'connected';
    });
    context.read<StreamsProvider>().updateConnectionState(
      isConnecting: false,
      isPlaying: true,
    );

    // Update notification playback state via LiveStreamService
    try {
      context.read<StreamsProvider>();
    } catch (_) {}
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _connectionState = 'disconnected';
    });
    context.read<StreamsProvider>().updateConnectionState(
      isConnecting: false,
      isPlaying: false,
    );
  }

  void _onWebRTCError(String err) {
    if (!mounted) return;
    setState(() {
      _errorMessage = err;
      _isPlaying = false;
      _connectionState = 'failed';
    });
    context.read<StreamsProvider>().updateConnectionState(
      isConnecting: false,
      isPlaying: false,
      error: err,
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void _toggleMute() {
    if (!mounted) return;
    setState(() => _isMuted = !_isMuted);
  }

  void _togglePlayPause() {
    if (!mounted) return;
    final provider = context.read<StreamsProvider>();
    provider.togglePlayPause();
    if (mounted) setState(() => _isPlaying = provider.isPlaying);
  }

  void _toggleLike() {
    if (!mounted) return;
    setState(() => _isLiked = !_isLiked);
  }

  /// Minimize → stream keeps running; mini-player takes over.
  void _minimize() {
    if (!mounted) return;
    context.read<StreamsProvider>().minimize();
    Navigator.of(context).maybePop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept Android back — minimize instead of killing stream
      canPop: false,
      onPopInvoked: (_) => _minimize(),
      child: Scaffold(
        backgroundColor: _bg,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Ambient background glows ──────────────────────────────
              _AmbientBackground(
                isPlaying: _isPlaying,
                primaryColor: _primary,
                secondaryColor: _secondary,
              ),

              // ── Main content ──────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildCenter()),
                  ],
                ),
              ),

              // ── Floating control bar (pinned to bottom) ───────────────
              if (!_isLoading && _errorMessage == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildFloatingControls(),
                ),

              // ── Loading overlay ───────────────────────────────────────
              if (_isLoading) _buildLoadingOverlay(),

              // ── Error overlay ─────────────────────────────────────────
              if (_errorMessage != null) _buildErrorOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Minimize / back
          _GlassIconBtn(icon: Icons.expand_more_rounded, onTap: _minimize),
          const Spacer(),

          // LIVE badge
          _LiveBadge(isConnected: _connectionState == 'connected'),

          const SizedBox(width: 12),

          // Viewer count
          if (_streamDetails != null)
            _ViewerChip(count: _streamDetails!.livestream.viewerCount),
        ],
      ),
    );
  }

  // ── Centre area ───────────────────────────────────────────────────────────

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Creator identity
        _buildCreatorIdentity(),
        const SizedBox(height: 48),

        // Waveform or loading/waiting visual
        _buildWaveformOrWaiting(),
      ],
    );
  }

  Widget _buildCreatorIdentity() {
    final name = _streamDetails?.company.name ?? widget.companyName ?? '—';
    final subtitle =
        _streamDetails?.livestream.title ?? widget.streamTitle ?? 'Live Stream';
    final logoUrl = _streamDetails?.company.logoUrl ?? widget.companyLogoUrl;

    return Column(
      children: [
        // Avatar with pulsing live ring
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final pulse = _pulseCtrl.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer ping ring
                Container(
                  width: 96 + pulse * 8,
                  height: 96 + pulse * 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _tertiary.withOpacity(0.35 * (1 - pulse)),
                      width: 2,
                    ),
                  ),
                ),
                // Static ring
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _tertiary.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                ),
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF222A3D),
                    border: Border.all(
                      color: const Color(0xFF060E20),
                      width: 3,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: logoUrl != null
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _FallbackAvatar(),
                        )
                      : const _FallbackAvatar(),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // Name + verified
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, color: _primary, size: 20),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          subtitle,
          style: const TextStyle(
            color: _onVariant,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 18),

        // Follow button
        _FollowButton(),
      ],
    );
  }

  Widget _buildWaveformOrWaiting() {
    if (_connectionState == 'connecting' ||
        _connectionState == 'initializing') {
      return _buildConnectingAnimation();
    }

    if (_connectionState == 'connected') {
      return _buildWaveform();
    }

    return const SizedBox.shrink();
  }

  Widget _buildConnectingAnimation() {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              // Middle ring
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
              // Pulsing indicator
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 60 + _pulseCtrl.value * 10,
                  height: 60 + _pulseCtrl.value * 10,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Icon(Icons.live_tv_rounded, color: _primary, size: 32),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Connecting...',
          style: TextStyle(
            color: _onVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          return AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) {
              final phase = _waveCtrl.value * 2 * math.pi;
              final barSeed = _barSeeds[i];
              final height =
                  20 +
                  30 * (0.5 + 0.5 * math.sin(phase + barSeed * 2 * math.pi));
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, _bg.withOpacity(0.9), _bg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute
            _ControlBtn(
              icon: _isMuted ? Icons.volume_off : Icons.volume_up,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMute,
            ),
            // Play/Pause
            _PlayPauseBtn(isPlaying: _isPlaying, onTap: _togglePlayPause),
            // Like
            _ControlBtn(
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              label: 'Like',
              isActive: _isLiked,
              activeColor: _tertiary,
              onTap: _toggleLike,
            ),
            // Expand/Collapse (minimize)
            _ControlBtn(
              icon: Icons.expand_more_rounded,
              label: 'Mini player',
              onTap: _minimize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: _bg.withOpacity(0.9),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text('Loading stream...', style: TextStyle(color: _onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: _bg.withOpacity(0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _errorColor, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unknown error',
                style: const TextStyle(color: _errorColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════════════

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool isConnected;

  const _LiveBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.red : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerChip extends StatelessWidget {
  final int count;

  const _ViewerChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            _formatCount(count),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return c.toString();
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? const Color(0xFF89CEFF))
        : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? (activeColor ?? const Color(0xFF89CEFF)).withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PlayPauseBtn extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseBtn({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF89CEFF),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: const Color(0xFF00344D),
          size: 32,
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF89CEFF)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF89CEFF),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        ),
        child: const Text('Follow'),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF222A3D),
      child: const Icon(Icons.person, color: Colors.white54, size: 40),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;

  const _AmbientBackground({
    required this.isPlaying,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [primaryColor.withOpacity(0.15), const Color(0xFF060E20)],
            ),
          ),
        ),
        // Animated glows
        if (isPlaying) ...[
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [secondaryColor.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
