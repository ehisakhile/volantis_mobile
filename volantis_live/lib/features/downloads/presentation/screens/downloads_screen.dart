import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../recordings/data/models/recording_download.dart';
import '../../../recordings/presentation/providers/recordings_provider.dart';
import '../../../../services/download_manager.dart';
import '../providers/downloads_provider.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  // Volantis Dark Glass Theme Tokens
  static const _bg = Color(0xFF0B1326);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _error = Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadsProvider>().loadDownloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          AppStrings.offlineDownloads,
          style: TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [_buildHeaderActions()],
      ),
      body: Stack(
        children: [
          // Background Glow Effect
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withOpacity(0.05),
              ),
            ),
          ),
          Consumer<DownloadsProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }

              final hasActive = provider.activeDownloads.isNotEmpty;
              final hasCompleted = provider.downloads.isNotEmpty;

              if (!hasActive && !hasCompleted) return _buildEmptyState();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildStorageInfo(provider)),

                  if (hasActive) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader('Active Downloads'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildActiveDownloadItem(
                          provider.activeDownloads[index],
                          provider,
                        ),
                        childCount: provider.activeDownloads.length,
                      ),
                    ),
                  ],

                  if (hasCompleted) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader('Your Library'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDownloadItem(
                          provider.downloads[index],
                          provider,
                        ),
                        childCount: provider.downloads.length,
                      ),
                    ),
                  ],

                  SliverToBoxAdapter(
                    child: _buildSectionHeader('Explore More'),
                  ),
                  SliverToBoxAdapter(child: _buildRecommendedSection(provider)),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Consumer<DownloadsProvider>(
      builder: (context, provider, _) {
        if (provider.downloads.isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: _onVariant),
          onPressed: () => _showClearAllDialog(),
        );
      },
    );
  }

  Widget _buildStorageInfo(DownloadsProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cloud_done_outlined, color: _primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.downloads.length} Saved Recordings',
                  style: const TextStyle(
                    color: _onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Storage: ${provider.formatStorageSize(provider.totalStorageUsed)}',
                  style: const TextStyle(color: _onVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadItem(
    RecordingDownload download,
    DownloadsProvider provider,
  ) {
    return Dismissible(
      key: Key('dl_${download.recordingId}'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) => _showDeleteDialog(download.title),
      onDismissed: (_) => provider.deleteDownload(download.recordingId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          onTap: () => provider.playDownloaded(download.recordingId),
          leading: _buildThumbnail(download.thumbnailUrl),
          title: Text(
            download.title,
            style: const TextStyle(
              color: _onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: _onVariant),
                  const SizedBox(width: 4),
                  Text(
                    download.formattedDuration,
                    style: const TextStyle(color: _onVariant, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.save_outlined, size: 14, color: _onVariant),
                  const SizedBox(width: 4),
                  Text(
                    download.formattedFileSize,
                    style: const TextStyle(color: _onVariant, fontSize: 12),
                  ),
                ],
              ),
              if (download.lastPosition > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: download.progress,
                    backgroundColor: Colors.white10,
                    color: _primary,
                    minHeight: 2,
                  ),
                ),
              ],
            ],
          ),
          trailing: const Icon(
            Icons.play_circle_outline,
            color: _primary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDownloadItem(
    ActiveDownloadTask task,
    DownloadsProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceHigh.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildThumbnail(task.thumbnailUrl, isDownloading: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: Colors.white10,
                    color: _primary,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _onVariant, size: 20),
            onPressed: () => provider.cancelDownload(task.recordingId),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? url, {bool isDownloading = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 54,
        height: 54,
        child: url != null
            ? CustomNetworkImage(imageUrl: url)
            : Container(
                color: _primary.withOpacity(0.1),
                child: Icon(
                  isDownloading ? Icons.downloading : Icons.headphones,
                  color: _primary,
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: _primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 80,
            color: _onVariant.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Downloads',
            style: TextStyle(
              color: _onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your offline library is currently empty.',
            style: TextStyle(color: _onVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Reuse logic for Recommended Cards but with Volantis Styling
  Widget _buildRecommendedSection(DownloadsProvider provider) {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildRecommendedCard(
            'Listen Offline',
            'Favorite recordings',
            Icons.headphones_rounded,
          ),
          _buildRecommendedCard(
            'Save Data',
            'Use WiFi only',
            Icons.wifi_rounded,
          ),
          _buildRecommendedCard(
            'Recent',
            'Pick up where you left',
            Icons.history_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCard(String title, String subtitle, IconData icon) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(0.15), _primary.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: _primary, size: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: _onVariant, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Dialogs ---
  Future<bool?> _showDeleteDialog(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Download?',
          style: TextStyle(color: _onSurface),
        ),
        content: Text(
          'Delete "$title" from your device?',
          style: const TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep', style: TextStyle(color: _onVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Library?',
          style: TextStyle(color: _onSurface),
        ),
        content: const Text(
          'This removes all offline recordings.',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _onVariant)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DownloadsProvider>().clearAllDownloads();
            },
            child: const Text('Clear All', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
  }
}
