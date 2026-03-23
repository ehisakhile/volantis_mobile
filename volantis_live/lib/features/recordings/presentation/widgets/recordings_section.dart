import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../providers/recordings_provider.dart';
import 'recording_card.dart';
import 'full_screen_player_sheet.dart';

/// Recordings section — VolantisLive dark glass design
class RecordingsSection extends StatefulWidget {
  final String companySlug;

  const RecordingsSection({super.key, required this.companySlug});

  @override
  State<RecordingsSection> createState() => _RecordingsSectionState();
}

class _RecordingsSectionState extends State<RecordingsSection> {
  final _scrollController = ScrollController();

  // ── Design tokens ────────────────────────────────────────────────────────
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecordingsProvider>().loadRecordings(widget.companySlug);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!mounted) return;
      context.read<RecordingsProvider>().loadRecordings(widget.companySlug);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openPlayer(BuildContext context, int recordingId) {
    final provider = context.read<RecordingsProvider>();
    provider.openRecording(recordingId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const FullScreenPlayerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        if (provider.recordings.isEmpty && provider.isLoadingList) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(),
          );
        }

        if (provider.recordings.isEmpty && !provider.isLoadingList) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(provider),
            ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount:
                  provider.recordings.length + (provider.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i >= provider.recordings.length) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }
                final recording = provider.recordings[i];
                return RecordingCard(
                  recording: recording,
                  replayCount: recording.replayCount,
                  onTap: () => _openPlayer(context, recording.id),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(RecordingsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        children: [
          const Text(
            AppStrings.recordings,
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${provider.recordings.length}',
              style: const TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          // Refresh pill
          GestureDetector(
            onTap: () =>
                provider.loadRecordings(widget.companySlug, refresh: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh_rounded, color: _outline, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      color: _onVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.library_music_outlined,
                size: 32,
                color: _outline,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.noRecordingsAvailable,
              style: TextStyle(
                color: _onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Check back later for recorded streams',
              style: TextStyle(color: _onVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
