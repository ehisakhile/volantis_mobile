import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/streams/presentation/screens/streams_screen.dart';
import '../features/streams/presentation/providers/streams_provider.dart';
import '../features/streams/presentation/widgets/live_stream_mini_player.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/recordings/presentation/providers/recordings_provider.dart';
import '../features/recordings/presentation/widgets/mini_player.dart';

/// Main screen with bottom navigation — VolantisLive dark glass design
class MainScreen extends StatefulWidget {
  final Widget? child;
  final Function(int)? onTabChanged;
  final int currentIndex;

  const MainScreen({
    super.key,
    this.child,
    this.onTabChanged,
    this.currentIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _indicatorCtrl;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060E20); // deepest navy for nav
  static const _surface = Color(0xFF0B1326);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onPrimary = Color(0xFF00344D);
  static const _secondary = Color(0xFFD2BBFF);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);

  static const _navItems = [
    _NavItem(
      label: 'Discover',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      route: '/home',
    ),
    _NavItem(
      label: 'Streams',
      icon: Icons.podcasts_outlined,
      activeIcon: Icons.podcasts_rounded,
      route: '/streams',
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      route: '/profile',
    ),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    StreamsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (widget.currentIndex == index) return;

    _indicatorCtrl.forward(from: 0);

    if (widget.onTabChanged != null) {
      widget.onTabChanged!(index);
    } else {
      context.go(_navItems[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          IndexedStack(index: widget.currentIndex, children: _screens),
          // Persistent mini player at bottom - recordings
          Positioned(
            left: 0,
            right: 0,
            bottom: 10, // Above navbar
            child: Consumer<RecordingsProvider>(
              builder: (context, recordingsProvider, _) {
                if (!recordingsProvider.hasActivePlayer) {
                  return const SizedBox.shrink();
                }
                return const MiniPlayer();
              },
            ),
          ),
          // Persistent mini player at bottom - live streams
          Positioned(
            left: 0,
            right: 0,
            bottom: 10, // Above navbar
            child: Consumer<StreamsProvider>(
              builder: (context, streamsProvider, _) {
                if (!streamsProvider.hasActivePlayer) {
                  return const SizedBox.shrink();
                }
                return const LiveStreamMiniPlayer();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _VolantisNavBar(
        currentIndex: widget.currentIndex,
        items: _navItems,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Nav bar
// ──────────────────────────────────────────────────────────────────────────────

class _VolantisNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  static const _bg = Color(0xFF060E20);
  static const _glassCard = Color(0xFF171F33);
  static const _primary = Color(0xFF89CEFF);
  static const _outlineVar = Color(0xFF3E4850);

  const _VolantisNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        // Top border line
        border: const Border(
          top: BorderSide(color: Color(0xFF1A2540), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              return _NavTab(
                item: items[i],
                isSelected: currentIndex == i,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Individual nav tab
// ──────────────────────────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onPrimary = Color(0xFF00344D);
  static const _outline = Color(0xFF88929B);

  const _NavTab({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with animated pill background
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [
                          Color(0x2689CEFF), // primary/15%
                          Color(0x140EA5E9), // primaryCont/8%
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isSelected
                    ? Border.all(color: _primary.withOpacity(0.25), width: 1)
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey('${item.label}_$isSelected'),
                  color: isSelected ? _primary : _outline,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(height: 5),

            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? _primary : _outline,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: isSelected ? 0.2 : 0.0,
              ),
              child: Text(item.label),
            ),

            // Active dot indicator
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isSelected ? 16 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [_primary, _primaryCont])
                    : null,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Data model
// ──────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}
