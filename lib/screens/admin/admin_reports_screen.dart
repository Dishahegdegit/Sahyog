import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchReportData(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        return SingleChildScrollView(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
                  // ── Header ──
                  Text(
                    'REPORTS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reports & Analytics',
                    style: GoogleFonts.publicSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'System health and platform metrics summary',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else ...[
                    // ── 2x2 Fixed Stats Grid ──
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _ReportCard(
                          title: 'Total Users',
                          value: '${data['totalUsers'] ?? 0}',
                          icon: Icons.people_alt_outlined,
                          color: AppColors.primary,
                        ),
                        _ReportCard(
                          title: 'Approved NGOs',
                          value: '${data['approvedNgos'] ?? 0}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.secondary,
                        ),
                        _ReportCard(
                          title: 'Total Donations',
                          value: '${data['totalDonations'] ?? 0}',
                          icon: Icons.volunteer_activism_outlined,
                          color: AppColors.tertiary,
                        ),
                        _ReportCard(
                          title: 'Pending Approvals',
                          value: '${data['pendingNgos'] ?? 0}',
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Breakdown Section ──
                    Text(
                      'Role Breakdown',
                      style: GoogleFonts.publicSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _BreakdownRow(
                      label: 'Donors',
                      count: data['donors'] ?? 0,
                      total: data['totalUsers'] ?? 1,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _BreakdownRow(
                      label: 'NGOs',
                      count: data['totalNgos'] ?? 0,
                      total: data['totalUsers'] ?? 1,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 10),
                    _BreakdownRow(
                      label: 'Volunteers',
                      count: data['volunteers'] ?? 0,
                      total: data['totalUsers'] ?? 1,
                      color: AppColors.tertiary,
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      }

  Future<Map<String, dynamic>> _fetchReportData() async {
    final db = FirebaseFirestore.instance;
    final usersSnap = await db.collection('users').get();

    int totalUsers = usersSnap.docs.length;
    int approvedNgos = 0, pendingNgos = 0, totalNgos = 0;
    int donors = 0, volunteers = 0;

    for (final doc in usersSnap.docs) {
      final map = doc.data();
      final role = map['role'] ?? 'donor';
      if (role == 'ngo') {
        totalNgos++;
        final status = map['status'] ?? 'pending';
        if (status == 'approved') approvedNgos++;
        if (status == 'pending') pendingNgos++;
      }
      if (role == 'donor') donors++;
      if (role == 'volunteer') volunteers++;
    }

    int totalDonations = 0;
    try {
      final donationsSnap = await db.collection('donations').get();
      totalDonations = donationsSnap.docs.length;
    } catch (_) {}

    return {
      'totalUsers': totalUsers,
      'approvedNgos': approvedNgos,
      'pendingNgos': pendingNgos,
      'totalDonations': totalDonations,
      'totalNgos': totalNgos,
      'donors': donors,
      'volunteers': volunteers,
    };
  }
}

// ─────────────────────────────────────────────
//  Report Card (stat card)
// ─────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.publicSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Breakdown Row with progress bar
// ─────────────────────────────────────────────
class _BreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? count / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                count.toString(),
                style: GoogleFonts.publicSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppColors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
