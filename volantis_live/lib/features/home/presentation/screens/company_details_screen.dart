import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:volantis_live/features/streams/presentation/providers/streams_provider.dart';
import 'package:volantis_live/features/streams/presentation/widgets/full_screen_player_sheet.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../services/api_service.dart';
import '../../../../services/subscriptions_service.dart';
import '../../../recordings/presentation/widgets/recordings_section.dart';
import '../../../recordings/presentation/widgets/mini_player.dart';
import '../../../recordings/presentation/providers/recordings_provider.dart';
import '../../../streams/data/models/company_live_stream_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/subscription_model.dart';
import '../providers/home_provider.dart';

/// Company details screen — VolantisLive dark glass design
class CompanyDetailsScreen extends StatefulWidget {
  final String companySlug;

  const CompanyDetailsScreen({super.key, required this.companySlug});

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  CompanyModel? _company;
  bool _isLoading = true;
  bool _isLoadingStreams = true;
  String? _error;

  List<CompanyStream> _allStreams = [];
  List<CompanyStream> _activeStreams = [];
  List<CompanyStream> _inactiveStreams = [];

  static const int _streamsPageSize = 3;
  int _currentStreamsPage = 0;
  bool _isLoadingMoreStreams = false;

  CompanyStatsModel? _companyStats;
  bool _isLoadingStats = true;

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
    _loadCompanyDetails();
  }

  Future<void> _loadCompanyDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final homeProvider = context.read<HomeProvider>();
      final company = homeProvider.companies.firstWhere(
        (c) => c.slug == widget.companySlug,
        orElse: () => throw Exception('Company not found'),
      );

      setState(() {
        _company = company;
        _isLoading = false;
      });

      await Future.wait([_loadCompanyStreams(), _loadCompanyStats()]);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompanyStreams() async {
    setState(() => _isLoadingStreams = true);

    try {
      final apiService = ApiService.instance;
      final response = await apiService.get(
        ApiConstants.getCompanyStreamsEndpoint(
          widget.companySlug,
          includeInactive: true,
        ),
      );

      if (response.data is List) {
        final streams = (response.data as List)
            .map((json) => CompanyStream.fromJson(json as Map<String, dynamic>))
            .toList();

        final active = streams.where((s) => s.isActive).toList();
        final inactive = streams.where((s) => !s.isActive).toList();
        inactive.sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );

        setState(() {
          _allStreams = streams;
          _activeStreams = active;
          _inactiveStreams = inactive;
          _currentStreamsPage = 0;
          _isLoadingStreams = false;
        });
      }
    } on DioException catch (e) {
      print('API: Error loading company streams - ${e.message}');
      setState(() => _isLoadingStreams = false);
    }
  }

  Future<void> _loadCompanyStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final subscriptionsService = SubscriptionsService.instance;
      final stats = await subscriptionsService.getCompanyStats(
        widget.companySlug,
      );
      setState(() {
        _companyStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading company stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _bg, body: LoadingShimmer());
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(child: _buildErrorState()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Ambient glow ─────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withOpacity(0.05),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              // ── Collapsing hero header ─────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: _bg,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _onSurface,
                      size: 16,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(),
                  collapseMode: CollapseMode.parallax,
                ),
              ),

              // ── Company info ─────────────────────────────────
              SliverToBoxAdapter(child: _buildCompanyInfo()),

              // ── Stats ─────────────────────────────────────────
              if (!_isLoadingStats && _companyStats != null)
                SliverToBoxAdapter(child: _buildStatsSection()),

              // ── Live Now header ──────────────────────────────
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  _activeStreams.isNotEmpty ? 'Live Now' : 'No Live Streams',
                  count: _activeStreams.length,
                ),
              ),

              // ── Live streams content ──────────────────────────
              SliverToBoxAdapter(child: _buildContent()),

              // ── Previous streams ──────────────────────────────
              if (_inactiveStreams.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    'Previous Streams',
                    count: _inactiveStreams.length,
                  ),
                ),
                SliverToBoxAdapter(child: _buildPreviousStreamsSection()),
              ],

              // ── Recordings section ────────────────────────────
              SliverToBoxAdapter(
                child: RecordingsSection(companySlug: widget.companySlug),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),

          // ── Mini player ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Consumer<RecordingsProvider>(
              builder: (context, recordingsProvider, _) {
                if (!recordingsProvider.isPlayerOpen ||
                    recordingsProvider.isFullScreen) {
                  return const SizedBox.shrink();
                }
                return const MiniPlayer();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header (hero banner) ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D2137), Color(0xFF0B1326)],
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          bottom: -20,
          left: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD2BBFF).withOpacity(0.05),
            ),
          ),
        ),

        // Bottom gradient fade into bg
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _bg],
              ),
            ),
          ),
        ),

        // Logo
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surfaceHigh,
                  border: Border.all(
                    color: _primary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _company!.hasLogo
                      ? Image.network(
                          _company!.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.business_rounded,
                            size: 36,
                            color: _primary,
                          ),
                        )
                      : const Icon(
                          Icons.business_rounded,
                          size: 36,
                          color: _primary,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Company info ──────────────────────────────────────────────────────────

  Widget _buildCompanyInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _company!.name,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Consumer<HomeProvider>(
                builder: (context, homeProvider, _) {
                  final isFollowed = homeProvider.isCompanyFollowed(
                    _company!.id,
                  );
                  return _FollowButton(
                    isFollowed: isFollowed,
                    onTap: () => homeProvider.toggleFollow(_company!.id),
                  );
                },
              ),
            ],
          ),

          // Description
          if (_company!.description != null &&
              _company!.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _company!.description!,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {int count = 0}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Stats section ─────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    if (_companyStats == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                color: _onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.play_circle_outline_rounded,
                  value: '${_companyStats!.totalStreams}',
                  label: 'Streams',
                ),
                _buildDivider(),
                _buildStatItem(
                  icon: Icons.people_alt_rounded,
                  value: '${_companyStats!.subscriberCount}',
                  label: 'Followers',
                ),
                // _buildDivider(),
                // _buildStatItem(
                //   icon: Icons.schedule_rounded,
                //   value: _companyStats!.formattedStreamedTime,
                //   label: 'Total Time',
                // ),
              ],
            ),
            if (_companyStats!.isLive) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    _PulseDot(color: Colors.red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Currently Live',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${_companyStats!.currentViewers} watching',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 36, color: _outlineVar);
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: _outline,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Active streams ────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_isLoadingStreams) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
        ),
      );
    }

    if (_activeStreams.isNotEmpty) {
      return Column(
        children: _activeStreams
            .map((stream) => _buildStreamCard(stream))
            .toList(),
      );
    }

    if (_inactiveStreams.isNotEmpty) {
      return const SizedBox.shrink();
    }

    // No streams at all
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 26,
                color: _outline,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No streams available',
              style: TextStyle(
                color: _onVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stream card ───────────────────────────────────────────────────────────

  Widget _buildStreamCard(CompanyStream stream) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () => _playStream(stream),
        child: Container(
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
                    if (stream.isActive)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulseDot(color: Colors.white, size: 5),
                              SizedBox(width: 3),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      Text(
                        stream.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (stream.isActive)
                        Row(
                          children: [
                            const Icon(
                              Icons.visibility_rounded,
                              size: 11,
                              color: _outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${stream.viewerCount} watching',
                              style: const TextStyle(
                                color: _outline,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          stream.formattedDate,
                          style: const TextStyle(
                            color: _onVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stream.formattedDuration,
                          style: const TextStyle(color: _outline, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Play button
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: stream.isActive
                        ? const LinearGradient(
                            colors: [_primary, _primaryCont],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: stream.isActive ? null : _surfaceHigh,
                    shape: BoxShape.circle,
                    boxShadow: stream.isActive
                        ? [
                            BoxShadow(
                              color: _primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: stream.isActive ? _onPrimary : _onVariant,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pagination helpers ────────────────────────────────────────────────────

  List<CompanyStream> get _paginatedStreams {
    final startIndex = _currentStreamsPage * _streamsPageSize;
    final endIndex = startIndex + _streamsPageSize;
    if (startIndex >= _inactiveStreams.length) return [];
    return _inactiveStreams.sublist(
      0,
      endIndex > _inactiveStreams.length ? _inactiveStreams.length : endIndex,
    );
  }

  bool get _hasMoreStreams {
    final loadedCount = (_currentStreamsPage + 1) * _streamsPageSize;
    return loadedCount < _inactiveStreams.length;
  }

  void _loadMoreStreams() {
    if (_isLoadingMoreStreams || !_hasMoreStreams) return;

    setState(() {
      _isLoadingMoreStreams = true;
      _currentStreamsPage++;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isLoadingMoreStreams = false);
    });
  }

  Widget _buildPreviousStreamsSection() {
    if (_isLoadingStreams) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
        ),
      );
    }

    if (_inactiveStreams.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ..._paginatedStreams.map((stream) => _buildStreamCard(stream)),
        if (_hasMoreStreams) ...[
          const SizedBox(height: 12),
          _isLoadingMoreStreams
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: _loadMoreStreams,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _glassCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _outlineVar.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.expand_more_rounded,
                            color: _primary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Load More (${_inactiveStreams.length - (_currentStreamsPage + 1) * _streamsPageSize} more)',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState() {
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
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surfaceHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _outlineVar),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    color: _onSurface,
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

  void _playStream(CompanyStream stream) {
    final liveStream = LiveStream(
      id: stream.id,
      title: stream.title,
      slug: stream.slug,
      companyId: _company!.id,
      companySlug: _company!.slug,
      companyName: _company!.name,
      companyLogoUrl: _company!.logoUrl,
      isLive: stream.isActive,
      viewerCount: stream.viewerCount,
      thumbnailUrl: stream.thumbnailUrl,
      startedAt: stream.createdAt,
    );
    _navigateToPlayer(liveStream);
  }

  /// Navigate to stream player screen - handles single stream logic
  Future<void> _navigateToPlayer(stream) async {
    final provider = context.read<StreamsProvider>();

    // Open stream - returns true if same stream (continue listening), false if new
    final isSameStream = await provider.openStream(stream);

    if (isSameStream) {
      // Same stream - just expand the player
      provider.expand();
    }

    if (!context.mounted) return;

    // Use bottom sheet instead of full screen navigation (like recordings player)
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

// ── Follow button ─────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final bool isFollowed;
  final VoidCallback onTap;

  const _FollowButton({required this.isFollowed, required this.onTap});

  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _outlineVar = Color(0xFF3E4850);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: isFollowed
              ? const LinearGradient(
                  colors: [_primary, _primaryCont],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isFollowed ? null : _surfaceHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isFollowed ? Colors.transparent : _outlineVar,
            width: 1,
          ),
          boxShadow: isFollowed
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowed ? Icons.check_rounded : Icons.add_rounded,
              color: isFollowed ? _onPrimary : const Color(0xFFBEC8D2),
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              isFollowed ? AppStrings.followed : AppStrings.follow,
              style: TextStyle(
                color: isFollowed ? _onPrimary : const Color(0xFFBEC8D2),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulse dot ─────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseDot({this.color = Colors.white, this.size = 6});

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
      begin: 0.3,
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
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
