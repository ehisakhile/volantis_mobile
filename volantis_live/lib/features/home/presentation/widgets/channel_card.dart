import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../auth/data/models/channel_model.dart';

/// Channel card widget for displaying channels in grid
class ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onSubscribe;
  final bool showLiveBadge;
  final bool isPlaying;

  const ChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.onPlay,
    this.onSubscribe,
    this.showLiveBadge = true,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with play button overlay
            Stack(
              children: [
                ChannelArtwork(
                  imageUrl: channel.imageUrl,
                  size: 160,
                  isLive: channel.isLive,
                  showLiveBadge: showLiveBadge,
                ),
                // Play button overlay
                if (onPlay != null)
                  Positioned.fill(
                    child: Center(
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isPlaying 
                                ? AppColors.primary 
                                : AppColors.background.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AppColors.textPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Offline badge
                if (channel.isDownloaded)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.download_done,
                        color: AppColors.textPrimary,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Channel name
            Text(
              channel.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Genre and listeners
            Row(
              children: [
                if (channel.genre != null) ...[
                  Text(
                    channel.genre!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (channel.listenerCount != null)
                    Text(
                      ' • ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
                if (channel.listenerCount != null)
                  Text(
                    '${_formatListeners(channel.listenerCount!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatListeners(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// Channel list item widget for displaying channels in list
class ChannelListItem extends StatelessWidget {
  final Channel channel;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onSubscribe;
  final bool isPlaying;

  const ChannelListItem({
    super.key,
    required this.channel,
    this.onTap,
    this.onPlay,
    this.onSubscribe,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          ChannelArtwork(
            imageUrl: channel.imageUrl,
            size: 60,
            isLive: channel.isLive,
            showLiveBadge: true,
          ),
          if (isPlaying)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.equalizer,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        channel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channel.description != null)
            Text(
              channel.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (channel.genre != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    channel.genre!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              const SizedBox(width: 8),
              if (channel.listenerCount != null)
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatListeners(channel.listenerCount!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPlay != null)
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: AppColors.primary,
                size: 36,
              ),
              onPressed: onPlay,
            ),
          if (onSubscribe != null)
            IconButton(
              icon: Icon(
                channel.isSubscribed
                    ? Icons.check_circle
                    : Icons.add_circle_outline,
                color: channel.isSubscribed
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              onPressed: onSubscribe,
            ),
        ],
      ),
    );
  }

  String _formatListeners(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}