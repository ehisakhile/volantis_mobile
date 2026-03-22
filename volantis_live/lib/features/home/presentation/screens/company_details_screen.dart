import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
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

/// Screen showing company details with their live streams
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

  // Stream data
  List<CompanyStream> _allStreams = [];
  List<CompanyStream> _activeStreams = [];
  List<CompanyStream> _inactiveStreams = [];

  // Pagination for previous streams
  static const int _streamsPageSize = 3;
  int _currentStreamsPage = 0;
  bool _isLoadingMoreStreams = false;

  // Stats data
  CompanyStatsModel? _companyStats;
  bool _isLoadingStats = true;

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
      // Find company from the home provider
      final homeProvider = context.read<HomeProvider>();
      final company = homeProvider.companies.firstWhere(
        (c) => c.slug == widget.companySlug,
        orElse: () => throw Exception('Company not found'),
      );

      setState(() {
        _company = company;
        _isLoading = false;
      });

      // Load streams and stats in parallel
      await Future.wait([_loadCompanyStreams(), _loadCompanyStats()]);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompanyStreams() async {
    setState(() {
      _isLoadingStreams = true;
    });

    try {
      final apiService = ApiService.instance;

      // Fetch all streams (including inactive)
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

        // Separate active and inactive streams
        final active = streams.where((s) => s.isActive).toList();
        final inactive = streams.where((s) => !s.isActive).toList();

        // Sort inactive streams by creation date (newest first)
        inactive.sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );

        setState(() {
          _allStreams = streams; // Keep for potential future use
          _activeStreams = active;
          _inactiveStreams = inactive;
          _currentStreamsPage = 0; // Reset pagination
          _isLoadingStreams = false;
        });
      }
    } on DioException catch (e) {
      print('API: Error loading company streams - ${e.message}');
      setState(() {
        _isLoadingStreams = false;
      });
    }
  }

  Future<void> _loadCompanyStats() async {
    setState(() {
      _isLoadingStats = true;
    });

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
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingShimmer());
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // App Bar with company banner
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
              ),

              // Company Info
              SliverToBoxAdapter(child: _buildCompanyInfo()),

              // Stats Section
              if (!_isLoadingStats)
                SliverToBoxAdapter(child: _buildStatsSection()),

              // Live Now Section
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  _activeStreams.isNotEmpty ? 'Live Now' : 'No Live Streams',
                  count: _activeStreams.length,
                ),
              ),

              // Streams content
              SliverToBoxAdapter(child: _buildContent()),

              // Previous Streams Section (with pagination - 3 at a time)
              if (_inactiveStreams.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    'Previous Streams',
                    count: _inactiveStreams.length,
                  ),
                ),
                SliverToBoxAdapter(child: _buildPreviousStreamsSection()),
              ],

              // Recordings Section
              SliverToBoxAdapter(
                child: RecordingsSection(companySlug: widget.companySlug),
              ),
            ],
          ),
          // Mini Player - Fixed at bottom, outside scroll view
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Consumer<RecordingsProvider>(
              builder: (context, recordingsProvider, _) {
                // Only show mini player when a recording is open and not in fullscreen mode
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

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Company Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _company!.hasLogo
                    ? Image.network(
                        _company!.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.business,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.business,
                        size: 40,
                        color: AppColors.primary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Name
          Text(
            _company!.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Follow Button
          Consumer<HomeProvider>(
            builder: (context, homeProvider, _) {
              final isFollowed = homeProvider.isCompanyFollowed(_company!.id);
              return ElevatedButton.icon(
                onPressed: () => homeProvider.toggleFollow(_company!.id),
                icon: Icon(isFollowed ? Icons.check : Icons.add),
                label: Text(
                  isFollowed ? AppStrings.followed : AppStrings.follow,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowed
                      ? AppColors.primary
                      : Colors.white,
                  foregroundColor: isFollowed
                      ? Colors.white
                      : AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Description
          if (_company!.description != null &&
              _company!.description!.isNotEmpty)
            Text(
              _company!.description!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {int count = 0}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_companyStats == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.play_circle_outline,
                  value: '${_companyStats!.totalStreams}',
                  label: 'Streams',
                ),
                _buildStatItem(
                  icon: Icons.visibility,
                  value: '${_companyStats!.subscriberCount}',
                  label: 'Followers',
                ),
                _buildStatItem(
                  icon: Icons.schedule,
                  value: _companyStats!.formattedStreamedTime,
                  label: 'Total Time',
                ),
              ],
            ),
            if (_companyStats!.isLive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Currently Live',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${_companyStats!.currentViewers} watching',
                      style: const TextStyle(color: Colors.red),
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

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoadingStreams) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Show active streams
    if (_activeStreams.isNotEmpty) {
      return Column(
        children: _activeStreams
            .map((stream) => _buildStreamCard(stream))
            .toList(),
      );
    }

    // If no active streams, check if there are inactive streams
    // If there are inactive streams, don't show the empty state
    if (_inactiveStreams.isNotEmpty) {
      return const SizedBox.shrink(); // Previous streams section will be shown below
    }

    // No streams at all
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.wifi_off,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No streams available',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamCard(CompanyStream stream) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: stream.thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      stream.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.play_circle_outline,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.primary,
                  ),
          ),
          title: Text(
            stream.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (stream.isActive)
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.visibility,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stream.viewerCount}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  stream.formattedDate,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Duration: ${stream.formattedDuration}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          trailing: stream.isActive
              ? IconButton(
                  icon: const Icon(
                    Icons.play_circle_fill,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    // Play the live stream
                    _playStream(stream);
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () {
                    // Play the recording
                    _playStream(stream);
                  },
                ),
        ),
      ),
    );
  }

  /// Get paginated streams (3 at a time)
  List<CompanyStream> get _paginatedStreams {
    final startIndex = _currentStreamsPage * _streamsPageSize;
    final endIndex = startIndex + _streamsPageSize;
    if (startIndex >= _inactiveStreams.length) {
      return [];
    }
    return _inactiveStreams.sublist(
      startIndex,
      endIndex > _inactiveStreams.length ? _inactiveStreams.length : endIndex,
    );
  }

  /// Check if there are more streams to load
  bool get _hasMoreStreams {
    final loadedCount = (_currentStreamsPage + 1) * _streamsPageSize;
    return loadedCount < _inactiveStreams.length;
  }

  /// Load more streams (pagination)
  void _loadMoreStreams() {
    if (_isLoadingMoreStreams || !_hasMoreStreams) return;

    setState(() {
      _isLoadingMoreStreams = true;
      _currentStreamsPage++;
    });

    // Simulate a small delay for UX (or remove if not needed)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoadingMoreStreams = false;
        });
      }
    });
  }

  Widget _buildPreviousStreamsSection() {
    if (_isLoadingStreams) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_inactiveStreams.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Show 3 streams at a time with pagination
          ..._paginatedStreams.map((stream) => _buildStreamCard(stream)),

          // Load More button
          if (_hasMoreStreams) ...[
            const SizedBox(height: 16),
            _isLoadingMoreStreams
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _loadMoreStreams,
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      'Load More (${_inactiveStreams.length - _paginatedStreams.length} more)',
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  void _playStream(CompanyStream stream) {
    // Navigate to stream player or show bottom sheet
    // For now, we'll use the existing recordings player flow
    // This would need to be connected to the actual stream player
    print('Play stream: ${stream.title} - ${stream.slug}');
  }
}
