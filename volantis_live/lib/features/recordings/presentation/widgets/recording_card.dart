import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/models/recording_model.dart';
import '../../data/models/recording_download.dart';
import '../providers/recordings_provider.dart';
import 'package:intl/intl.dart';

/// Recording card — VolantisLive dark glass design
class RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback onTap;
  final int? replayCount;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  const RecordingCard({
    super.key,
    required this.recording,
    required this.onTap,
    this.replayCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            _buildThumbnail(),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recording.title,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Duration + date row
                  Row(
                    children: [
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: recording.formattedDuration,
                      ),
                      const SizedBox(width: 10),
                      _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: _formatDate(recording.createdAt),
                      ),
                    ],
                  ),

                  // Replay count
                  if (replayCount != null || recording.replayCount != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.replay_rounded,
                          size: 12,
                          color: _primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${replayCount ?? recording.replayCount} ${AppStrings.replayCount}',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Download + play
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDownloadButton(context),
                const SizedBox(height: 8),
                _PlayBtn(onTap: onTap),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: recording.hasThumbnail
          ? CachedNetworkImage(
              imageUrl: recording.thumbnailUrl!,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.mic_rounded, color: _primary, size: 28),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  Widget _buildDownloadButton(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (_, provider, __) {
        final status = provider.getDownloadStatus(recording.id);
        final isDownloaded = status == DownloadStatus.downloaded;
        final isInProgress =
            status == DownloadStatus.downloading ||
            status == DownloadStatus.queued;

        return GestureDetector(
          onTap: () => _handleDownloadTap(provider, status),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (isDownloaded || isInProgress)
                    ? _primary.withOpacity(0.3)
                    : _outlineVar.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              _getDownloadIcon(status),
              color: (isDownloaded || isInProgress) ? _primary : _outline,
              size: 17,
            ),
          ),
        );
      },
    );
  }

  void _handleDownloadTap(RecordingsProvider provider, dynamic status) {
    final s = status.toString();
    if (s.contains('downloaded')) {
      provider.playDownloadedRecording(recording.id);
    } else if (!s.contains('downloading') && !s.contains('queued')) {
      provider.downloadRecording(recording, downloadUrl: recording.s3Url);
    }
  }

  IconData _getDownloadIcon(dynamic status) {
    final s = status.toString();
    if (s.contains('downloaded')) return Icons.download_done_rounded;
    if (s.contains('downloading')) return Icons.downloading_rounded;
    if (s.contains('queued')) return Icons.hourglass_empty_rounded;
    return Icons.download_rounded;
  }
}

// ── Play button ───────────────────────────────────────────────────────────────

class _PlayBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF89CEFF), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF89CEFF).withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Color(0xFF00344D),
          size: 20,
        ),
      ),
    );
  }
}

// ── Meta chip (icon + label) ──────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF88929B)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBEC8D2),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
