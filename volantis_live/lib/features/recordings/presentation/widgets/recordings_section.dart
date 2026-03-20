import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../providers/recordings_provider.dart';
import 'recording_card.dart';
import 'full_screen_player_sheet.dart';
import 'mini_player.dart';

/// Section widget for displaying recordings list on the channel page
class RecordingsSection extends StatefulWidget {
  final String companySlug;

  const RecordingsSection({super.key, required this.companySlug});

  @override
  State<RecordingsSection> createState() => _RecordingsSectionState();
}

class _RecordingsSectionState extends State<RecordingsSection> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingsProvider>().loadRecordings(widget.companySlug);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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
        // Show loading shimmer for initial load
        if (provider.recordings.isEmpty && provider.isLoadingList) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(),
          );
        }

        // Show empty state if no recordings
        if (provider.recordings.isEmpty && !provider.isLoadingList) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.recordings,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (provider.recordings.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        provider.loadRecordings(
                          widget.companySlug,
                          refresh: true,
                        );
                      },
                      child: const Text('Refresh'),
                    ),
                ],
              ),
            ),
            // Recordings list
            ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount:
                  provider.recordings.length + (provider.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i >= provider.recordings.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
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
            // Mini player at bottom if player is open
            if (provider.isPlayerOpen && !provider.isFullScreen)
              const MiniPlayer(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.noRecordingsAvailable,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
