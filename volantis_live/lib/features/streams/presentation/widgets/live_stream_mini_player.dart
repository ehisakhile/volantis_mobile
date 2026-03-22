import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/streams_provider.dart';
import 'full_screen_player_sheet.dart';

/// Mini player bar shown at the bottom when player is minimized
/// Uses bottom sheet pattern like recordings player for easy expanding/minimizing
class LiveStreamMiniPlayer extends StatelessWidget {
  const LiveStreamMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlayerOpen || provider.currentStream == null) {
          return const SizedBox.shrink();
        }

        final stream = provider.currentStream!;
        final theme = Theme.of(context);

        return GestureDetector(
          onTap: () {
            // Expand player state
            provider.expand();
            // Show full screen player sheet
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const FullScreenPlayerSheet(),
              ),
            );
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Live indicator
                Container(height: 2, color: Colors.red),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: stream.companyLogoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: stream.companyLogoUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _buildPlaceholder(),
                                  errorWidget: (_, __, ___) =>
                                      _buildPlaceholder(),
                                )
                              : _buildPlaceholder(),
                        ),
                        const SizedBox(width: 12),
                        // Title
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      stream.companyName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stream.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // IconButton(
                            //   icon: Icon(
                            //     provider.isMuted
                            //         ? Icons.volume_off
                            //         : Icons.volume_up,
                            //   ),
                            //   iconSize: 20,
                            //   onPressed: () => provider.toggleMute(),
                            // ),
                            // IconButton(
                            //   icon: Icon(
                            //     provider.isPlaying
                            //         ? Icons.pause
                            //         : Icons.play_arrow,
                            //   ),
                            //   iconSize: 28,
                            //   onPressed: () => provider.togglePlayPause(),
                            // ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              iconSize: 20,
                              onPressed: () => provider.closePlayer(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.live_tv,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}
