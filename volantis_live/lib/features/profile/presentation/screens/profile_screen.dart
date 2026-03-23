import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../../services/analytics_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../providers/profile_provider.dart';

/// Profile screen — VolantisLive dark glass design
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
      context.read<ProfileProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Ambient glow blobs ─────────────────────────────────────
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD2BBFF).withOpacity(0.04),
              ),
            ),
          ),

          SafeArea(
            child: Consumer<ProfileProvider>(
              builder: (context, profileProvider, _) {
                return CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    _buildUserInfo(),
                    // _buildAnalyticsSection(profileProvider),
                    _buildDownloadsSection(profileProvider),
                    _buildSettingsSection(profileProvider),
                    _buildLogoutButton(),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                AppStrings.profile,
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                // TODO: Navigate to settings
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surfaceHigh,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: _onVariant,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── User info card ────────────────────────────────────────────────────────

  Widget _buildUserInfo() {
    return SliverToBoxAdapter(
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _glassCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primary.withOpacity(0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.15),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    imageUrl: user?.companySlug,
                    initials:
                        user?.username?.substring(0, 1).toUpperCase() ?? 'U',
                    size: 68,
                  ),
                ),
                const SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? 'User',
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(color: _onVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (user?.isActive == true
                                      ? _primary
                                      : Colors.orange)
                                  .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (user?.isActive == true
                                        ? _primary
                                        : Colors.orange)
                                    .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: user?.isActive == true
                                  ? _primary
                                  : Colors.orange,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user?.isActive == true ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: user?.isActive == true
                                    ? _primary
                                    : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit button
                GestureDetector(
                  onTap: () {
                    // TODO: Edit profile
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: _onVariant,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Analytics section ─────────────────────────────────────────────────────

  Widget _buildAnalyticsSection(ProfileProvider profileProvider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(AppStrings.listeningAnalytics),

          // Stats cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.access_time_rounded,
                    value: AnalyticsService.formatDuration(
                      profileProvider.totalListeningTime,
                    ),
                    label: AppStrings.totalListeningTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.local_fire_department_rounded,
                    value: '${profileProvider.listeningStreak}',
                    label: AppStrings.listeningStreak,
                    suffix: ' days',
                    accentColor: const Color(0xFFFF8C42),
                  ),
                ),
              ],
            ),
          ),

          // Favorite genres
          if (profileProvider.favoriteGenres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _glassCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: _primary,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.favoriteGenres,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profileProvider.favoriteGenres.map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _primary.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            genre['genre'] ?? '',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    String? suffix,
    Color? accentColor,
  }) {
    final color = accentColor ?? _primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    suffix,
                    style: const TextStyle(color: _outline, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _outline,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Downloads section ─────────────────────────────────────────────────────

  Widget _buildDownloadsSection(ProfileProvider profileProvider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  AppStrings.offlineDownloads,
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (profileProvider.downloads.isNotEmpty)
                  GestureDetector(
                    onTap: () => context.push('/downloads'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/downloads'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _glassCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _primaryCont],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.download_done_rounded,
                      color: _onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profileProvider.downloads.length} ${AppStrings.downloadedContent}',
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${AppStrings.storageUsed}: ${profileProvider.formatStorageSize(profileProvider.storageUsed)}',
                          style: const TextStyle(color: _outline, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _outline,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings section ──────────────────────────────────────────────────────

  Widget _buildSettingsSection(ProfileProvider profileProvider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(AppStrings.settings),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                // Audio Quality
                _buildSettingsTile(
                  icon: Icons.high_quality_rounded,
                  title: AppStrings.audioQuality,
                  trailing: _buildDropdown(
                    value: profileProvider.audioQuality,
                    items: const ['low', 'medium', 'high', 'auto'],
                    labels: const ['Low', 'Medium', 'High', 'Auto'],
                    onChanged: (v) {
                      if (v != null) profileProvider.setAudioQuality(v);
                    },
                  ),
                ),
                _buildDivider(),

                // WiFi only
                _buildSwitchTile(
                  icon: Icons.wifi_rounded,
                  title: AppStrings.downloadOverWifiOnly,
                  value: profileProvider.downloadOverWifiOnly,
                  onChanged: profileProvider.setDownloadOverWifiOnly,
                ),
                _buildDivider(),

                // Notifications
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: AppStrings.notifications,
                  value: profileProvider.notificationsEnabled,
                  onChanged: profileProvider.setNotificationsEnabled,
                ),
                _buildDivider(),

                // Dark mode
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: AppStrings.darkMode,
                  value: profileProvider.darkMode,
                  onChanged: profileProvider.setDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _onVariant, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _onVariant, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _onPrimary,
            activeTrackColor: _primary,
            inactiveThumbColor: _outline,
            inactiveTrackColor: _surfaceHigh,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outlineVar.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: const Color(0xFF222A3D),
          style: const TextStyle(
            color: _onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          icon: const Icon(
            Icons.expand_more_rounded,
            color: _outline,
            size: 16,
          ),
          items: List.generate(items.length, (i) {
            return DropdownMenuItem(value: items[i], child: Text(labels[i]));
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: _outlineVar.withOpacity(0.5),
    );
  }

  // ── Logout button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: GestureDetector(
          onTap: _showLogoutDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withOpacity(0.25), width: 1),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.redAccent, size: 17),
                SizedBox(width: 8),
                Text(
                  AppStrings.logout,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: _onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          AppStrings.logout,
          style: TextStyle(color: _onSurface, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _outline, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text(
              AppStrings.logout,
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDownloadsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Clear Downloads',
          style: TextStyle(color: _onSurface, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to delete all downloaded content?',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _outline, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileProvider>().clearAllDownloads();
            },
            child: const Text(
              'Clear',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
