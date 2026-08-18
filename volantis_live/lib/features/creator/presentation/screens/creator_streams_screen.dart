import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/creator_stream_model.dart';
import '../providers/creator_provider.dart';

class CreatorStreamsScreen extends StatefulWidget {
  const CreatorStreamsScreen({super.key});

  @override
  State<CreatorStreamsScreen> createState() => _CreatorStreamsScreenState();
}

class _CreatorStreamsScreenState extends State<CreatorStreamsScreen> {
  static const _bg = Color(0xFF0B1326);
  static const _glassCard = Color(0xFF171F33);
  static const _primary = Color(0xFF89CEFF);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _liveRed = Color(0xFFFF6C66);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<CreatorProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Text(
                          'Streams',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (provider.pastStreams.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _glassCard,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${provider.pastStreams.length}',
                              style: const TextStyle(
                                color: _onVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (provider.isStreaming)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildActiveStreamCard(provider),
                    ),
                  ),
                if (provider.pastStreams.isEmpty && !provider.isStreaming)
                  const SliverFillRemaining(
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    sliver: SliverList.separated(
                      itemCount: provider.pastStreams.length,
                      separatorBuilder: (_, _2) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _StreamTile(stream: provider.pastStreams[index]);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveStreamCard(CreatorProvider provider) {
    final stream = provider.currentStream!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2a1020), Color(0xFF1a1030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _liveRed.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _liveRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.circle, color: _liveRed, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                        color: _liveRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.formattedDuration,
                      style: const TextStyle(
                        color: _liveRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stream.title,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            stream.streamType == StreamType.video
                ? Icons.videocam
                : Icons.mic,
            color: _primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  final CreatorStream stream;

  const _StreamTile({required this.stream});

  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);

  @override
  Widget build(BuildContext context) {
    final duration = _computeDuration();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              stream.streamType == StreamType.video
                  ? Icons.videocam
                  : Icons.mic,
              color: _primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream.title,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      stream.isActive ? Icons.circle : Icons.circle_outlined,
                      color: stream.isActive
                          ? const Color(0xFFFF6C66)
                          : _onVariant,
                      size: 8,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stream.isActive ? 'Live' : 'Ended',
                      style: TextStyle(
                        color: stream.isActive
                            ? const Color(0xFFFF6C66)
                            : _onVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$duration${stream.viewerCount > 0 ? ' \u2022 ${stream.viewerCount} viewers' : ''}',
                      style: const TextStyle(
                        color: _onVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (stream.recordingUrl != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: _primary,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  String _computeDuration() {
    if (stream.startTime == null) return _formatDate(stream.createdAt);
    final end = stream.endTime ?? DateTime.now();
    final diff = end.difference(stream.startTime!);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${diff.inSeconds}s';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.podcasts_outlined,
            size: 64,
            color: _onVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No streams yet',
            style: TextStyle(
              color: _onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your past streams will appear here',
            style: TextStyle(color: _onVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
