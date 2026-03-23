import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/recording_download.dart';
import '../providers/recordings_provider.dart';
import '../../../../core/constants/app_colors.dart';

/// Download button — VolantisLive dark glass design
class DownloadButton extends StatelessWidget {
  final int recordingId;
  final String? s3Url;
  final VoidCallback? onDownloadComplete;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  const DownloadButton({
    super.key,
    required this.recordingId,
    this.s3Url,
    this.onDownloadComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (_, provider, __) {
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
        return _IconTile(
          icon: Icons.download_rounded,
          color: _outline,
          onTap: () => _startDownload(provider),
          tooltip: 'Download',
        );

      case DownloadStatus.queued:
        return _CircleTile(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: const AlwaysStoppedAnimation(_primary),
            ),
          ),
        );

      case DownloadStatus.downloading:
        return _CircleTile(
          child: SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  backgroundColor: _outlineVar,
                  valueColor: const AlwaysStoppedAnimation(_primary),
                ),
                Text(
                  '${(progress * 100).toInt()}',
                  style: const TextStyle(
                    fontSize: 7,
                    color: _primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          onTap: () => provider.cancelDownload(recordingId),
        );

      case DownloadStatus.paused:
        return _IconTile(
          icon: Icons.pause_circle_outline_rounded,
          color: _primary,
          onTap: () => provider.cancelDownload(recordingId),
          tooltip: 'Paused — tap to cancel',
        );

      case DownloadStatus.downloaded:
        return _IconTile(
          icon: Icons.download_done_rounded,
          color: _primary,
          onTap: () {},
          tooltip: 'Downloaded',
        );
    }
  }

  void _startDownload(RecordingsProvider provider) {
    debugPrint('Download requested for recording: $recordingId');
  }
}

// ── Shared tile shells ────────────────────────────────────────────────────────

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color == const Color(0xFF89CEFF)
                ? color.withOpacity(0.3)
                : const Color(0xFF3E4850).withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _CircleTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _CircleTile({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DOWNLOAD PROGRESS INDICATOR (inline, for expanded views)
// ══════════════════════════════════════════════════════════════════════════════

/// Inline progress bar shown in expanded recording views.
class DownloadProgressIndicator extends StatelessWidget {
  final int recordingId;
  final double progress;
  final DownloadStatus status;
  final VoidCallback? onCancel;

  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _outlineVar = Color(0xFF3E4850);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);

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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Label
              Expanded(
                child: Text(
                  status == DownloadStatus.queued
                      ? 'Waiting to download…'
                      : 'Downloading… ${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: _onVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onCancel != null)
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(
                    Icons.close_rounded,
                    color: _outline,
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: _outlineVar,
              valueColor: const AlwaysStoppedAnimation(_primary),
            ),
          ),
        ],
      ),
    );
  }
}
