import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'ngo_dashboard_screen.dart';
import 'ngo_map_screen.dart';
import 'donation_feed_screen.dart';
import 'volunteer_mgmt_screen.dart';
import 'ngo_profile_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NgoHome extends ConsumerStatefulWidget {
  const NgoHome({super.key});

  @override
  ConsumerState<NgoHome> createState() => _NgoHomeState();
}

class _NgoHomeState extends ConsumerState<NgoHome> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();;
    _screens = [
      NgoDashboardScreen(
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const NgoMapScreen(),
      const DonationFeedScreen(),
      const VolunteerMgmtScreen(),
      const NgoProfileScreen(),
    ];
  }

  Widget _buildTopOrangeHeader(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final String currentNgoId =
        FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ngos')
            .doc(currentNgoId)
            .snapshots(),
        builder: (context, ngoSnap) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentNgoId)
                .snapshots(),
            builder: (context, userSnap) {
              String ngoName = '';
              String profileUrl = '';

              if (ngoSnap.hasData && ngoSnap.data!.exists) {
                final data = ngoSnap.data!.data() as Map<String, dynamic>;
                ngoName = (data['name'] as String? ?? '').trim();
                profileUrl =
                    data['profileImageUrl'] as String? ?? profileUrl;
              }
              if (ngoName.isEmpty &&
                  userSnap.hasData &&
                  userSnap.data!.exists) {
                final data = userSnap.data!.data() as Map<String, dynamic>;
                ngoName = (data['name'] as String? ?? '').trim();
                if (profileUrl.isEmpty) {
                  profileUrl = data['profileImageUrl'] as String? ?? '';
                }
              }
              if (ngoName.isEmpty) {
                ngoName =
                    FirebaseAuth.instance.currentUser?.displayName?.trim() ??
                        '';
              }

              final String displayName =
                  ngoName.isNotEmpty ? ngoName : 'NGO Partner';
              final String avatarInitials =
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'N';

              return AppBar(
                backgroundColor: AppColors.primary,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sahyog',
                      style: GoogleFonts.publicSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: Colors.white, size: 22),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.primary,
                          content: Text(
                            'No new notifications',
                            style: GoogleFonts.publicSans(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 4; // Go to Profile
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                        border: Border.all(color: Colors.white, width: 1.5),
                        image: profileUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(profileUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: profileUrl.isEmpty
                          ? Text(
                              avatarInitials,
                              style: GoogleFonts.publicSans(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_currentIndex == 4)
                    IconButton(
                      icon: const Icon(Icons.menu,
                          color: Colors.white, size: 22),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text(
                              'NGO Menu option coming soon!',
                              style:
                                  GoogleFonts.publicSans(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(width: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color navBg = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.surfaceContainerLow;
    final Color navBorder = isDark
        ? AppColors.darkSurfaceContainerHighest
        : AppColors.surfaceContainerHighest;
    final Color scaffoldBg = isDark
        ? AppColors.darkBackground
        : AppColors.background;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildTopOrangeHeader(context) as PreferredSizeWidget,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: navBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home', colorScheme, isDark),
              _buildNavItem(1, Icons.map_outlined, Icons.map, 'Map', colorScheme, isDark),
              _buildMiddleNavItem(2, 'Requests'),
              _buildNavItem(3, Icons.handshake_outlined, Icons.handshake, 'Community', colorScheme, isDark),
              _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile', colorScheme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final bool isSelected = _currentIndex == index;
    final Color selectedColor = AppColors.primary;
    final Color unselectedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final Color itemColor = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              color: itemColor,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: itemColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiddleNavItem(int index, String label) {
    final bool isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}