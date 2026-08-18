import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:floating/floating.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../home/data/models/playlist_model.dart';
import '../../../home/presentation/providers/playlist_provider.dart';
import '../../../home/presentation/widgets/playlist_video_player.dart';
import '../../../../services/audio_manager.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final String companySlug;
  final String playlistSlug;
  final bool is_recording;

  const PlaylistPlayerScreen({
    super.key,
    required this.companySlug,
    required this.playlistSlug,
    this.is_recording = false,
  });

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

const _bg = Color(0xFF0B1326);
const _glassCard = Color(0xFF171F33);
const _surfaceHigh = Color(0xFF222A3D);
const _primary = Color(0xFF89CEFF);
const _primaryCont = Color(0xFF0EA5E9);
const _onPrimary = Color(0xFF00344D);
const _onSurface = Color(0xFFDAE2FD);
const _onVariant = Color(0xFFBEC8D2);
const _outline = Color(0xFF88929B);
const _outlineVar = Color(0xFF3E4850);

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen> {
  late final PlaylistPlayerProvider _provider;

  // Fullscreen (is_recording == true) control-chrome state.
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  bool get _isFullScreenMode => widget.is_recording;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PlaylistPlayerProvider>();

    if (_isFullScreenMode) {
      // Go edge-to-edge/immersive for a true full-screen player.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _scheduleHideControls();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.setPlayerScreenVisible(true);
      // Always delegate to loadPlaylist — it already short-circuits when
      // the *same* playlist is loaded (resume path) and properly stops old
      // playback when a *different* playlist is requested.

      if (!widget.is_recording) {
        // If this is a full-screen recording, we want to start playback immediately.
        _provider.loadPlaylist(
          companySlug: widget.companySlug,
          playlistSlug: widget.playlistSlug,
        );
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    if (_isFullScreenMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _provider.setPlayerScreenVisible(false);
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullScreenMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Full-screen (single recording) — kill playback on back.
        _provider.closePlayer();
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: _isFullScreenMode
            ? const Color.fromARGB(255, 194, 128, 128)
            : _bg,
        body: SafeArea(
          top: !_isFullScreenMode,
          bottom: !_isFullScreenMode,
          child: Consumer<PlaylistPlayerProvider>(
            builder: (context, provider, _) {
              if (!widget.is_recording && !provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }

              if (!widget.is_recording && provider.currentPlaylist == null) {
                return _buildErrorState(provider.error ?? 'Playlist not found');
              }

              if (_isFullScreenMode) {
                return PiPSwitcher(
                  floating: provider.floating,
                  childWhenDisabled: _buildFullScreenPlayer(provider),
                  childWhenEnabled: _buildPipContent(provider),
                );
              }

              return PiPSwitcher(
                floating: provider.floating,
                childWhenDisabled: _buildContent(provider),
                childWhenEnabled: _buildPipContent(provider),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Simplified view shown when the OS is in PiP mode — only the video,
  /// no app bar, no playlist header, no controls chrome.
  Widget _buildPipContent(PlaylistPlayerProvider provider) {
    final item = provider.currentItem;
    final controller = provider.videoController;
    if (item == null || controller == null || !controller.value.isInitialized) {
      return Container(color: _bg);
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio.isFinite
              ? controller.value.aspectRatio
              : 16 / 9,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  // ── Full-screen interactive player (is_recording == true) ────────────────

  Widget _buildFullScreenPlayer(PlaylistPlayerProvider provider) {
    final item = provider.currentItem;

    if (item == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: item.isVideo
                ? _buildFullScreenVideo(provider)
                : _buildFullScreenAudio(provider, item),
          ),
          IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  _fullScreenTopBar(item),
                  const Spacer(),
                  if (item.isVideo) _fullScreenVideoControls(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fullScreenTopBar(PlaylistItemModel item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                _provider.closePlayer();
                if (context.mounted) context.pop();
              },
            ),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenVideo(PlaylistPlayerProvider provider) {
    final controller = provider.videoController;
    final hasError = provider.error != null;
    final canRender =
        controller != null && (controller.value.isInitialized || !hasError);

    if (!canRender) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            provider.error ?? 'Video unavailable',
            style: const TextStyle(color: _onVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio.isFinite
            ? controller.value.aspectRatio
            : 16 / 9,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _fullScreenVideoControls(PlaylistPlayerProvider provider) {
    final controller = provider.videoController;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final pos = value.position;
                  final dur = value.duration;
                  final maxVal = dur.inMilliseconds > 0
                      ? dur.inMilliseconds.toDouble()
                      : 1.0;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          activeTrackColor: _primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: _primary,
                          overlayColor: _primary.withOpacity(0.15),
                        ),
                        child: Slider(
                          value: pos.inMilliseconds.toDouble().clamp(0, maxVal),
                          max: maxVal,
                          onChanged: (v) {
                            provider.seek(Duration(milliseconds: v.toInt()));
                            _scheduleHideControls();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fmtDuration(pos),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _fmtDuration(dur),
                              style: const TextStyle(
                                color: Colors.white70,
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
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _fsControl(
                  icon: Icons.skip_previous_rounded,
                  size: 28,
                  enabled: provider.hasPrevious,
                  onTap: () => provider.previous(),
                ),
                _fsControl(
                  icon: Icons.replay_10_rounded,
                  size: 28,
                  enabled: true,
                  onTap: () => provider.skipBack(10),
                ),
                _fsPlayPause(provider),
                _fsControl(
                  icon: Icons.forward_10_rounded,
                  size: 28,
                  enabled: true,
                  onTap: () => provider.skipForward(10),
                ),
                _fsControl(
                  icon: Icons.skip_next_rounded,
                  size: 28,
                  enabled: provider.hasNext,
                  onTap: () => provider.next(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fsControl({
    required IconData icon,
    required double size,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: enabled ? Colors.white : Colors.white30,
        size: size,
      ),
      onPressed: enabled
          ? () {
              onTap();
              _scheduleHideControls();
            }
          : null,
    );
  }

  Widget _fsPlayPause(PlaylistPlayerProvider provider) {
    return GestureDetector(
      onTap: () {
        provider.togglePlayPause();
        _scheduleHideControls();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(
          provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  Widget _buildFullScreenAudio(
    PlaylistPlayerProvider provider,
    PlaylistItemModel item,
  ) {
    // Fall back to the shared audio "now playing" widget, centered fullscreen.
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: _AudioNowPlaying(provider: provider, item: item),
      ),
    );
  }

  // ── Playlist view (is_recording == false, unchanged) ─────────────────────

  Widget _buildContent(PlaylistPlayerProvider provider) {
    final playlist = provider.currentPlaylist!;
    final hasCurrentItem = provider.currentItem != null;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 470,
          backgroundColor: _bg,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _onSurface,
                size: 16,
              ),
            ),
          ),
          title: Text(
            playlist.title,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${playlist.itemCount} items',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildPlaylistHeader(playlist, provider),
            collapseMode: CollapseMode.parallax,
          ),
        ),
        // Only show Now Playing section if there's actually a current item
        if (hasCurrentItem)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(child: _buildNowPlaying(provider)),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = playlist.items[index];
              return _buildPlaylistItem(item, index, provider);
            }, childCount: playlist.items.length),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  // ── Now playing ──────────────────────────────────────────────────────────

  Widget _buildNowPlaying(PlaylistPlayerProvider provider) {
    final item = provider.currentItem!;

    if (item.isVideo) {
      return _buildVideoNowPlaying(provider, item);
    }
    return _AudioNowPlaying(provider: provider, item: item);
  }

  Widget _buildVideoNowPlaying(
    PlaylistPlayerProvider provider,
    PlaylistItemModel item,
  ) {
    final controller = provider.videoController;
    final hasError = provider.error != null;
    final canRenderPlayer =
        controller != null && (controller.value.isInitialized || !hasError);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canRenderPlayer)
          PlaylistVideoPlayer(
            key: ValueKey('video_${item.id}'),
            controller: controller,
            thumbnailUrl: item.thumbnailUrl,
          )
        else
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                provider.error ?? 'Video unavailable',
                style: const TextStyle(color: _onVariant, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        const SizedBox(height: 12),
        _NowPlayingMetaBar(provider: provider, item: item),
      ],
    );
  }

  Widget _buildPlaylistHeader(
    PlaylistModel playlist,
    PlaylistPlayerProvider provider,
  ) {
    final hasCurrentItem = provider.currentItem != null;
    final isPlaying = provider.isPlaying;

    // Determine the correct button state
    String buttonLabel;
    IconData buttonIcon;

    if (isPlaying) {
      buttonLabel = 'Pause';
      buttonIcon = Icons.pause_rounded;
    } else if (hasCurrentItem) {
      buttonLabel = 'Resume';
      buttonIcon = Icons.play_arrow_rounded;
    } else {
      buttonLabel = 'Play All';
      buttonIcon = Icons.playlist_play_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(playlist),
          const SizedBox(height: 16),
          Text(
            playlist.title,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          if (playlist.description != null &&
              playlist.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              playlist.description!,
              style: const TextStyle(color: _onVariant, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (provider.companyName != null &&
                  provider.companyName!.isNotEmpty)
                _buildCompanyChip(provider),
              _buildInfoChip(
                icon: Icons.format_list_numbered,
                label: '${playlist.itemCount} items',
              ),
              if (playlist.formattedTotalDuration.isNotEmpty)
                _buildInfoChip(
                  icon: Icons.schedule_rounded,
                  label: playlist.formattedTotalDuration,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: playlist.items.isNotEmpty
                  ? () => _onPrimaryAction(provider)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(buttonIcon),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(PlaylistModel playlist) {
    final cover = playlist.thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: cover != null && cover.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                placeholder: (_, __) => _coverPlaceholder(playlist),
                errorWidget: (_, __, ___) => _coverPlaceholder(playlist),
              )
            : _coverPlaceholder(playlist),
      ),
    );
  }

  Widget _coverPlaceholder(PlaylistModel playlist) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary.withOpacity(0.2), _primaryCont.withOpacity(0.1)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_play_rounded,
                color: _primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                playlist.title,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyChip(PlaylistPlayerProvider provider) {
    final name = provider.companyName!;
    final logo = provider.companyLogoUrl;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: logo != null && logo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logo,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _companyLogoFallback(),
                  )
                : _companyLogoFallback(),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyLogoFallback() {
    return Container(
      width: 18,
      height: 18,
      color: _surfaceHigh,
      child: const Icon(Icons.business_rounded, color: _primary, size: 11),
    );
  }

  void _onPrimaryAction(PlaylistPlayerProvider provider) {
    if (provider.currentPlaylist?.items.isNotEmpty == true) {
      // If there's a current item, play it (resume/pause)
      // If no current item, start from the first item
      if (provider.currentItem != null) {
        // Toggle play/pause if there's a current item
        provider.togglePlayPause();
      } else {
        // Start playing from the first item
        provider.playItem(provider.currentPlaylist!.items.first);
      }
    }
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _outline, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _onVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(
    PlaylistItemModel item,
    int index,
    PlaylistPlayerProvider provider,
  ) {
    final isCurrentItem = provider.currentItem?.id == item.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentItem ? _primary.withOpacity(0.1) : _glassCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentItem
              ? _primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: ListTile(
        onTap: () => _playItem(provider, item),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (item.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => _buildMediaIcon(item),
                  ),
                )
              else
                _buildMediaIcon(item),
              if (isCurrentItem && provider.isPlaying)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: _onPrimary,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          '${index + 1}. ${item.title}',
          style: TextStyle(
            color: isCurrentItem ? _primary : _onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              item.isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded,
              color: _outline,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              item.formattedDuration,
              style: const TextStyle(color: _outline, fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isCurrentItem && provider.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            color: _primary,
            size: 36,
          ),
          onPressed: () => _playItem(provider, item),
        ),
      ),
    );
  }

  Widget _buildMediaIcon(PlaylistItemModel item) {
    return Icon(
      item.isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded,
      color: _primary,
      size: 24,
    );
  }

  void _playItem(PlaylistPlayerProvider provider, PlaylistItemModel item) {
    provider.playItem(item);
  }

  void _playAll(PlaylistPlayerProvider provider) {
    if (provider.currentPlaylist?.items.isNotEmpty == true) {
      final firstItem = provider.currentPlaylist!.items.first;
      provider.playItem(firstItem);
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _onVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surfaceHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    color: _onSurface,
                    fontWeight: FontWeight.w700,
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

// ── Now-playing meta bar (shared by audio & video) ────────────────────────────

class _NowPlayingMetaBar extends StatelessWidget {
  final PlaylistPlayerProvider provider;
  final PlaylistItemModel item;

  const _NowPlayingMetaBar({required this.provider, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _barButton(
            icon: Icons.skip_previous_rounded,
            enabled: provider.hasPrevious,
            onTap: () => provider.previous(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Now Playing',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _barButton(
            icon: Icons.skip_next_rounded,
            enabled: provider.hasNext,
            onTap: () => provider.next(),
          ),
          const SizedBox(width: 4),
          _barButton(
            icon: Icons.close_rounded,
            enabled: true,
            onTap: () {
              provider.closePlayer();
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _barButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: enabled ? _onVariant : _outlineVar, size: 22),
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Inline audio player (uses the shared AudioManager recording player) ──────

class _AudioNowPlaying extends StatelessWidget {
  final PlaylistPlayerProvider provider;
  final PlaylistItemModel item;

  const _AudioNowPlaying({required this.provider, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<AudioState>(
        stream: AudioManager.instance.stateStream,
        initialData: AudioManager.instance.currentState,
        builder: (context, snap) {
          final state = snap.data ?? const AudioState();
          final isPlaying =
              state.sourceType == AudioSourceType.recording && state.isPlaying;
          final isLoading =
              state.sourceType == AudioSourceType.recording &&
              state.isConnecting;

          return Column(
            children: [
              Row(
                children: [
                  _audioThumbnail(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Now Playing',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _audioCloseButton(context),
                ],
              ),
              const SizedBox(height: 8),
              _audioProgress(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _audioControl(
                    icon: Icons.skip_previous_rounded,
                    size: 26,
                    enabled: provider.hasPrevious,
                    onTap: () => provider.previous(),
                  ),
                  _audioControl(
                    icon: Icons.replay_10_rounded,
                    size: 26,
                    enabled: true,
                    onTap: () => provider.skipBack(10),
                  ),
                  _audioPlayPause(isPlaying: isPlaying, isLoading: isLoading),
                  _audioControl(
                    icon: Icons.forward_10_rounded,
                    size: 26,
                    enabled: true,
                    onTap: () => provider.skipForward(10),
                  ),
                  _audioControl(
                    icon: Icons.skip_next_rounded,
                    size: 26,
                    enabled: provider.hasNext,
                    onTap: () => provider.next(),
                  ),
                ],
              ),
              if (provider.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _audioThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: item.thumbnailUrl != null
          ? CachedNetworkImage(
              imageUrl: item.thumbnailUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (_, __) => _thumbnailPlaceholder(),
              errorWidget: (_, __, ___) => _thumbnailPlaceholder(),
            )
          : _thumbnailPlaceholder(),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.audiotrack_rounded, color: _primary, size: 26),
    );
  }

  Widget _audioCloseButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close_rounded, color: _onVariant, size: 20),
      onPressed: () {
        provider.closePlayer();
        if (context.mounted) context.pop();
      },
    );
  }

  Widget _audioProgress() {
    return StreamBuilder<Duration?>(
      stream: AudioManager.instance.positionStream,
      builder: (context, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: AudioManager.instance.durationStream,
          builder: (context, durSnap) {
            final dur =
                durSnap.data ??
                (item.durationSeconds != null
                    ? Duration(seconds: item.durationSeconds!)
                    : Duration.zero);
            final maxVal = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    activeTrackColor: _primary,
                    inactiveTrackColor: _outlineVar,
                    thumbColor: _primary,
                    overlayColor: _primary.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: pos.inSeconds.toDouble().clamp(0, maxVal),
                    max: maxVal,
                    onChanged: (v) =>
                        provider.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmtDuration(pos),
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _fmtDuration(dur),
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
      },
    );
  }

  Widget _audioPlayPause({required bool isPlaying, required bool isLoading}) {
    return GestureDetector(
      onTap: () => provider.togglePlayPause(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _primaryCont],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _onPrimary,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _onPrimary,
                  size: 30,
                ),
        ),
      ),
    );
  }

  Widget _audioControl({
    required IconData icon,
    required double size,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: enabled ? _onVariant : _outlineVar, size: size),
      onPressed: enabled ? onTap : null,
    );
  }
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
