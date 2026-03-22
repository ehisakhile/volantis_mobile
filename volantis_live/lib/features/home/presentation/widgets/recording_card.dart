import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../recordings/data/models/recording_model.dart';
import '../../../recordings/presentation/providers/recordings_provider.dart';
import '../../../../core/constants/app_colors.dart';

/// Recording card widget for displaying recordings on the home screen
class RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback onTap;
  final double width;
  final double height;

  const RecordingCard({
    super.key,
    required this.recording,
    required this.onTap,
    this.width = 140,
    this.height = 180,
  });

  // Design tokens (mirroring the VolantisLive home screen)
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: _surfaceHigh,
                      child: recording.hasThumbnail
                          ? CachedNetworkImage(
                              imageUrl: recording.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildPlaceholder(),
                              errorWidget: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _glassCard.withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play button overlay
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF00344D),
                        size: 22,
                      ),
                    ),
                  ),
                  // Duration badge
                  if (recording.durationSeconds != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          recording.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Download button
                  Positioned(top: 6, right: 6, child: _buildDownloadButton()),
                ],
              ),
            ),
            // Title and info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Date
                    Text(
                      _formatDate(recording.createdAt),
                      style: const TextStyle(color: _onVariant, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: _surfaceHigh,
      child: const Center(child: Icon(Icons.mic, color: _outline, size: 32)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildDownloadButton() {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        final status = provider.getDownloadStatus(recording.id);

        return GestureDetector(
          onTap: () => _handleDownloadTap(provider, status),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getDownloadIcon(status),
              color: _getDownloadColor(status),
              size: 18,
            ),
          ),
        );
      },
    );
  }

  void _handleDownloadTap(RecordingsProvider provider, dynamic status) {
    if (status.toString().contains('downloaded')) {
      // Already downloaded - play offline
      provider.playDownloadedRecording(recording.id);
    } else if (status.toString().contains('downloading') ||
        status.toString().contains('queued')) {
      // Currently downloading - show info or cancel
      _showDownloadInfo();
    } else {
      // Not downloaded - start download
      provider.downloadRecording(recording, downloadUrl: recording.s3Url);
    }
  }

  void _showDownloadInfo() {
    // Could show a snackbar or dialog with download progress
    debugPrint('Download in progress for: ${recording.title}');
  }

  IconData _getDownloadIcon(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('downloaded')) {
      return Icons.download_done;
    } else if (statusStr.contains('downloading')) {
      return Icons.downloading;
    } else if (statusStr.contains('queued')) {
      return Icons.hourglass_empty;
    } else {
      return Icons.download;
    }
  }

  Color _getDownloadColor(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('downloaded')) {
      return AppColors.primary;
    } else if (statusStr.contains('downloading') ||
        statusStr.contains('queued')) {
      return AppColors.primary;
    } else {
      return Colors.white;
    }
  }
}
