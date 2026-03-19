import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../features/home/presentation/providers/home_provider.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/streams/presentation/providers/streams_provider.dart';
import '../features/streams/presentation/screens/streams_screen.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../features/profile/presentation/screens/profile_screen.dart';

/// Main screen with bottom navigation
class MainScreen extends StatefulWidget {
  final Widget? child;
  final Function(int)? onTabChanged;

  const MainScreen({super.key, this.child, this.onTabChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    StreamsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Use IndexedStack for managing tab navigation
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: AppStrings.home,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.wifi_outlined,
                activeIcon: Icons.wifi,
                label: AppStrings.streams,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: AppStrings.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        // Update local state for visual indication
        setState(() {
          _currentIndex = index;
        });

        // Use callback if provided, otherwise use GoRouter
        if (widget.onTabChanged != null) {
          widget.onTabChanged!(index);
        } else {
          // Navigate using GoRouter
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/streams');
              break;
            case 2:
              context.go('/profile');
              break;
          }
        }

        // Initialize data when switching tabs
        if (index == 0) {
          context.read<HomeProvider>().init();
        } else if (index == 1) {
          context.read<StreamsProvider>().init();
        } else if (index == 2) {
          context.read<ProfileProvider>().init();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
