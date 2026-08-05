import 'package:flutter/material.dart';
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

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DonorDashboard(onTabChange: _changeTab),
      const CreateDonationScreen(),
      const DonationHistoryScreen(),
      const DonorProfileScreen(),
    ];

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    const primaryOrange = Color(0xFFFF5E2B);
    const darkNavBackground = Color(0xFF14171A);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: darkNavBackground,
          border: Border(
            top: BorderSide(color: Color(0xFF2A2F33), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _changeTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: darkNavBackground,
          selectedItemColor: primaryOrange,
          unselectedItemColor: const Color(0xFF8C959E),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle_rounded),
              label: 'DONATE',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'HISTORY',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'PROFILE',
            ),
          ],
        ),
      ),
    );
  }
}
