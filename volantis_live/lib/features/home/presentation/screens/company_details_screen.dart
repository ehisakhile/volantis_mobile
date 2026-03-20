import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:volantis_live/features/recordings/presentation/widgets/recordings_section.dart';
import 'package:volantis_live/features/recordings/presentation/widgets/mini_player.dart';
import 'package:volantis_live/features/recordings/presentation/providers/recordings_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/models/company_model.dart';
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
  String? _error;

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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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

              // Live Now Section
              SliverToBoxAdapter(
                child: _buildSectionHeader(AppStrings.liveNow),
              ),

              // Streams content
              SliverToBoxAdapter(child: _buildContent()),
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
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
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
                    color: Colors.black.withOpacity(0.2),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Streams Section (placeholder for now)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.wifi,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No live streams available',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Recordings Section
        RecordingsSection(companySlug: widget.companySlug),
      ],
    );
  }
}
