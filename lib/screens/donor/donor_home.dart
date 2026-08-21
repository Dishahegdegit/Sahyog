import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'donor_dashboard.dart';
import 'create_donation_screen.dart';
import 'donation_history_screen.dart';
import 'donor_profile_screen.dart';

class DonorHome extends StatefulWidget {
  const DonorHome({super.key});

  @override
  State<DonorHome> createState() => _DonorHomeState();
}

class _DonorHomeState extends State<DonorHome> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Keep pages stable so IndexedStack does not recreate the dashboard
    // (which restarts the carousel and causes glitching).
    _pages = [
      DonorDashboard(onTabChange: _changeTab),
      const CreateDonationScreen(),
      const DonationHistoryScreen(),
      const DonorProfileScreen(),
    ];
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final navItems = [
      _NavItemData(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Home'),
      _NavItemData(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle_rounded, label: 'Donate'),
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

                return Semantics(
                  label: item.label,
                  selected: isActive,
                  button: true,
                  child: InkWell(
                    onTap: () => _changeTab(index),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isActive ? (compact ? 12 : 16) : (compact ? 8 : 12),
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primaryTint : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: isActive
                            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive ? AppColors.primary : c.textSecondary,
                            size: 24,
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
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
