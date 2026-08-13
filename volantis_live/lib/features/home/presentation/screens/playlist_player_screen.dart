import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../home/data/models/playlist_model.dart';
import '../../../home/presentation/providers/playlist_provider.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final String companySlug;
  final String playlistSlug;

  const PlaylistPlayerScreen({
    super.key,
    required this.companySlug,
    required this.playlistSlug,
  });

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen> {
  static const _bg = Color(0xFF0B1326);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistPlayerProvider>().loadPlaylist(
        companySlug: widget.companySlug,
        playlistSlug: widget.playlistSlug,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<PlaylistPlayerProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }

            if (provider.error != null) {
              return _buildErrorState(provider.error!);
            }

            if (provider.currentPlaylist == null) {
              return _buildErrorState('Playlist not found');
            }

            return _buildContent(provider);
          },
        ),
      ),
    );
  }

  Widget _buildContent(PlaylistPlayerProvider provider) {
    final playlist = provider.currentPlaylist!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
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

  Widget _buildPlaylistHeader(
    PlaylistModel playlist,
    PlaylistPlayerProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primary.withOpacity(0.2),
                  _primaryCont.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(height: 12),
                  Text(
                    playlist.title,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (playlist.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      playlist.description!,
                      style: const TextStyle(color: _onVariant, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.format_list_numbered,
                label: '${playlist.itemCount} items',
              ),
              const SizedBox(width: 8),
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
                  ? () => _playAll(provider)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                provider.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                provider.isPlaying ? 'Pause' : 'Play All',
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
