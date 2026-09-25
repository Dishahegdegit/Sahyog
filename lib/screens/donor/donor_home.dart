import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'donor_dashboard.dart';
import 'create_donation_screen.dart';
import 'donation_history_screen.dart';
import 'donor_map_screen.dart';
import 'donor_profile_screen.dart';

class DonorHome extends StatefulWidget {
  const DonorHome({super.key});

  @override
  State<DonorHome> createState() => _DonorHomeState();
}

class _DonorHomeState extends State<DonorHome> {
  int _currentIndex = 0;
  List<Widget> get _pages => [
        DonorDashboard(onTabChange: _changeTab),
        CreateDonationScreen(onTabChange: _changeTab),
        DonorMapScreen(onTabChange: _changeTab),
        DonationHistoryScreen(onTabChange: _changeTab),
        const DonorProfileScreen(),
      ];

  void _changeTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final navItems = [
      _NavItemData(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Home'),
      _NavItemData(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle_rounded, label: 'Donate'),
      _NavItemData(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Track'),
      _NavItemData(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History'),
      _NavItemData(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            top: BorderSide(color: c.outlineVariant, width: 1),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: Responsive.of(context).isCompact ? 60 : 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isActive = _currentIndex == index;
                final compact = Responsive.of(context).isCompact;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _changeTab(index),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? AppColors.primary : c.textSecondary,
                          size: 22,
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
