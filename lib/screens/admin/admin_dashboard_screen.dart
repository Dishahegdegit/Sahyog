import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/admin/admin_stats.dart';
import 'ngo_approval_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

// ─────────────────────────────────────────────────────────────────
//  Area Chart Painter (light-theme, smooth line with fill)
// ─────────────────────────────────────────────────────────────────
class _AreaChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  _AreaChartPainter(this.values, this.lineColor, this.fillColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce(math.max);
    if (maxVal == 0) return;

    final count = values.length;
    final dx = size.width / (count - 1);

    List<Offset> points = [];
    for (int i = 0; i < count; i++) {
      final x = i * dx;
      final y = size.height - (values[i] / maxVal) * size.height * 0.85;
      points.add(Offset(x, y));
    }

    // Smooth path (cubic bezier)
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }

    // Fill area
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // End dot
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = lineColor,
    );
    canvas.drawCircle(
      points.last,
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _period = '30D';

  double _donationQuantityKg(Map<String, dynamic> data) {
    for (final key in ['quantityKg', 'quantity', 'weight']) {
      final v = data[key];
      if (v is num) return v.toDouble();
      if (v != null) {
        final parsed = double.tryParse(v.toString());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    final foodQty = (data['foodQuantity'] ?? '').toString();
    final kgMatch = RegExp(r'([\d.]+)\s*kg', caseSensitive: false).firstMatch(foodQty);
    if (kgMatch != null) return double.tryParse(kgMatch.group(1)!) ?? 0;
    final numMatch = RegExp(r'^([\d.]+)').firstMatch(foodQty);
    if (numMatch != null) return double.tryParse(numMatch.group(1)!) ?? 0;
    return 0;
  }

  int _donationServings(Map<String, dynamic> data) {
    final raw = data['servings'] ?? data['beneficiariesCount'] ?? data['beneficiaries'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  bool _isCollectedStatus(String status) {
    const collected = {
      'accepted', 'picked up', 'volunteer assigned', 'on delivery',
      'completed', 'delivered', 'verified',
    };
    return collected.contains(status);
  }

  bool _isDistributedStatus(String status) {
    const distributed = {'delivered', 'completed', 'verified'};
    return distributed.contains(status);
  }

  // ── Data fetch ──────────────────────────────────────────────
  Future<AdminStats> _fetchStats() async {
    final db = FirebaseFirestore.instance;

    final usersSnap = await db.collection('users').get();
    int donors = 0, ngos = 0, pendingNgos = 0;

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = data['role'] ?? 'donor';
      if (role == 'donor') donors++;
      if (role == 'ngo') {
        ngos++;
        if ((data['status'] ?? 'pending') == 'pending') pendingNgos++;
      }
    }

    int activeVolunteers = 0;
    try {
      final volSnap = await db.collection('volunteers').get();
      activeVolunteers = volSnap.docs.where((doc) {
        final status = (doc.data()['status'] ?? 'Available').toString().toLowerCase();
        return status == 'available' || status == 'on delivery';
      }).length;
    } catch (_) {}

    double foodCollectedKg = 0;
    double foodDistributedKg = 0;
    int totalBeneficiaries = 0;
    int donationsCount = 0;
    List<Map<String, dynamic>> logisticsList = [];
    List<double> chartBuckets = List.filled(12, 0.0);

    try {
      final donationsSnap = await db
          .collection('donations')
          .orderBy('createdAt', descending: true)
          .get();

      donationsCount = donationsSnap.docs.length;

      for (final doc in donationsSnap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final qty = _donationQuantityKg(data);
        final servings = _donationServings(data);

        if (_isCollectedStatus(status)) foodCollectedKg += qty;
        if (_isDistributedStatus(status)) {
          foodDistributedKg += qty;
          totalBeneficiaries += servings;
        }

        if (logisticsList.length < 5) {
          logisticsList.add({
            'title': data['title'] ?? data['foodItem'] ?? data['foodType'] ?? 'Donation Item',
            'subtitle':
                data['ngoName'] ?? data['donorName'] ?? data['location'] ?? data['pickupAddress'] ?? '',
            'amount': qty > 0 ? '+${qty.toStringAsFixed(0)} kg' : (servings > 0 ? '+$servings meals' : ''),
            'status': status.toUpperCase(),
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
          int daysLimit = _period == '7D' ? 7 : (_period == '90D' ? 90 : 30);
          if (diffDays >= 0 && diffDays <= daysLimit) {
            int bucket = ((1.0 - (diffDays / daysLimit)) * 11).clamp(0, 11).toInt();
            chartBuckets[bucket] += qty > 0 ? qty : (servings > 0 ? servings.toDouble() : 1);
          }
        }
      }
    } catch (_) {}

    // Pending NGOs for approvals section
    List<Map<String, dynamic>> pendingNgosList = [];
    try {
      final pendingSnap = await db
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .where('status', isEqualTo: 'pending')
          .limit(3)
          .get();
      for (final doc in pendingSnap.docs) {
        pendingNgosList.add({'uid': doc.id, ...doc.data()});
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
      donationsCount: donationsCount,
      volunteersCount: activeVolunteers,
      foodCollectedKg: foodCollectedKg,
      foodDistributedKg: foodDistributedKg,
      foodTons: foodCollectedKg / 1000.0,
      totalBeneficiaries: totalBeneficiaries,
      chartValues: chartBuckets,
      lowStockCount: lowStockCount,
      recentLogistics: logisticsList,
      activeOperations: operationsList,
      qualityScorePercent: null,
      pendingNgosList: pendingNgosList,
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<AdminStats>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: colors.surface,
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                _buildHeader(colors),
                const SizedBox(height: 20),

                // ── Stat Cards Row ───────────────────────────────
                _buildStatCardsRow(stats, isLoading),
                const SizedBox(height: 16),

                // ── Beneficiaries Banner ─────────────────────────
                _buildBeneficiariesBanner(stats, isLoading),
                const SizedBox(height: 16),

                // ── Donation Trends Chart ────────────────────────
                _buildTrendsCard(stats, isLoading),
                const SizedBox(height: 16),

                // ── Pending NGO Approvals ────────────────────────
                _buildPendingNgos(stats, isLoading),
                const SizedBox(height: 16),

                // ── Recent Activity Feed ─────────────────────────
                _buildRecentActivity(stats, isLoading),

                // ── Low Stock Alert ──────────────────────────────
                if ((stats?.lowStockCount ?? 0) > 0) ...[
                  const SizedBox(height: 16),
                  _buildAlertCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.tertiary,
                    title: 'Low Stock Alerts',
                    subtitle: '${stats!.lowStockCount} NGO(s) need restocking',
                  ),
                ],
                const SizedBox(height: 16),
                _buildMiniMapCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section: Header ───────────────────────────────────────────
  Widget _buildHeader(AppColorSet colors) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Overview',
                    style: GoogleFonts.publicSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Super Admin',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  'Platform overview & management',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section: Stat Cards ───────────────────────────────────────
  Widget _buildStatCardsRow(AdminStats? stats, bool isLoading) {
    String fmtKg(double kg) => kg > 0 ? kg.toStringAsFixed(0) : '0';

    final cards = [
      _StatCardData(
        icon: Icons.volunteer_activism_outlined,
        label: 'Total Donors',
        value: isLoading ? '--' : '${stats?.donorsCount ?? 0}',
        tint: AppColors.primary,
        isPrimary: true,
      ),
      _StatCardData(
        icon: Icons.shield_outlined,
        label: 'Total NGOs',
        value: isLoading ? '--' : '${stats?.ngosCount ?? 0}',
        tint: AppColors.secondary,
      ),
      _StatCardData(
        icon: Icons.inventory_2_outlined,
        label: 'Total Donations',
        value: isLoading ? '--' : '${stats?.donationsCount ?? 0}',
        tint: const Color(0xFF4A90D9),
      ),
      _StatCardData(
        icon: Icons.people_outline,
        label: 'Active Volunteers',
        value: isLoading ? '--' : '${stats?.volunteersCount ?? 0}',
        tint: const Color(0xFF7C63D4),
      ),
      _StatCardData(
        icon: Icons.restaurant_outlined,
        label: 'Food Collected',
        value: isLoading ? '--' : '${fmtKg(stats?.foodCollectedKg ?? 0)} kg',
        tint: AppColors.tertiary,
      ),
      _StatCardData(
        icon: Icons.local_shipping_outlined,
        label: 'Food Distributed',
        value: isLoading ? '--' : '${fmtKg(stats?.foodDistributedKg ?? 0)} kg',
        tint: const Color(0xFF2E9E6A),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: cards.map((c) => _StatCard(data: c)).toList(),
    );
  }

  // ── Section: Beneficiaries Banner ─────────────────────────────
  Widget _buildBeneficiariesBanner(AdminStats? stats, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFF9A6C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.groups_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Beneficiaries',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoading ? '--' : '${stats?.totalBeneficiaries ?? 0}',
                  style: GoogleFonts.publicSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                Text(
                  'people supported',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if ((stats?.pendingNgosCount ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${stats!.pendingNgosCount} pending',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Section: Trends Chart ─────────────────────────────────────
  Widget _buildTrendsCard(AdminStats? stats, bool isLoading) {
    final colors = context.colors;
    final chartValues = stats?.chartValues ?? List.filled(12, 0.0);
    final hasData = chartValues.any((v) => v > 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Donation Trends',
                    style: GoogleFonts.publicSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    hasData ? 'Volume over past $_period' : 'No data yet',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Period filter tabs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: ['7D', '30D', '90D'].map((p) {
                    final isActive = p == _period;
                    return GestureDetector(
                      onTap: () => setState(() => _period = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Text(
                          p,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? Colors.white : colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isLoading)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else
            SizedBox(
              height: 120,
              child: CustomPaint(
                size: Size.infinite,
                painter: _AreaChartPainter(
                  chartValues,
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_period ago',
                style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
              ),
              Text(
                'Today',
                style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section: Pending NGO Approvals ────────────────────────────
  Widget _buildPendingNgos(AdminStats? stats, bool isLoading) {
    final colors = context.colors;
    final pending = stats?.pendingNgosList ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending NGO Approvals',
              style: GoogleFonts.publicSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (pending.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NgoApprovalScreen()),
                ),
                child: Text(
                  'View All →',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          _shimmerCard(colors)
        else if (pending.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 22),
                const SizedBox(width: 12),
                Text(
                  'No pending approvals',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: pending.asMap().entries.map((entry) {
                final i = entry.key;
                final ngo = entry.value;
                final isLast = i == pending.length - 1;
                return _PendingNgoRow(
                  uid: ngo['uid'] ?? '',
                  name: ngo['name'] ?? ngo['organizationName'] ?? 'NGO',
                  address: ngo['address'] ?? ngo['officialAddress'] ?? '',
                  isLast: isLast,
                  onApproveReject: () => setState(() {}),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ── Section: Recent Activity ──────────────────────────────────
  Widget _buildRecentActivity(AdminStats? stats, bool isLoading) {
    final colors = context.colors;
    final logistics = stats?.recentLogistics ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.publicSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          _shimmerCard(colors)
        else if (logistics.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'No recent donation activity yet.',
                style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: logistics.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isLast = i == logistics.length - 1;
                final isCompleted = (item['status'] == 'COMPLETED' || item['status'] == 'VERIFIED');
                return _ActivityRow(
                  title: item['title'] ?? 'Donation',
                  subtitle: item['subtitle'] ?? '',
                  amount: item['amount'] ?? '',
                  status: item['status'] ?? 'PENDING',
                  dotColor: isCompleted ? AppColors.secondary : AppColors.tertiary,
                  isLast: isLast,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ── Section: Alert Card ───────────────────────────────────────
  Widget _buildAlertCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
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
                      color: colors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shimmer placeholder ───────────────────────────────────────
  Widget _shimmerCard(AppColorSet colors) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }

  // ── Mini Map Card ─────────────────────────────────────────────
  Widget _buildMiniMapCard() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Map Tracking',
                style: GoogleFonts.publicSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => widget.onNavigate?.call(3),
                child: Text(
                  'Open full map →',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    options: const MapOptions(
                      initialCenter: ll.LatLng(19.0760, 72.8777),
                      initialZoom: 10.0,
                      interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                        userAgentPackageName: 'com.sahyog.app',
                      ),
                    ],
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onNavigate?.call(3),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Stat Card Data Model
// ─────────────────────────────────────────────────────────────────
class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final bool isPrimary;
  const _StatCardData({required this.icon, required this.label, required this.value, required this.tint, this.isPrimary = false});
}

// ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (data.isPrimary) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFFF8F5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: Colors.white, size: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style: GoogleFonts.publicSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.tint, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  style: GoogleFonts.publicSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
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

// ─────────────────────────────────────────────────────────────────
//  Pending NGO Row
// ─────────────────────────────────────────────────────────────────
class _PendingNgoRow extends StatelessWidget {
  final String uid;
  final String name;
  final String address;
  final bool isLast;
  final VoidCallback onApproveReject;

  const _PendingNgoRow({
    required this.uid,
    required this.name,
    required this.address,
    required this.isLast,
    required this.onApproveReject,
  });

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': status,
      });
      onApproveReject();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? '$name approved' : '$name rejected'),
            backgroundColor: status == 'approved' ? AppColors.secondary : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // NGO icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.secondary, size: 18),
              ),
              const SizedBox(width: 12),
              // Name + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Approve / Reject
              _ActionChip(
                label: 'Approve',
                color: AppColors.secondary,
                onTap: () => _updateStatus(context, 'approved'),
              ),
              const SizedBox(width: 6),
              _ActionChip(
                label: 'Reject',
                color: AppColors.error,
                onTap: () => _updateStatus(context, 'rejected'),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.5), indent: 16, endIndent: 16),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Activity Row (timeline style)
// ─────────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String status;
  final Color dotColor;
  final bool isLast;

  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.dotColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 16),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: dotColor.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12, bottom: isLast ? 16 : 0, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (amount.isNotEmpty)
                        Text(
                          amount,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: dotColor,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: dotColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (!isLast) const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
