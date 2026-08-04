import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/admin/admin_stats.dart';

// ─────────────────────────────────────────────
//  Bar Chart Painter
// ─────────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  final List<double> values;
  _BarChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final count = values.length;
    final totalGap = size.width * 0.35;
    final barWidth = (size.width - totalGap) / count;
    final gap = totalGap / (count + 1);
    final maxVal = values.reduce(math.max);
    final hasData = maxVal > 0;

    for (int i = 0; i < count; i++) {
      final x = gap + i * (barWidth + gap);
      final norm = hasData ? (values[i] / maxVal) : 0.0;
      final barH = hasData ? (size.height * 0.8 * norm) : 4.0;
      final rect = Rect.fromLTWH(x, size.height - barH, barWidth, barH);
      final isHighlight = hasData && i == count - 1;

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isHighlight
              ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.5)]
              : [const Color(0xFF3D2B20), const Color(0xFF2A1D15)],
        ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = AppColors.surfaceContainerHighest
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _period = '30D';

  Future<AdminStats> _fetchStats() async {
    final db = FirebaseFirestore.instance;

    final usersSnap = await db.collection('users').get();
    int donors = 0, ngos = 0, pendingNgos = 0, volunteers = 0;

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = data['role'] ?? 'donor';
      if (role == 'donor') donors++;
      if (role == 'ngo') {
        ngos++;
        if ((data['status'] ?? 'pending') == 'pending') pendingNgos++;
      }
      if (role == 'volunteer') volunteers++;
    }

    try {
      final volSnap = await db.collection('volunteers').get();
      volunteers += volSnap.docs.length;
    } catch (_) {}

    double totalKg = 0;
    int totalBeneficiaries = 0;
    List<Map<String, dynamic>> logisticsList = [];
    List<double> chartBuckets = List.filled(12, 0.0);

    try {
      final donationsSnap = await db
          .collection('donations')
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in donationsSnap.docs) {
        final data = doc.data();
        final qty =
            (data['quantityKg'] ?? data['quantity'] ?? data['weight'] ?? 0)
                .toDouble();
        final benRaw = data['beneficiariesCount'] ?? data['beneficiaries'] ?? 0;
        final ben = (benRaw is num)
            ? benRaw.toInt()
            : (int.tryParse(benRaw.toString()) ?? 0);

        totalKg += qty;
        totalBeneficiaries += ben;

        if (logisticsList.length < 5) {
          logisticsList.add({
            'title': data['title'] ?? data['foodItem'] ?? 'Donation Item',
            'subtitle':
                data['ngoName'] ?? data['donorName'] ?? data['location'] ?? '',
            'amount': qty > 0 ? '+${qty.toStringAsFixed(0)} kg' : '',
            'status': (data['status'] ?? 'pending').toString().toUpperCase(),
          });
        }

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
          final now = DateTime.now();
          final diffDays = now.difference(created).inDays;
          int daysLimit =
              _period == '7D' ? 7 : (_period == '90D' ? 90 : 30);
          if (diffDays >= 0 && diffDays <= daysLimit) {
            int bucket =
                ((1.0 - (diffDays / daysLimit)) * 11).clamp(0, 11).toInt();
            chartBuckets[bucket] += qty > 0 ? qty : 1;
          }
        }
      }
    } catch (_) {}

    List<Map<String, dynamic>> operationsList = [];
    try {
      final opSnap = await db
          .collection('operations')
          .where('status', isEqualTo: 'active')
          .get();
      for (final doc in opSnap.docs) {
        operationsList.add(doc.data());
      }
    } catch (_) {}

    int lowStockCount = 0;
    try {
      final lowStockSnap = await db
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .where('lowStock', isEqualTo: true)
          .get();
      lowStockCount = lowStockSnap.docs.length;
    } catch (_) {}

    return AdminStats(
      donorsCount: donors,
      ngosCount: ngos,
      pendingNgosCount: pendingNgos,
      volunteersCount: volunteers,
      foodTons: totalKg / 1000.0,
      totalBeneficiaries: totalBeneficiaries,
      chartValues: chartBuckets,
      lowStockCount: lowStockCount,
      recentLogistics: logisticsList,
      activeOperations: operationsList,
      qualityScorePercent: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceContainerLow,
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section Label ──
                Text(
                  'OVERVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Platform Summary',
                  style: GoogleFonts.publicSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2x2 Stats Grid (fixed, always) ──
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _StatCard(
                      icon: Icons.person_outline,
                      label: 'DONORS',
                      value: isLoading ? '--' : '${stats?.donorsCount ?? 0}',
                      badge: 'Live',
                      badgeColor: AppColors.secondary,
                    ),
                    _StatCard(
                      icon: Icons.shield_outlined,
                      label: 'NGOS',
                      value: isLoading ? '--' : '${stats?.ngosCount ?? 0}',
                      badge: 'Live',
                      badgeColor: AppColors.textSecondary,
                    ),
                    _StatCard(
                      icon: Icons.group_outlined,
                      label: 'VOLUNTEERS',
                      value: isLoading
                          ? '--'
                          : '${stats?.volunteersCount ?? 0}',
                      badge: 'Live',
                      badgeColor: AppColors.secondary,
                    ),
                    _StatCard(
                      icon: Icons.restaurant_outlined,
                      label: 'FOOD (TONS)',
                      value: isLoading
                          ? '--'
                          : (stats?.foodTons ?? 0) > 0
                              ? stats!.foodTons.toStringAsFixed(2)
                              : '0',
                      badge: 'Live',
                      badgeColor: Colors.white54,
                      isHighlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Beneficiaries Banner ──
                _BeneficiariesCard(
                  beneficiaries: stats?.totalBeneficiaries ?? 0,
                  pendingNgos: stats?.pendingNgosCount ?? 0,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 20),

                // ── Trends ──
                _TrendsSection(
                  period: _period,
                  onPeriodChanged: (p) => setState(() => _period = p),
                  chartValues:
                      stats?.chartValues ?? List.filled(12, 0.0),
                ),
                const SizedBox(height: 16),

                // ── Active Operation ──
                _ActiveOperationCard(
                  operations: stats?.activeOperations ?? [],
                ),
                const SizedBox(height: 16),

                // ── Low Stock Alert ──
                if ((stats?.lowStockCount ?? 0) > 0) ...[
                  _AlertRow(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.tertiary,
                    title: 'Low Stock Alerts',
                    subtitle:
                        '${stats!.lowStockCount} NGO(s) requiring restock',
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Recent Logistics ──
                _RecentLogisticsSection(
                  logistics: stats?.recentLogistics ?? [],
                  isLoading: isLoading,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Stat Card
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String badge;
  final Color badgeColor;
  final bool isHighlighted;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        isHighlighted ? AppColors.primary : AppColors.surfaceContainerLow;
    final textColor = isHighlighted ? Colors.white : AppColors.textPrimary;
    final subColor =
        isHighlighted ? Colors.white70 : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? null
            : Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon,
                  color: isHighlighted
                      ? Colors.white70
                      : AppColors.textSecondary,
                  size: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.15)
                      : badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? Colors.white : badgeColor,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subColor,
                    letterSpacing: 0.8,
                  )),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.publicSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textColor,
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
//  Beneficiaries Card
// ─────────────────────────────────────────────
class _BeneficiariesCard extends StatelessWidget {
  final int beneficiaries;
  final int pendingNgos;
  final bool isLoading;

  const _BeneficiariesCard({
    required this.beneficiaries,
    required this.pendingNgos,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              const Icon(Icons.groups_outlined,
                  color: AppColors.textSecondary, size: 20),
              if (pendingNgos > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pendingNgos pending NGO(s)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('TOTAL BENEFICIARIES',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 4),
          Text(
            isLoading ? '--' : '$beneficiaries',
            style: GoogleFonts.publicSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Trends Section
// ─────────────────────────────────────────────
class _TrendsSection extends StatelessWidget {
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final List<double> chartValues;

  const _TrendsSection({
    required this.period,
    required this.onPeriodChanged,
    required this.chartValues,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = chartValues.any((v) => v > 0);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trends',
                      style: GoogleFonts.publicSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    hasData
                        ? 'Donation volume ($period)'
                        : 'No data yet',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: ['7D', '30D', '90D'].map((p) {
                  final isActive = p == period;
                  return GestureDetector(
                    onTap: () => onPeriodChanged(p),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.surfaceContainerHighest
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(chartValues),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$period Ago',
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
//  Active Operation Card
// ─────────────────────────────────────────────
class _ActiveOperationCard extends StatelessWidget {
  final List<Map<String, dynamic>> operations;
  const _ActiveOperationCard({required this.operations});

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceContainerHighest),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No Active Operations',
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    'Active campaigns & drives will appear here',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final topOp = operations.first;
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1A0E), Color(0xFF1C140C)],
        ),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('ACTIVE OPERATION',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      )),
                ),
                const SizedBox(height: 6),
                Text(
                  topOp['title'] ?? topOp['name'] ?? 'Active Operation',
                  style: GoogleFonts.publicSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Alert Row
// ─────────────────────────────────────────────
class _AlertRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _AlertRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.publicSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Recent Logistics Section
// ─────────────────────────────────────────────
class _RecentLogisticsSection extends StatelessWidget {
  final List<Map<String, dynamic>> logistics;
  final bool isLoading;

  const _RecentLogisticsSection({
    required this.logistics,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Logistics',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (logistics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerHighest),
            ),
            child: Center(
              child: Text(
                'No recent logistics records in DB yet.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Column(
            children: logistics.map((item) {
              final badgeColor = (item['status'] == 'COMPLETED' ||
                      item['status'] == 'VERIFIED')
                  ? AppColors.secondary
                  : AppColors.tertiary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LogItem(
                  title: item['title'] ?? 'Logistics Item',
                  subtitle: item['subtitle'] ?? '',
                  badgeText: item['amount'] ?? '',
                  badgeLabel: item['status'] ?? 'PENDING',
                  badgeColor: badgeColor,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _LogItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final String badgeLabel;
  final Color badgeColor;

  const _LogItem({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeLabel,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (badgeText.isNotEmpty)
                Text(badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    )),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                      letterSpacing: 0.5,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
