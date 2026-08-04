import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/admin/ngo_approval_item.dart';

// ─────────────────────────────────────────────
//  Line Chart Painter
// ─────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;

  _LineChartPainter({required this.values, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce(math.max);
    final hasData = maxVal > 0;

    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final norm = hasData ? (values[i] / maxVal) : 0.0;
      final y = size.height - norm * size.height * 0.75;

      if (i == 0) {
        fillPath.moveTo(x, y);
        linePath.moveTo(x, y);
      } else {
        final prevX = ((i - 1) / (values.length - 1)) * size.width;
        final prevNorm = hasData ? (values[i - 1] / maxVal) : 0.0;
        final prevY = size.height - prevNorm * size.height * 0.75;
        final cpx1 = prevX + (x - prevX) * 0.5;
        final cpx2 = x - (x - prevX) * 0.5;
        linePath.cubicTo(cpx1, prevY, cpx2, y, x, y);
        fillPath.cubicTo(cpx1, prevY, cpx2, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────
class NgoApprovalScreen extends StatefulWidget {
  const NgoApprovalScreen({super.key});

  @override
  State<NgoApprovalScreen> createState() => _NgoApprovalScreenState();
}

class _NgoApprovalScreenState extends State<NgoApprovalScreen> {
  String _searchQuery = '';

  Future<void> _approveNGO(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'status': 'approved'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar('NGO approved successfully', AppColors.secondary),
    );
  }

  Future<void> _rejectNGO(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'status': 'rejected'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar('Application rejected', AppColors.error),
    );
  }

  SnackBar _snackBar(String msg, Color color) => SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .snapshots(),
      builder: (context, snapshot) {
        final allNGOs = snapshot.data?.docs ?? [];

        final pending = allNGOs
            .where((d) =>
                ((d.data() as Map)['status'] ?? 'pending') == 'pending')
            .toList();

        final approved = allNGOs
            .where((d) => (d.data() as Map)['status'] == 'approved')
            .toList();

        final rejected = allNGOs
            .where((d) => (d.data() as Map)['status'] == 'rejected')
            .toList();

        final filteredPending = pending.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase()) ||
              email.contains(_searchQuery.toLowerCase());
        }).toList();

        // Weekly trend from real timestamps
        List<double> weeklyBuckets = List.filled(7, 0.0);
        final now = DateTime.now();
        for (final doc in allNGOs) {
          final data = doc.data() as Map<String, dynamic>;
          DateTime? created;
          if (data['createdAt'] != null) {
            if (data['createdAt'] is String) {
              created = DateTime.tryParse(data['createdAt']);
            } else {
              try {
                created = data['createdAt'].toDate() as DateTime?;
              } catch (_) {}
            }
          }
          if (created != null) {
            final diff = now.difference(created).inDays;
            if (diff >= 0 && diff < 7) weeklyBuckets[6 - diff] += 1.0;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  // ── Header ──
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'VERIFICATION PORTAL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pending Approvals',
                          style: GoogleFonts.publicSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (pending.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pending.length} NEW',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Search Bar ──
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.surfaceContainerHighest),
                    ),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search by name or email...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary, size: 18),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── NGO Cards ──
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else if (allNGOs.isEmpty)
                    _EmptyState()
                  else ...[
                    if (filteredPending.isNotEmpty) ...[
                      Column(
                        children: filteredPending.map((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>;
                          final item =
                              NgoApprovalItem.fromMap(data, doc.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NgoCard(
                              item: item,
                              onApprove: () => _approveNGO(doc.id),
                              onReject: () => _rejectNGO(doc.id),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else if (_searchQuery.isNotEmpty) ...[
                      Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No results for "$_searchQuery"',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ] else ...[
                      _EmptyState(),
                    ],

                    // ── Approved / Rejected Summary ──
                    if (approved.isNotEmpty || rejected.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (approved.isNotEmpty)
                            _MiniCountBadge(
                              label: 'Approved',
                              count: approved.length,
                              color: AppColors.secondary,
                            ),
                          if (approved.isNotEmpty &&
                              rejected.isNotEmpty)
                            const SizedBox(width: 8),
                          if (rejected.isNotEmpty)
                            _MiniCountBadge(
                              label: 'Rejected',
                              count: rejected.length,
                              color: AppColors.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Weekly Trend ──
                    _WeeklyTrendSection(
                      trendValues: weeklyBuckets,
                      totalCount: allNGOs.length,
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
  }
}

// ─────────────────────────────────────────────
//  NGO Card
// ─────────────────────────────────────────────
class _NgoCard extends StatelessWidget {
  final NgoApprovalItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _NgoCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + Status
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  item.initials,
                  style: GoogleFonts.publicSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.registrationId,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PENDING',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.surfaceContainerHighest, height: 1),
          const SizedBox(height: 12),

          // Details
          if (item.address.isNotEmpty)
            _DetailRow(
                icon: Icons.location_on_outlined, text: item.address),
          if (item.email.isNotEmpty)
            _DetailRow(icon: Icons.email_outlined, text: item.email),
          if (item.phone.isNotEmpty)
            _DetailRow(icon: Icons.phone_outlined, text: item.phone),

          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Reject',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Approve',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Mini Count Badge
// ─────────────────────────────────────────────
class _MiniCountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniCountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Weekly Trend Section
// ─────────────────────────────────────────────
class _WeeklyTrendSection extends StatelessWidget {
  final List<double> trendValues;
  final int totalCount;

  const _WeeklyTrendSection({
    required this.trendValues,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = trendValues.any((v) => v > 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Applications',
                style: GoogleFonts.publicSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$totalCount total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasData ? 'NGO registrations in last 7 days' : 'No registrations in last 7 days',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                  values: trendValues, lineColor: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7 days ago',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textSecondary)),
              Text('Today',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.verified_outlined,
                size: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No Pending Approvals',
              style: GoogleFonts.publicSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'NGO applications will appear here once submitted.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
