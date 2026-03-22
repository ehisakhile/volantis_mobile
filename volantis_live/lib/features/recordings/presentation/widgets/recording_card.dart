import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/models/recording_model.dart';
import '../providers/recordings_provider.dart';
import 'package:intl/intl.dart';

/// Card widget for displaying a single recording in a list
class RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback onTap;
  final int? replayCount;

  const RecordingCard({
    super.key,
    required this.recording,
    required this.onTap,
    this.replayCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              _buildThumbnail(),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      recording.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Duration and date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recording.formattedDuration,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(recording.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Replay count
                    if (replayCount != null || recording.replayCount != null)
                      Row(
                        children: [
                          Icon(
                            Icons.replay,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${replayCount ?? recording.replayCount} ${AppStrings.replayCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Download button
              _buildDownloadButton(context),
              const SizedBox(width: 8),
              // Play button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: theme.colorScheme.onPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (recording.hasThumbnail) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: recording.thumbnailUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.mic, color: AppColors.textSecondary, size: 32),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildDownloadButton(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        final status = provider.getDownloadStatus(recording.id);

        return GestureDetector(
          onTap: () => _handleDownloadTap(provider, status),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getDownloadIcon(status),
              color: _getDownloadColor(status),
              size: 20,
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
      // Currently downloading - show info
      debugPrint('Download in progress for: ${recording.title}');
    } else {
      // Not downloaded - start download
      provider.downloadRecording(recording, downloadUrl: recording.s3Url);
    }
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
      return AppColors.textSecondary;
    }
  }
}
