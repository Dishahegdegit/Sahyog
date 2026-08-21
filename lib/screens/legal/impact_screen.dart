import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class ImpactAchievementsScreen extends StatelessWidget {
  const ImpactAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Impact & Achievements', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: user != null
                  ? FirebaseFirestore.instance.collection('donations').where('donorId', isEqualTo: user.uid).snapshots()
                  : null,
              builder: (context, snapshot) {
                int totalMeals = 0;
                int totalDonations = 0;

                if (snapshot.hasData) {
                  totalDonations = snapshot.data!.docs.length;
                  for (var doc in snapshot.data!.docs) {
                    final status = (doc.data()['status'] ?? '').toString().toLowerCase();
                    if (status == 'completed' || status == 'delivered') {
                      final servings = doc.data()['servings'];
                      totalMeals += servings is int ? servings : int.tryParse(servings?.toString() ?? '0') ?? 0;
                    }
                  }
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 54, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text('Community Hunger Champion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('You have created $totalDonations donation drives and shared $totalMeals meals!', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Milestone Badges Unlocked', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          Divider(color: c.borderLight, height: 24),
                          _buildBadgeTile(c, Icons.military_tech_rounded, 'First Donor Shield', 'Completed 1st verified food donation drive', totalDonations >= 1),
                          _buildBadgeTile(c, Icons.workspace_premium_rounded, 'Century Feeder', 'Shared 100+ meals with partner NGOs', totalMeals >= 100),
                          _buildBadgeTile(c, Icons.star_rounded, 'Zero Waste Guardian', 'Contributed consistently to zero food waste', totalDonations >= 5),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeTile(AppColorSet c, IconData icon, String title, String subtitle, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: unlocked ? AppColors.primaryTint : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: unlocked ? AppColors.primary : c.textHint, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: unlocked ? c.textPrimary : c.textHint)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ),
          Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: unlocked ? AppColors.statusDelivered : c.textHint),
        ],
      ),
    );
  }
}
