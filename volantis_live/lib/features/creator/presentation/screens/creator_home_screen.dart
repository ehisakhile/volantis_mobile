import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/creator_stream_model.dart';
import '../providers/creator_provider.dart';
import 'create_stream_screen.dart';

class CreatorHomeScreen extends StatefulWidget {
  const CreatorHomeScreen({super.key});

  @override
  State<CreatorHomeScreen> createState() => _CreatorHomeScreenState();
}

class _CreatorHomeScreenState extends State<CreatorHomeScreen> {
  static const _bg = Color(0xFF0B1326);
  static const _surface = Color(0xFF131B2E);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _secondary = Color(0xFFD2BBFF);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _liveRed = Color(0xFFFF6C66);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CreatorProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<CreatorProvider>(
          builder: (context, provider, _) {
            if (provider.state == CreatorState.loading) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }

            if (provider.isStreaming) {
              return _buildLiveDashboard(provider);
            }

            return _buildCreatorDashboard(provider);
          },
        ),
      ),
    );
  }

  Widget _buildLiveDashboard(CreatorProvider provider) {
    final stream = provider.currentStream!;
    return Column(
      children: [
        _buildLiveHeader(provider),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildLiveStatsCard(provider),
                const SizedBox(height: 16),
                _buildQuickActions(provider),
                const Spacer(),
                _buildStopStreamButton(provider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveHeader(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: Color(0xFF1A2540))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _liveRed,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.currentStream?.title ?? 'Untitled Stream',
              style: const TextStyle(
                color: _onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _glassCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: _primary, size: 16),
                const SizedBox(width: 4),
                Text(
                  provider.formattedDuration,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatsCard(CreatorProvider provider) {
    final stats = provider.streamStats;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _liveRed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Stats',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                Icons.visibility,
                '${stats?.viewerCount ?? 0}',
                'Viewers',
              ),
              const SizedBox(width: 32),
              _buildStatItem(
                Icons.trending_up,
                '${stats?.peakViewers ?? 0}',
                'Peak',
              ),
              const SizedBox(width: 32),
              _buildStatItem(
                Icons.play_circle_outline,
                '${stats?.totalViews ?? 0}',
                'Total Views',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _primary, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _onVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildQuickActions(CreatorProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            onTap: () => _showChatSheet(provider),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.copy,
            label: 'Share',
            onTap: () => _shareStream(provider),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildStopStreamButton(CreatorProvider provider) {
    return GestureDetector(
      onTap: () => _confirmStopStream(provider),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _liveRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'End Stream',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorDashboard(CreatorProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildGoLiveCard(provider),
          const SizedBox(height: 24),
          _buildPastStreamsSection(provider),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Creator Studio',
          style: TextStyle(
            color: _onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _glassCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.notifications_outlined, color: _onVariant),
        ),
      ],
    );
  }

  Widget _buildGoLiveCard(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1f3a), Color(0xFF131B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.broadcast_on_personal,
              color: _primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ready to go live?',
            style: TextStyle(
              color: _onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start streaming to your audience',
            style: TextStyle(color: _onVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StreamTypeButton(
                  icon: Icons.mic,
                  label: 'Audio',
                  onTap: () => _navigateToCreateStream(StreamType.audio),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StreamTypeButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () => _navigateToCreateStream(StreamType.video),
                  disabled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPastStreamsSection(CreatorProvider provider) {
    if (provider.pastStreams.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Streams',
          style: TextStyle(
            color: _onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...provider.pastStreams
            .take(5)
            .map((stream) => _buildPastStreamTile(stream)),
      ],
    );
  }

  Widget _buildPastStreamTile(stream) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(8),
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
                ),
                const SizedBox(height: 4),
                Text(
                  '${stream.viewerCount} viewers • ${_formatDate(stream.createdAt)}',
                  style: const TextStyle(color: _onVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (stream.recordingUrl != null)
            const Icon(Icons.play_circle_outline, color: _primary),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _navigateToCreateStream(StreamType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateStreamScreen(streamType: type),
      ),
    );
  }

  void _showChatSheet(CreatorProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ChatSheet(provider: provider),
    );
  }

  void _shareStream(CreatorProvider provider) {
    final slug = provider.currentStream?.slug;
    if (slug != null) {
      // TODO: Implement share functionality
    }
  }

  void _confirmStopStream(CreatorProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _glassCard,
        title: const Text('End Stream?', style: TextStyle(color: _onSurface)),
        content: const Text(
          'Are you sure you want to end your live stream?',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.stopStream();
            },
            child: const Text('End Stream', style: TextStyle(color: _liveRed)),
          ),
        ],
      ),
    );
  }
}

class _StreamTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  const _StreamTypeButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.withOpacity(0.3)
              : const Color(0xFF89CEFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: disabled ? Colors.grey : const Color(0xFF00344D),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: disabled ? Colors.grey : const Color(0xFF00344D),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF171F33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF89CEFF), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFBEC8D2),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  final CreatorProvider provider;

  const _ChatSheet({required this.provider});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF131B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Live Chat',
              style: TextStyle(
                color: Color(0xFFDAE2FD),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.provider.chatMessages.length,
              itemBuilder: (context, index) {
                final message = widget.provider.chatMessages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF222A3D),
                        child: Text(
                          (message.username ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF89CEFF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.username ?? 'Anonymous',
                              style: const TextStyle(
                                color: Color(0xFF89CEFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              message.content,
                              style: const TextStyle(
                                color: Color(0xFFDAE2FD),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF171F33),
              border: Border(top: BorderSide(color: Color(0xFF1A2540))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Color(0xFFDAE2FD)),
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF222A3D),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_controller.text.isNotEmpty) {
                      widget.provider.sendChatMessage(_controller.text);
                      _controller.clear();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF89CEFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Color(0xFF00344D),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
