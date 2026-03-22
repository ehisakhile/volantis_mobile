import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/recording_download.dart';
import '../providers/recordings_provider.dart';
import '../../../../core/constants/app_colors.dart';

/// Download button widget for recording cards
/// Shows download state and handles download actions
class DownloadButton extends StatelessWidget {
  final int recordingId;
  final String? s3Url;
  final VoidCallback? onDownloadComplete;

  const DownloadButton({
    super.key,
    required this.recordingId,
    this.s3Url,
    this.onDownloadComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        final status = provider.getDownloadStatus(recordingId);
        final progress = provider.getDownloadProgress(recordingId);

        return _buildButton(context, status, progress, provider);
      },
    );
  }

  Widget _buildButton(
    BuildContext context,
    DownloadStatus status,
    double progress,
    RecordingsProvider provider,
  ) {
    switch (status) {
      case DownloadStatus.notDownloaded:
      case DownloadStatus.failed:
      case DownloadStatus.expired:
        return IconButton(
          icon: const Icon(Icons.download_outlined),
          color: AppColors.textSecondary,
          onPressed: () => _startDownload(provider),
          tooltip: 'Download',
        );

      case DownloadStatus.queued:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        );

      case DownloadStatus.downloading:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 8, color: AppColors.primary),
                ),
              ],
            ),
          ),
        );

      case DownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_arrow),
          color: AppColors.primary,
          onPressed: () {
            // Resume would require the original download parameters
            // For now, show cancel option instead
            provider.cancelDownload(recordingId);
          },
          tooltip: 'Resume Download',
        );

      case DownloadStatus.downloaded:
        return IconButton(
          icon: const Icon(Icons.download_done),
          color: AppColors.primary,
          tooltip: 'Downloaded',
          onPressed: () {
            // Could show options like delete, play, etc.
          },
        );
    }
  }

  void _startDownload(RecordingsProvider provider) {
    // This would be called from the parent with proper recording data
    // The parent should pass the full Recording object
    debugPrint('Download requested for recording: $recordingId');
  }
}

/// Download progress indicator for expanded views
class DownloadProgressIndicator extends StatelessWidget {
  final int recordingId;
  final double progress;
  final DownloadStatus status;
  final VoidCallback? onCancel;

  const DownloadProgressIndicator({
    super.key,
    required this.recordingId,
    required this.progress,
    required this.status,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (status != DownloadStatus.downloading &&
        status != DownloadStatus.queued) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status == DownloadStatus.queued
                      ? 'Waiting to download...'
                      : 'Downloading... ${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCancel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ],
      ),
    );
  }
}
