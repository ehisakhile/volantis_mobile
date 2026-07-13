import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/loading_shimmer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/models/company_model.dart';
import '../../../home/data/models/recommendations_model.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../streams/presentation/providers/streams_provider.dart';
import '../../../streams/presentation/widgets/full_screen_player_sheet.dart';

class LiveTabScreen extends StatefulWidget {
  const LiveTabScreen({super.key});

  @override
  State<LiveTabScreen> createState() => _LiveTabScreenState();
}

class _LiveTabScreenState extends State<LiveTabScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _searchFocused = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const _bg = Color(0xFF07111F);
  static const _surface = Color(0xFF0C1929);
  static const _surfaceLight = Color(0xFF142238);
  static const _glassCard = Color(0xFF0F1D30);
  static const _surfaceHigh = Color(0xFF1A2D45);
  static const _primary = Color(0xFF38BDF8);
  static const _liveRed = Color(0xFFEF4444);
  static const _onSurface = Color(0xFFFFFFFF);
  static const _onSurfaceMedium = Color(0xFFCBD5E1);
  static const _onVariant = Color(0xFF64748B);
  static const _outline = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = context.read<HomeProvider>();
      if (homeProvider.companies.isEmpty && !homeProvider.isLoading) {
        homeProvider.init();
      }

      final streamsProvider = context.read<StreamsProvider>();
      if (streamsProvider.allStreams.isEmpty && !streamsProvider.isLoading) {
        streamsProvider.init();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, homeProvider, _) {
            if (homeProvider.isLoading) {
              return const LoadingShimmer();
            }

            final hasSubscriptions = homeProvider.followedCompanies.isNotEmpty;

            return RefreshIndicator(
              color: _primary,
              backgroundColor: _glassCard,
              onRefresh: () async {
                await homeProvider.refresh();
                if (context.mounted) {
                  await context.read<StreamsProvider>().refresh();
                }
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(homeProvider)),
                  if (homeProvider.isSearching) ...[
                    SliverToBoxAdapter(child: _buildSearchBar(homeProvider)),
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildSearchResults(homeProvider),
                      ),
                    ),
                  ] else if (!hasSubscriptions) ...[
                    SliverToBoxAdapter(child: _buildOnboardingBlock(homeProvider)),
                  ] else ...[
                    SliverToBoxAdapter(child: _buildSearchBar(homeProvider)),
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            _buildPersonalSummary(homeProvider),
                            if (homeProvider
                                .subscribedLivestreams
                                .isNotEmpty)
                              _buildLiveNow(homeProvider),
                            _buildSubscribedCreators(homeProvider),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SliverPadding(padding: EdgeInsets.only(bottom: 112)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(HomeProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Live',
                      style: TextStyle(
                        color: _onSurface,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (provider.subscribedLivestreams.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const _LiveIndicator(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  provider.followedCompanies.isEmpty
                      ? 'Discover creators and subscribe.'
                      : 'Your personalized live content feed.',
                  style: const TextStyle(
                    color: _onVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderIconButton(
            icon: Icons.person_rounded,
            onTap: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.3)),
        ),
        child: Icon(icon, color: _primary, size: 22),
      ),
    );
  }

  Widget _buildSearchBar(HomeProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Focus(
        onFocusChange: (focused) => setState(() => _searchFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocused ? _primary : _outline.withOpacity(0.3),
              width: _searchFocused ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {});
              Future.delayed(const Duration(milliseconds: 350), () {
                if (mounted && _searchController.text == value) {
                  provider.searchCompanies(value);
                }
              });
            },
            style: const TextStyle(color: _onSurfaceMedium, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search any organisation or creator',
              hintStyle: TextStyle(color: _outline.withOpacity(0.9)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _onVariant,
                size: 22,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        provider.clearSearch();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, color: _onVariant),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingBlock(HomeProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find your community',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for an organization or creator to start watching their live streams.',
                style: TextStyle(
                  color: _onVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        _buildSearchBar(provider),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outline.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: _primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nothing to see yet',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to at least one organization to see their live streams and updates in this tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _onVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalSummary(HomeProvider provider) {
    final liveCount = provider.subscribedLivestreams.length;
    final creatorCount = provider.followedCompanies.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            _ModernSummaryMetric(
              label: 'Subscribed',
              value: '$creatorCount',
              icon: Icons.subscriptions_rounded,
              iconColor: _primary,
            ),
            Container(
              width: 1,
              height: 44,
              color: _outline.withOpacity(0.2),
            ),
            _ModernSummaryMetric(
              label: 'Live now',
              value: '$liveCount',
              icon: Icons.podcasts_rounded,
              iconColor: _liveRed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(HomeProvider provider) {
    if (provider.isSearchingLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (provider.searchResults.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: const _EmptyPanel(
          icon: Icons.search_off_rounded,
          title: 'No organisations found',
          body: 'Try a different name or keyword.',
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          children: provider.searchResults
              .map(
                (company) => _CompanySearchTile(
                  company: company,
                  isSubscribed: provider.isCompanySubscribed(company.slug),
                  onOpen: () => context.push('/company/${company.slug}'),
                  onSubscribe: () => _toggleSubscription(provider, company),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildLiveNow(HomeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Live from your creators',
          trailing: '${provider.subscribedLivestreams.length}',
          showLiveBadge: true,
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: provider.subscribedLivestreams.length,
            itemBuilder: (context, index) {
              return _LiveStreamCard(
                livestream: provider.subscribedLivestreams[index],
                onTap: () => _playStream(provider.subscribedLivestreams[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubscribedCreators(HomeProvider provider) {
    if (provider.followedCompanies.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: const _EmptyPanel(
          icon: Icons.explore_rounded,
          title: 'Build your Live feed',
          body:
              'Search for organisations and subscribe. They will appear here whenever you open Live.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Your creators',
            trailing: '${provider.followedCompanies.length}',
            showLiveBadge: false,
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            itemCount: provider.followedCompanies.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final company = provider.followedCompanies[index];
              final livestream = _livestreamForCompany(provider, company.slug);
              return _SubscribedCreatorTile(
                company: company,
                livestream: livestream,
                onOpen: () {
                  if (livestream != null) {
                    _playStream(livestream);
                  } else {
                    context.push('/company/${company.slug}');
                  }
                },
                onUnsubscribe: () => _toggleSubscription(provider, company),
              );
            },
          ),
        ],
      ),
    );
  }

  SubscribedLivestream? _livestreamForCompany(
    HomeProvider provider,
    String companySlug,
  ) {
    for (final livestream in provider.subscribedLivestreams) {
      if (livestream.companySlug == companySlug && livestream.isLive) {
        return livestream;
      }
    }
    return null;
  }

  Future<void> _toggleSubscription(
    HomeProvider provider,
    CompanyModel company,
  ) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      _showAuthRequired();
      return;
    }

    await provider.toggleSubscription(company.slug, companyId: company.id);
    if (!mounted) return;
    await context.read<StreamsProvider>().refreshSubscriptions();
  }

  void _showAuthRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _glassCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign in to subscribe',
          style: TextStyle(color: _onSurface, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Create an account or sign in so your Live feed can stay personalised across devices.',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  void _playStream(SubscribedLivestream livestream) {
    final stream = LiveStream(
      id: livestream.id,
      title: livestream.title,
      slug: livestream.slug,
      companyId: livestream.companyId,
      companySlug: livestream.companySlug,
      companyName: livestream.companyName,
      isLive: livestream.isLive,
      viewerCount: livestream.viewerCount,
      totalViews: livestream.totalViews,
      thumbnailUrl: livestream.thumbnailUrl,
    );
    _navigateToPlayer(stream);
  }

  Future<void> _navigateToPlayer(LiveStream stream) async {
    final provider = context.read<StreamsProvider>();
    final isSameStream = await provider.openStream(stream);
    if (isSameStream) {
      provider.expand();
    }

    if (!mounted) return;

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

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _LiveTabScreenState._liveRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _LiveTabScreenState._liveRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _LiveTabScreenState._liveRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: _LiveTabScreenState._liveRed,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _ModernSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _LiveTabScreenState._onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _LiveTabScreenState._onVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;
  final bool showLiveBadge;

  const _SectionTitle({
    required this.title,
    required this.trailing,
    required this.showLiveBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _LiveTabScreenState._onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (showLiveBadge) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _LiveTabScreenState._liveRed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (!showLiveBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _LiveTabScreenState._primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing,
                style: const TextStyle(
                  color: _LiveTabScreenState._primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompanySearchTile extends StatelessWidget {
  final CompanyModel company;
  final bool isSubscribed;
  final VoidCallback onOpen;
  final VoidCallback onSubscribe;

  const _CompanySearchTile({
    required this.company,
    required this.isSubscribed,
    required this.onOpen,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _LiveTabScreenState._glassCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _LiveTabScreenState._outline.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              _OrgAvatar(name: company.name, logoUrl: company.logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _LiveTabScreenState._onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((company.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        company.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _LiveTabScreenState._onVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ModernSubscribeButton(
                isSubscribed: isSubscribed,
                onTap: onSubscribe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscribedCreatorTile extends StatelessWidget {
  final CompanyModel company;
  final SubscribedLivestream? livestream;
  final VoidCallback onOpen;
  final VoidCallback onUnsubscribe;

  const _SubscribedCreatorTile({
    required this.company,
    required this.livestream,
    required this.onOpen,
    required this.onUnsubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final hasLive = livestream != null;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _LiveTabScreenState._glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLive
                ? _LiveTabScreenState._liveRed.withOpacity(0.3)
                : _LiveTabScreenState._outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            _OrgAvatar(name: company.name, logoUrl: company.logoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          company.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _LiveTabScreenState._onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (hasLive) const _ModernLivePill(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLive
                        ? '${livestream!.title} is live now'
                        : 'No livestream right now',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _LiveTabScreenState._onVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (hasLive) ...[
              const SizedBox(width: 8),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _LiveTabScreenState._primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Join',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              IconButton(
                tooltip: 'Unsubscribe',
                onPressed: onUnsubscribe,
                icon: const Icon(
                  Icons.check_circle_rounded,
                  color: _LiveTabScreenState._primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveStreamCard extends StatefulWidget {
  final SubscribedLivestream livestream;
  final VoidCallback onTap;

  const _LiveStreamCard({required this.livestream, required this.onTap});

  @override
  State<_LiveStreamCard> createState() => _LiveStreamCardState();
}

class _LiveStreamCardState extends State<_LiveStreamCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          color: _LiveTabScreenState._glassCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _LiveTabScreenState._outline.withOpacity(0.2)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.livestream.thumbnailUrl == null
                  ? Container(
                      color: _LiveTabScreenState._surfaceHigh,
                      child: const Icon(
                        Icons.podcasts_rounded,
                        color: _LiveTabScreenState._primary,
                        size: 44,
                      ),
                    )
                  : Image.network(
                      widget.livestream.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: _LiveTabScreenState._surfaceHigh,
                        child: const Icon(
                          Icons.podcasts_rounded,
                          color: _LiveTabScreenState._primary,
                          size: 44,
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ),
            const Positioned(top: 10, left: 10, child: _ModernLivePill()),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.livestream.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.livestream.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      color: Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.livestream.viewerCount ?? 0}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
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
    );
  }
}

class _ModernSubscribeButton extends StatefulWidget {
  final bool isSubscribed;
  final VoidCallback onTap;

  const _ModernSubscribeButton({
    required this.isSubscribed,
    required this.onTap,
  });

  @override
  State<_ModernSubscribeButton> createState() => _ModernSubscribeButtonState();
}

class _ModernSubscribeButtonState extends State<_ModernSubscribeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          color: widget.isSubscribed
              ? _LiveTabScreenState._primary.withOpacity(0.12)
              : _LiveTabScreenState._primary,
          borderRadius: BorderRadius.circular(999),
          border: widget.isSubscribed
              ? Border.all(color: _LiveTabScreenState._primary.withOpacity(0.5))
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          widget.isSubscribed ? 'Subscribed' : 'Subscribe',
          style: TextStyle(
            color: widget.isSubscribed
                ? _LiveTabScreenState._primary
                : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;

  const _OrgAvatar({required this.name, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _LiveTabScreenState._surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: logoUrl == null || logoUrl!.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: _LiveTabScreenState._primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.business_rounded,
                color: _LiveTabScreenState._primary,
              ),
            ),
    );
  }
}

class _ModernLivePill extends StatelessWidget {
  const _ModernLivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _LiveTabScreenState._liveRed,
        borderRadius: BorderRadius.circular(999),
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
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 20),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _LiveTabScreenState._surfaceHigh,
                  _LiveTabScreenState._surfaceLight,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: _LiveTabScreenState._primary, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _LiveTabScreenState._onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _LiveTabScreenState._onVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
