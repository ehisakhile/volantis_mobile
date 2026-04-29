import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/models/recommendations_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/guest_home_models.dart';
import '../providers/home_provider.dart';
import '../providers/guest_home_provider.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../recordings/presentation/providers/recordings_provider.dart';
import '../../../categories/presentation/providers/category_preferences_provider.dart';
import '../../../streams/presentation/providers/streams_provider.dart';
import '../../../streams/presentation/widgets/full_screen_player_sheet.dart';

/// Home screen — VolantisLive dark glass design
class HomeScreen extends StatefulWidget {
  final bool isGuestMode;

  const HomeScreen({super.key, this.isGuestMode = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _searchFocused = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late GuestHomeProvider _guestProvider;

  // ── Design tokens (mirroring the VolantisLive auth system) ───────────────
  static const _bg = Color(0xFF0B1326);
  static const _surface = Color(0xFF131B2E);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _surfaceBright = Color(0xFF2D3449);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _secondary = Color(0xFFD2BBFF);
  static const _tertiary = Color(0xFFFFB3AD);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);
  static const _onPrimary = Color(0xFF00344D);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isGuestMode) {
        _guestProvider = context.read<GuestHomeProvider>();
        if (_guestProvider.companies.isEmpty && !_guestProvider.isLoading) {
          _guestProvider.init();
        }
      } else {
        final provider = context.read<HomeProvider>();
        if (provider.companies.isEmpty && !provider.isLoading) {
          provider.init();
        }
        _checkUserPreferences();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _checkUserPreferences() async {
    final categoryProvider = context.read<CategoryPreferencesProvider>();

    if (categoryProvider.preferencesPromptShown) {
      return;
    }

    await categoryProvider.checkUserPreferences();

    if (!categoryProvider.hasUserPreferences && mounted) {
      categoryProvider.markPreferencesPromptShown();
      context.push('/set-preferences');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HomeProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuestMode) {
      return _buildGuestHome();
    }
    return _buildAuthenticatedHome();
  }

  Widget _buildGuestHome() {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -40,
            right: -60,
            child: _GlowBlob(color: Color(0x0D89CEFF), size: 260),
          ),
          const Positioned(
            bottom: 120,
            left: -80,
            child: _GlowBlob(color: Color(0x08D2BBFF), size: 220),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  Expanded(
                    child: Consumer<GuestHomeProvider>(
                      builder: (context, ghp, _) {
                        if (ghp.isLoading) {
                          return const LoadingShimmer();
                        }
                        if (ghp.error != null) {
                          return _buildError(ghp.error!);
                        }
                        return RefreshIndicator(
                          color: _primary,
                          backgroundColor: _glassCard,
                          onRefresh: ghp.refresh,
                          child: _buildGuestContent(ghp),
                        );
                      },
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

  Widget _buildAuthenticatedHome() {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Ambient glow blobs
          const Positioned(
            top: -40,
            right: -60,
            child: _GlowBlob(color: Color(0x0D89CEFF), size: 260),
          ),
          const Positioned(
            bottom: 120,
            left: -80,
            child: _GlowBlob(color: Color(0x08D2BBFF), size: 220),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Custom header ───────────────────────────────────────
                  _buildHeader(),

                  // ── Search bar ──────────────────────────────────────────
                  _buildSearchBar(),

                  // ── Body ────────────────────────────────────────────────
                  Expanded(
                    child: Consumer<HomeProvider>(
                      builder: (context, hp, _) {
                        if (hp.isLoading) {
                          return const LoadingShimmer();
                        }
                        if (hp.error != null) {
                          return _buildError(hp.error!);
                        }
                        if (hp.isSearching) {
                          return _buildSearchResults(hp);
                        }
                        return RefreshIndicator(
                          color: _primary,
                          backgroundColor: _glassCard,
                          onRefresh: hp.refresh,
                          child: _buildCompaniesList(hp),
                        );
                      },
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

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Logo
          Container(
            height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.hardEdge,
            child: Image.asset(
              'assets/images/volantislive_logo.jpeg',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'VolantisLive',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  letterSpacing: -1.0,
                ),
              ),
            ),
          ),
          const Spacer(),

          // Refresh icon button
          Consumer<HomeProvider>(
            builder: (_, hp, __) =>
                _IconBtn(icon: Icons.refresh_rounded, onTap: hp.refresh),
          ),

          const SizedBox(width: 8),

          // Notification badge placeholder - commented out for now
          // _IconBtn(
          //   icon: Icons.notifications_outlined,
          //   onTap: () {},
          //   badge: true,
          // ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchFocused
                ? _primary.withOpacity(0.8)
                : _outlineVar.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: _searchFocused
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Focus(
          onFocusChange: (f) => setState(() => _searchFocused = f),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: _onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search channels & companies…',
              hintStyle: TextStyle(
                color: _onVariant.withOpacity(0.7),
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _onVariant,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _onVariant,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        context.read<HomeProvider>().clearSearch();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (v) {
              setState(() {});
              Future.delayed(const Duration(milliseconds: 450), () {
                if (_searchController.text == v) {
                  context.read<HomeProvider>().searchCompanies(v);
                }
              });
            },
          ),
        ),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────────────

  Widget _buildSearchResults(HomeProvider hp) {
    if (hp.isSearchingLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
      );
    }

    if (hp.searchResults.isEmpty) {
      return _buildEmptySearch();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: hp.searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildSearchResultTile(hp.searchResults[i], hp),
    );
  }

  Widget _buildSearchResultTile(company, HomeProvider hp) {
    final isFollowed = hp.isCompanyFollowed(company.id);
    return GestureDetector(
      onTap: () => _navigateToCompany(company),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            // Logo
            _CompanyAvatar(company: company, size: 44),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (company.description != null &&
                      company.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      company.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _onVariant, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Follow pill
            _FollowPill(
              isFollowed: isFollowed,
              onTap: () => hp.toggleFollow(company.id),
            ),
          ],
        ),
      ),
    );
  }

  // ── Companies list ────────────────────────────────────────────────────────

  Widget _buildCompaniesList(HomeProvider hp) {
    if (hp.companies.isEmpty) return _buildEmptyState();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // For You - Recommended Companies from user's selected categories
        if (hp.recommendedCompanies.isNotEmpty)
          SliverToBoxAdapter(child: _buildRecommendedCompaniesStrip(hp)),

        // Recommendations - Current Live Streams from subscribed companies
        if (hp.subscribedLivestreams.isNotEmpty)
          SliverToBoxAdapter(child: _buildLivestreamsStrip(hp)),

        // Recordings - Recent recordings from subscribed companies
        if (hp.subscribedRecordings.isNotEmpty)
          SliverToBoxAdapter(child: _buildSubscribedRecordingsStrip(hp)),

        // Creators section - Subscribed + Suggested
        if (_getCreatorsToShow(hp).isNotEmpty)
          SliverToBoxAdapter(child: _buildCreatorsSection(hp)),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Recommendations strip (current livestreams from subscriptions) ───────

  Widget _buildLivestreamsStrip(HomeProvider hp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Recommendations', hp.subscribedLivestreams.length),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: hp.subscribedLivestreams.length,
            itemBuilder: (_, i) =>
                _buildLivestreamCard(hp.subscribedLivestreams[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLivestreamCard(SubscribedLivestream livestream) {
    return GestureDetector(
      onTap: () => _playStream(livestream),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: _surfaceHigh,
                      child: livestream.thumbnailUrl != null
                          ? Image.network(
                              livestream.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.play_circle_outline,
                                color: _primary,
                                size: 40,
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_outline,
                              color: _primary,
                              size: 40,
                            ),
                    ),
                  ),
                  // Live badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6C66),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 5),
                          SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Viewer count
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${livestream.viewerCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
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
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      livestream.title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      livestream.companyName,
                      style: const TextStyle(color: _onVariant, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playStream(SubscribedLivestream livestream) {
    final liveStream = LiveStream(
      id: livestream.id,
      title: livestream.title,
      slug: livestream.slug,
      companyId: livestream.companyId,
      companySlug: livestream.companySlug,
      companyName: livestream.companyName,
      isLive: livestream.isLive,
      viewerCount: livestream.viewerCount,
      thumbnailUrl: livestream.thumbnailUrl,
    );
    _navigateToPlayer(liveStream);
  }

  Future<void> _navigateToPlayer(stream) async {
    final provider = context.read<StreamsProvider>();

    final isSameStream = await provider.openStream(stream);

    if (isSameStream) {
      provider.expand();
    }

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

  // ── Subscribed Recordings strip ────────────────────────────────────────────

  Widget _buildSubscribedRecordingsStrip(HomeProvider hp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Recordings', hp.subscribedRecordings.length),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: hp.subscribedRecordings.length,
            itemBuilder: (_, i) =>
                _buildSubscribedRecordingCard(hp.subscribedRecordings[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSubscribedRecordingCard(SubscribedRecording recording) {
    return GestureDetector(
      onTap: () => _playRecording(recording.id),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: _surfaceHigh,
                      child: recording.thumbnailUrl != null
                          ? Image.network(
                              recording.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.play_circle_outline,
                                color: _primary,
                                size: 36,
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_outline,
                              color: _primary,
                              size: 36,
                            ),
                    ),
                  ),
                  // Duration badge
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        recording.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      recording.companyName,
                      style: const TextStyle(color: _onVariant, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recommended Companies strip ────────────────────────────────────────────

  Widget _buildRecommendedCompaniesStrip(HomeProvider hp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('For You', hp.recommendedCompanies.length),
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: hp.recommendedCompanies.length,
            itemBuilder: (_, i) =>
                _buildRecommendedCompanyChip(hp.recommendedCompanies[i], hp),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRecommendedCompanyChip(
    RecommendedCompany company,
    HomeProvider hp,
  ) {
    final isFollowed = hp.isCompanySubscribed(company.companySlug);
    return GestureDetector(
      onTap: () => context.push('/company/${company.companySlug}'),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _surfaceHigh,
                border: Border.all(
                  color: isFollowed
                      ? _primary.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: company.hasLogo
                    ? Image.network(
                        company.companyLogoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.business_rounded,
                          color: _primary,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.business_rounded,
                        color: _primary,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              company.companyName,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Play a recording
  void _playRecording(int recordingId) {
    final recordingsProvider = context.read<RecordingsProvider>();
    recordingsProvider.openRecording(recordingId);
  }

  /// Get creators to show: subscribed + suggested (from For You recommendations)
  List<dynamic> _getCreatorsToShow(HomeProvider hp) {
    final List<dynamic> creators = [];

    // Add subscribed creators
    for (final company in hp.followedCompanies) {
      creators.add({'type': 'subscribed', 'company': company});
    }

    // Add suggested creators (from For You recommendations that are not subscribed)
    for (final rec in hp.recommendedCompanies) {
      if (!hp.isCompanySubscribed(rec.companySlug)) {
        creators.add({'type': 'suggested', 'company': rec});
      }
    }

    return creators;
  }

  /// Build the Creators section with subscribed + suggested
  Widget _buildCreatorsSection(HomeProvider hp) {
    final creators = _getCreatorsToShow(hp);
    if (creators.isEmpty) return const SizedBox.shrink();

    final subscribedCount = hp.followedCompanies.length;
    final suggestedCount = creators.length - subscribedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subscribed creators
        if (subscribedCount > 0) ...[
          _buildSectionLabel('Your Creators', subscribedCount),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: hp.followedCompanies.length,
              itemBuilder: (_, i) => _buildCreatorChip(
                hp.followedCompanies[i].name,
                hp.followedCompanies[i].hasLogo
                    ? hp.followedCompanies[i].logoUrl
                    : null,
                true,
                () => _navigateToCompany(hp.followedCompanies[i]),
                companySlug: hp.followedCompanies[i].slug,
                hp: hp,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Suggested creators
        if (suggestedCount > 0) ...[
          _buildSectionLabel('Suggested for You', suggestedCount),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: hp.recommendedCompanies.length,
              itemBuilder: (_, i) {
                final rec = hp.recommendedCompanies[i];
                if (hp.isCompanySubscribed(rec.companySlug)) {
                  return const SizedBox.shrink();
                }
                return _buildCreatorChip(
                  rec.companyName,
                  rec.hasLogo ? rec.companyLogoUrl : null,
                  false,
                  () => context.push('/company/${rec.companySlug}'),
                  companySlug: rec.companySlug,
                  hp: hp,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCreatorChip(
    String name,
    String? logoUrl,
    bool isSubscribed,
    VoidCallback onTap, {
    String? companySlug,
    HomeProvider? hp,
  }) {
    final hasActiveLivestream =
        companySlug != null && hp != null && hp.companyHasActiveLivestream(companySlug);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surfaceHigh,
                    border: Border.all(
                      color: isSubscribed
                          ? _primary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: logoUrl != null
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.business_rounded,
                              color: _primary,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.business_rounded,
                            color: _primary,
                            size: 28,
                          ),
                  ),
                ),
                if (hasActiveLivestream)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6C66),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 4),
                          SizedBox(width: 2),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 6,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (hasActiveLivestream)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6C66).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Currently Airing',
                  style: TextStyle(
                    color: Color(0xFFFF6C66),
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                name,
                style: const TextStyle(
                  color: _onVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // ── Company card (grid) ───────────────────────────────────────────────────

  Widget _buildCompanyCard(company, HomeProvider hp) {
    final isFollowed = hp.isCompanyFollowed(company.id);

    return GestureDetector(
      onTap: () => _navigateToCompany(company),
      child: Container(
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFollowed
                ? _primary.withOpacity(0.3)
                : Colors.white.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo area ─────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: _surfaceHigh,
                      child: _CompanyLogoContent(company: company),
                    ),
                  ),
                  // Gradient fade at bottom of logo
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _glassCard.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Follow button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => hp.toggleFollow(company.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isFollowed
                              ? _primary
                              : Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFollowed
                                ? _primary
                                : Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isFollowed ? Icons.check_rounded : Icons.add_rounded,
                          color: isFollowed ? _onPrimary : Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),

                  if (company.isActive == true)
                    Positioned(top: 8, left: 8, child: _LiveBadge()),
                ],
              ),
            ),

            // ── Info area ─────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: const TextStyle(
                        color: _onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (company.description != null &&
                        company.description!.isNotEmpty)
                      Text(
                        company.description!,
                        style: const TextStyle(
                          color: _onVariant,
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestContent(GuestHomeProvider ghp) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (ghp.companies.isNotEmpty)
          SliverToBoxAdapter(child: _buildChannelsStrip(ghp)),
        if (ghp.livestreams.isNotEmpty)
          SliverToBoxAdapter(child: _buildGuestLivestreamsStrip(ghp)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildChannelsStrip(GuestHomeProvider ghp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('All Channels', ghp.companies.length),
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: ghp.companies.length,
            itemBuilder: (_, i) => _buildGuestChannelChip(ghp.companies[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGuestChannelChip(CompanyModel company) {
    return GestureDetector(
      onTap: () => context.push('/company/${company.slug}'),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _surfaceHigh,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: company.hasLogo
                    ? Image.network(
                        company.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.business_rounded,
                          color: _primary,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.business_rounded,
                        color: _primary,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              company.name,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestLivestreamsStrip(GuestHomeProvider ghp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Live Now', ghp.livestreams.length),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: ghp.livestreams.length,
            itemBuilder: (_, i) =>
                _buildGuestLivestreamCard(ghp.livestreams[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGuestLivestreamCard(ActiveLivestream livestream) {
    return GestureDetector(
      onTap: () => context.push('/company/${livestream.companySlug}/stream/${livestream.slug}'),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: _surfaceHigh,
                      child: livestream.thumbnailUrl != null
                          ? Image.network(
                              livestream.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.play_circle_outline,
                                color: _primary,
                                size: 40,
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_outline,
                              color: _primary,
                              size: 40,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6C66),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 5),
                          SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${livestream.viewerCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      livestream.title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      livestream.companyName,
                      style: const TextStyle(color: _onVariant, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty / error states ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_outlined,
              size: 36,
              color: _outline,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No channels yet',
            style: TextStyle(
              color: _onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull down to refresh',
            style: TextStyle(color: _onVariant, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _PrimaryBtn(
            label: AppStrings.tryAgain,
            onTap: () => context.read<HomeProvider>().refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 36,
              color: _outline,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No results found',
            style: TextStyle(
              color: _onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search term',
            style: TextStyle(color: _onVariant.withOpacity(0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    // Check if this is a network connectivity error
    final isOfflineError =
        error.toLowerCase().contains('no internet') ||
        error.toLowerCase().contains('connection') ||
        error.toLowerCase().contains('network');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isOfflineError
                    ? const Color(0xFF0EA5E9).withOpacity(0.15)
                    : const Color(0xFF93000A).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOfflineError
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 36,
                color: isOfflineError
                    ? const Color(0xFF89CEFF)
                    : const Color(0xFFFFB4AB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOfflineError ? 'You are offline' : 'Something went wrong',
              style: const TextStyle(
                color: _onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOfflineError
                  ? 'Your downloaded recordings are still available. Connect to the internet to see latest content.'
                  : error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            if (isOfflineError) ...[
              _PrimaryBtn(
                label: 'My Downloads',
                onTap: () => context.go('/downloads'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<HomeProvider>().refresh(),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: _primary),
                ),
              ),
            ] else ...[
              _PrimaryBtn(
                label: AppStrings.tryAgain,
                onTap: () => context.read<HomeProvider>().refresh(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToCompany(company) => context.push('/company/${company.slug}');
}

// ══════════════════════════════════════════════════════════════════════════════
// LOCAL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── Glow blob ─────────────────────────────────────────────────────────────────

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Icon button with optional dot badge ───────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  const _IconBtn({required this.icon, required this.onTap, this.badge = false});

  static const _bg = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          if (badge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6C66),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Company avatar (circle) ───────────────────────────────────────────────────

class _CompanyAvatar extends StatelessWidget {
  final dynamic company;
  final double size;

  const _CompanyAvatar({required this.company, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF222A3D),
      ),
      clipBehavior: Clip.hardEdge,
      child: _CompanyLogoContent(company: company),
    );
  }
}

// ── Logo content (image or fallback icon) ─────────────────────────────────────

class _CompanyLogoContent extends StatelessWidget {
  final dynamic company;

  const _CompanyLogoContent({required this.company});

  @override
  Widget build(BuildContext context) {
    if (company.hasLogo) {
      return Image.network(
        company.logoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _FallbackIcon(),
      );
    }
    return const _FallbackIcon();
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.business_rounded, size: 28, color: Color(0xFF89CEFF)),
    );
  }
}

// ── Follow pill button ────────────────────────────────────────────────────────

class _FollowPill extends StatelessWidget {
  final bool isFollowed;
  final VoidCallback onTap;

  const _FollowPill({required this.isFollowed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isFollowed
              ? const Color(0xFF89CEFF).withOpacity(0.15)
              : const Color(0xFF89CEFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF89CEFF).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          isFollowed ? 'Following' : 'Follow',
          style: TextStyle(
            color: isFollowed
                ? const Color(0xFF89CEFF)
                : const Color(0xFF00344D),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Live badge ────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6C66),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 5),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary CTA button ────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF89CEFF),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF89CEFF).withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00344D),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
