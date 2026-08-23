import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFFFF8C5A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'About App',
          style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: _buildOverviewTab(colors),
    );
  }

  // ─── OVERVIEW TAB ──────────────────────────────────────────────
  Widget _buildOverviewTab(AppColorSet colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // App Header Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.secondary.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.volunteer_activism, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sahyog',
                  style: GoogleFonts.publicSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (Build 2026)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Bridging Surplus Food & Community Need',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About Description Card
          _buildCard(
            colors: colors,
            title: 'About the Platform',
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.primary,
            child: Text(
              'Sahyog is a unified community initiative designed to reduce food waste and combat hunger. By seamlessly connecting food donors (restaurants, events, households) with verified NGOs and volunteer pickup drivers, Sahyog ensures that surplus food is safely redirected to those who need it most.',
              style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),

          // Core Features List
          _buildCard(
            colors: colors,
            title: 'Key Capabilities',
            icon: Icons.stars_rounded,
            iconColor: AppColors.secondary,
            child: Column(
              children: [
                _buildFeatureRow(Icons.map_outlined, 'Live Map Tracking', 'Real-time location monitoring of NGO hubs, donors, and active pickup routes.', colors),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.verified_user_outlined, 'Verified Network', 'Vetted NGO credentials and donor authenticity badges to ensure trust.', colors),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.speed_rounded, 'Instant Matching', 'Smart dispatch matching donor pickups with nearby volunteers.', colors),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.bar_chart_rounded, 'Impact Analytics', 'Comprehensive reports tracking meals served and waste reduced.', colors),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── HELPER CARD ───────────────────────────────────────────────
  Widget _buildCard({
    required AppColorSet colors,
    required String title,
    IconData? icon,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc, AppColorSet colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
