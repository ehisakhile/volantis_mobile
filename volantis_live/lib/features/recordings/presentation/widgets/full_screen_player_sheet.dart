import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/recordings_provider.dart';

/// Full-screen player bottom sheet — VolantisLive dark glass design
class FullScreenPlayerSheet extends StatelessWidget {
  const FullScreenPlayerSheet({super.key});

  // ── Design tokens ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0B1326);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _surfaceBright = Color(0xFF2D3449);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlayerOpen || provider.currentRecording == null) {
          return const SizedBox.shrink();
        }

        final recording = provider.currentRecording!;

        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              // Ambient glow
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD2BBFF).withOpacity(0.05),
                  ),
                ),
              ),

              Column(
                children: [
                  // ── Handle ────────────────────────────────────────────
                  _Handle(),

                  // ── Header row ────────────────────────────────────────
                  _buildHeader(context, provider),

                  // ── Scrollable body ───────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // Album art
                          _buildAlbumArt(recording),
                          const SizedBox(height: 32),

                          // Title + description
                          _buildTrackInfo(recording),
                          const SizedBox(height: 36),

                          // Progress bar
                          _buildProgressBar(context, provider),
                          const SizedBox(height: 28),

                          // Playback controls
                          _buildControls(provider),
                          const SizedBox(height: 28),

                          // Speed control
                          _buildSpeedControl(provider),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, RecordingsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          // Down arrow
          _HeaderBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () {
              provider.minimize();
              Navigator.of(context).maybePop();
            },
          ),
          const Expanded(
            child: Text(
              AppStrings.nowPlaying,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // _HeaderBtn(icon: Icons.more_horiz_rounded, onTap: () {}),
        ],
      ),
    );
  }

  // ── Album art ─────────────────────────────────────────────────────────────

  Widget _buildAlbumArt(recording) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.12),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: recording.hasThumbnail
            ? CachedNetworkImage(
                imageUrl: recording.thumbnailUrl!,
                width: 260,
                height: 260,
                fit: BoxFit.cover,
                placeholder: (_, __) => _artPlaceholder(),
                errorWidget: (_, __, ___) => _artPlaceholder(),
              )
            : _artPlaceholder(),
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.mic_rounded, color: _primary, size: 72),
    );
  }

  // ── Track info ────────────────────────────────────────────────────────────

  Widget _buildTrackInfo(recording) {
    return Column(
      children: [
        Text(
          recording.title,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (recording.description != null &&
            recording.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            recording.description!,
            style: const TextStyle(
              color: _onVariant,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar(BuildContext context, RecordingsProvider provider) {
    return StreamBuilder<Duration>(
      stream: provider.positionStream,
      builder: (_, snap) {
        final position = snap.data ?? Duration.zero;
        final duration = provider.duration ?? Duration.zero;
        final maxVal = duration.inSeconds.toDouble().clamp(
          1.0,
          double.infinity,
        );

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: _primary,
                inactiveTrackColor: _outlineVar,
                thumbColor: _primary,
                overlayColor: _primary.withOpacity(0.15),
              ),
              child: Slider(
                value: position.inSeconds.toDouble().clamp(0, maxVal),
                max: maxVal,
                onChanged: (v) => provider.seek(Duration(seconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(position),
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _fmt(duration),
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Widget _buildControls(RecordingsProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip back
        _CtrlBtn(
          icon: Icons.replay_10_rounded,
          onTap: () => provider.skipBack(10),
          size: 28,
        ),
        const SizedBox(width: 20),

        // Play / Pause — large gradient circle
        StreamBuilder<PlayerState>(
          stream: provider.playerStateStream,
          builder: (_, snap) {
            final playing = snap.data?.playing ?? false;
            return GestureDetector(
              onTap: () => provider.togglePlayPause(),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryCont],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _onPrimary,
                  size: 36,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 20),

        // Skip forward
        _CtrlBtn(
          icon: Icons.forward_10_rounded,
          onTap: () => provider.skipForward(10),
          size: 28,
        ),
      ],
    );
  }

  // ── Speed control ─────────────────────────────────────────────────────────

  Widget _buildSpeedControl(RecordingsProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          AppStrings.playbackSpeed,
          style: TextStyle(
            color: _onVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<double>(
          initialValue: 1.0,
          color: const Color(0xFF222A3D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (speed) => provider.setSpeed(speed),
          itemBuilder: (_) => [
            _speedItem(0.5),
            _speedItem(0.75),
            _speedItem(1.0),
            _speedItem(1.25),
            _speedItem(1.5),
            _speedItem(2.0),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _outlineVar.withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.speed_rounded, color: _primary, size: 14),
                SizedBox(width: 6),
                Text(
                  '1.0×',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, color: _outline, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<double> _speedItem(double value) {
    return PopupMenuItem(
      value: value,
      child: Text(
        '${value}×',
        style: const TextStyle(color: _onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Handle ────────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF3E4850),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Header icon button ────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFFBEC8D2), size: 20),
      ),
    );
  }
}

// ── Control button ────────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CtrlBtn({required this.icon, required this.onTap, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFFDAE2FD), size: size),
      ),
    );
  }
}
