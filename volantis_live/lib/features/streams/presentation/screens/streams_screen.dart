import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/streams_provider.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../widgets/full_screen_player_sheet.dart';
import '../widgets/live_stream_mini_player.dart';

/// Streams screen — VolantisLive dark glass design
class StreamsScreen extends StatefulWidget {
  const StreamsScreen({super.key});

  @override
  State<StreamsScreen> createState() => _StreamsScreenState();
}

class _StreamsScreenState extends State<StreamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchFocused = false;

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0B1326);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StreamsProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Ambient glow blobs ─────────────────────────────────────
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD2BBFF).withOpacity(0.04),
              ),
            ),
          ),

          Consumer<StreamsProvider>(
            builder: (context, streamsProvider, _) {
              if (streamsProvider.isLoading) {
                return const LoadingShimmer();
              }

              if (streamsProvider.error != null) {
                return _buildError(streamsProvider.error!);
              }

              final followedStreams = streamsProvider.followedStreams;

              return SafeArea(
                child: RefreshIndicator(
                  color: _primary,
                  backgroundColor: _glassCard,
                  onRefresh: streamsProvider.refresh,
                  child: CustomScrollView(
                    slivers: [
                      // ── App Bar ──────────────────────────────────
                      SliverToBoxAdapter(child: _buildAppBar(streamsProvider)),

                      // ── Search bar ───────────────────────────────
                      SliverToBoxAdapter(
                        child: _buildSearchBar(streamsProvider),
                      ),

                      // ── Following section ─────────────────────────
                      if (followedStreams.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            'Following',
                            followedStreams.length,
                            isFollowing: true,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildFollowedStreamsList(streamsProvider),
                        ),
                      ],

                      // ── Live Now section ──────────────────────────
                      if (streamsProvider.liveStreams.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            AppStrings.liveNow,
                            streamsProvider.liveStreams.length,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildLiveStreamsList(streamsProvider),
                        ),
                      ],

                      // ── Empty state ───────────────────────────────
                      if (streamsProvider.liveStreams.isEmpty &&
                          followedStreams.isEmpty)
                        SliverFillRemaining(child: _buildEmptyState()),

                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 100),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Mini player ───────────────────────────────────────────
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiveStreamMiniPlayer(),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(StreamsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              AppStrings.allStreams,
              style: TextStyle(
                color: Color(0xFFDAE2FD),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: provider.refresh,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.wifi_rounded, color: _primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(StreamsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Focus(
        onFocusChange: (focused) => setState(() => _searchFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _searchFocused
                  ? _primary.withOpacity(0.6)
                  : _outlineVar.withOpacity(0.5),
              width: _searchFocused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                color: _searchFocused ? _primary : _outline,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.searchStreams,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchChannels,
                    hintStyle: TextStyle(
                      color: _outline,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,

                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    isDense: true,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    provider.searchStreams('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.close_rounded, color: _outline, size: 16),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    String title,
    int count, {
    bool isFollowing = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          if (isFollowing) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 14,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isFollowing
                  ? Colors.red.withOpacity(0.15)
                  : _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isFollowing ? Colors.redAccent : _primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Followed streams ──────────────────────────────────────────────────────

  Widget _buildFollowedStreamsList(StreamsProvider provider) {
    final followedStreams = provider.followedStreams;
    if (followedStreams.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: followedStreams.length,
        itemBuilder: (context, index) {
          return _buildLiveStreamCard(followedStreams[index], isFollowed: true);
        },
      ),
    );
  }

  Widget _buildLiveStreamsList(StreamsProvider provider) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.liveStreams.length,
        itemBuilder: (context, index) {
          return _buildLiveStreamCard(provider.liveStreams[index]);
        },
      ),
    );
  }

  // ── Live stream card (horizontal scroll) ──────────────────────────────────

  Widget _buildLiveStreamCard(dynamic stream, {bool isFollowed = false}) {
    return GestureDetector(
      onTap: () => _navigateToPlayer(stream),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: stream.thumbnailUrl != null
                  ? Image.network(
                      stream.thumbnailUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _streamPlaceholder(),
                    )
                  : _streamPlaceholder(),
            ),

            // Full gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.75),
                  ],
                ),
              ),
            ),

            // LIVE badge (top-left)
            Positioned(top: 9, left: 9, child: _buildLivePulseBadge()),

            // Following badge (top-right)
            if (isFollowed)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 8,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Following',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom content
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.companyName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stream.title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _streamPlaceholder() {
    return Container(
      color: _surfaceHigh,
      child: const Center(
        child: Icon(Icons.live_tv_rounded, color: _primary, size: 36),
      ),
    );
  }

  Widget _buildLivePulseBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stream list card (vertical) ───────────────────────────────────────────

  Widget _buildStreamCard(dynamic stream, {bool isFollowed = false}) {
    return GestureDetector(
      onTap: () => _navigateToPlayer(stream),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    color: _surfaceHigh,
                    child: stream.thumbnailUrl != null
                        ? Image.network(
                            stream.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.live_tv_rounded,
                                color: _primary,
                                size: 28,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.live_tv_rounded,
                              color: _primary,
                              size: 28,
                            ),
                          ),
                  ),
                  if (stream.isLive)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: _buildLivePulseBadge(),
                    ),
                ],
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFollowed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 10,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Following',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      stream.title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stream.companyName,
                            style: const TextStyle(
                              color: _onVariant,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.visibility_rounded,
                          size: 11,
                          color: _outline,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${stream.viewerCount}',
                          style: const TextStyle(color: _outline, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Play button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryCont],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: _onPrimary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 32,
              color: _outline,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No streams available',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.pullToRefresh,
            style: const TextStyle(color: _outline, fontSize: 13),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.read<StreamsProvider>().refresh(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryCont],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  color: _onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.read<StreamsProvider>().refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryCont],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: _onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _navigateToPlayer(stream) async {
    final provider = context.read<StreamsProvider>();
    final isSameStream = await provider.openStream(stream);
    if (isSameStream) provider.expand();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider.value(
        value: provider,
        child: const FullScreenPlayerSheet(),
      ),
    );
  }
}

// ── Pulse dot ─────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
