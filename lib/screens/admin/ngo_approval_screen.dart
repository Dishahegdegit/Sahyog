import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/admin/ngo_approval_item.dart';
import '../../services/location_service.dart';
import '../../utils/page_limits.dart';

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
  String _selectedTab = 'pending';
  String _selectedRole = 'ngo'; // 'ngo' or 'donor'
  int _pageLimit = PageLimits.pageSize;

  Future<void> _approveUser(String uid, String role) async {
    final db = FirebaseFirestore.instance;
    final updateData = role == 'ngo'
        ? {'status': 'approved', 'verified': true}
        : {'verified': true, 'status': 'approved'};
    await db.collection('users').doc(uid).update(updateData);
    if (role == 'ngo') {
      try {
        await db.collection('ngos').doc(uid).set({'status': 'approved', 'verified': true}, SetOptions(merge: true));
      } catch (_) {}
    }
    
    // Send Notification
    await db.collection('notifications').add({
      'title': '${role.toUpperCase()} Approved',
      'body': 'Your account has been verified by the administrator.',
      'recipientId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'category': 'system',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar('${role.toUpperCase()} approved successfully', AppColors.secondary),
    );
  }

  Future<void> _rejectUser(String uid, String role) async {
    final db = FirebaseFirestore.instance;
    final updateData = role == 'ngo'
        ? {'status': 'rejected', 'verified': false}
        : {'verified': false, 'status': 'rejected'};
    await db.collection('users').doc(uid).update(updateData);
    if (role == 'ngo') {
      try {
        await db.collection('ngos').doc(uid).set({'status': 'rejected', 'verified': false}, SetOptions(merge: true));
      } catch (_) {}
    }

    // Send Notification
    await db.collection('notifications').add({
      'title': '${role.toUpperCase()} Rejected',
      'body': 'Your verification request was rejected. Please contact support for details.',
      'recipientId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'category': 'system',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar('${role.toUpperCase()} rejected', AppColors.error),
    );
  }

  Future<void> _markPendingUser(String uid, String role) async {
    final db = FirebaseFirestore.instance;
    final updateData = role == 'ngo'
        ? {'status': 'pending', 'verified': false}
        : {'verified': false, 'status': 'pending'};
    await db.collection('users').doc(uid).update(updateData);
    if (role == 'ngo') {
      try {
        await db.collection('ngos').doc(uid).set({'status': 'pending', 'verified': false}, SetOptions(merge: true));
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar('${role.toUpperCase()} marked as pending', AppColors.tertiary),
    );
  }

  SnackBar _snackBar(String msg, Color color) => SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: _selectedRole)
          .limit(_pageLimit)
          .snapshots(),
      builder: (context, snapshot) {
        final allItems = snapshot.data?.docs ?? [];

        final pending = allItems.where((d) {
          final data = d.data() as Map;
          if (_selectedRole == 'ngo') {
            return (data['status'] ?? 'pending') == 'pending';
          } else {
            return (data['verified'] ?? false) == false;
          }
        }).toList();

        final approved = allItems.where((d) {
          final data = d.data() as Map;
          if (_selectedRole == 'ngo') {
            return data['status'] == 'approved';
          } else {
            return data['verified'] == true;
          }
        }).toList();

        final rejected = allItems.where((d) {
          final data = d.data() as Map;
          if (_selectedRole == 'ngo') {
            return data['status'] == 'rejected';
          } else {
            return false; // Donors don't really have "rejected" status yet, just unverified
          }
        }).toList();

        final List<DocumentSnapshot> currentTabList;
        if (_selectedTab == 'approved') {
          currentTabList = approved;
        } else if (_selectedTab == 'rejected') {
          currentTabList = rejected;
        } else {
          currentTabList = pending;
        }

        final filteredItems = currentTabList.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
        }).toList();

        // Weekly trend
        List<double> weeklyBuckets = List.filled(7, 0.0);
        final now = DateTime.now();
        for (final doc in allItems) {
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

        final colors = context.colors;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 14),
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
              Text(
                'Approval Center',
                style: GoogleFonts.publicSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // ── Role Selector (NGO / Donor) ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildRoleTab('NGOs', 'ngo', colors),
                    _buildRoleTab('Donors', 'donor', colors),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Status Tabs ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip('Pending', pending.length, 'pending', AppColors.primary),
                    const SizedBox(width: 8),
                    _buildTabChip('Approved', approved.length, 'approved', AppColors.secondary),
                    if (_selectedRole == 'ngo') ...[
                      const SizedBox(width: 8),
                      _buildTabChip('Rejected', rejected.length, 'rejected', AppColors.error),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Search Bar ──
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textHint),
                    prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Items List ──
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (allItems.isEmpty)
                _EmptyStateForTab(_selectedTab)
              else ...[
                if (filteredItems.isNotEmpty) ...[
                  Column(
                    children: filteredItems.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final item = NgoApprovalItem.fromMap(data, doc.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NgoCard(
                          item: item,
                          role: _selectedRole,
                          onApprove: () => _approveUser(doc.id, _selectedRole),
                          onReject: () => _rejectUser(doc.id, _selectedRole),
                          onMarkPending: () => _markPendingUser(doc.id, _selectedRole),
                        ),
                      );
                    }).toList(),
                  ),
                  LoadMoreBar(
                    visibleCount: allItems.length,
                    limit: _pageLimit,
                    onLoadMore: () => setState(() => _pageLimit += PageLimits.pageSize),
                  ),
                ] else if (_searchQuery.isNotEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No results for "$_searchQuery"',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  ),
                ] else ...[
                  _EmptyStateForTab(_selectedTab),
                ],

                const SizedBox(height: 20),

                // ── Weekly Trend ──
                _WeeklyTrendSection(
                  trendValues: weeklyBuckets,
                  totalCount: allItems.length,
                  label: _selectedRole == 'ngo' ? 'NGO Registrations' : 'Donor Joins',
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleTab(String label, String value, AppColorSet colors) {
    final selected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedRole = value;
          _selectedTab = 'pending';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int count, String tabValue, Color activeColor) {
    final colors = context.colors;
    final isSelected = _selectedTab == tabValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : colors.outlineVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: GoogleFonts.publicSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? activeColor : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NGO Card
// ─────────────────────────────────────────────
class _NgoCard extends StatelessWidget {
  final NgoApprovalItem item;
  final String role;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMarkPending;

  const _NgoCard({
    required this.item,
    required this.role,
    required this.onApprove,
    required this.onReject,
    required this.onMarkPending,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool isNgo = role == 'ngo';
    Color statusColor;
    String statusText;

    if (isNgo) {
      switch (item.status.toLowerCase()) {
        case 'approved':
          statusColor = AppColors.secondary;
          statusText = 'APPROVED';
          break;
        case 'rejected':
          statusColor = AppColors.error;
          statusText = 'REJECTED';
          break;
        default:
          statusColor = AppColors.tertiary;
          statusText = 'PENDING';
      }
    } else {
      final bool isVerified = item.status == 'true' || item.status == 'approved';
      statusColor = isVerified ? AppColors.secondary : AppColors.tertiary;
      statusText = isVerified ? 'VERIFIED' : 'UNVERIFIED';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + Status
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Text(
                  item.initials,
                  style: GoogleFonts.publicSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
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
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.registrationId,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: colors.outlineVariant, height: 1),
          const SizedBox(height: 12),

          // Details
          if (item.address.isNotEmpty)
            _DetailRow(
                icon: Icons.location_on_outlined, text: LocationService.cleanAddress(item.address, fallbackName: 'Official NGO Address')),
          if (item.email.isNotEmpty)
            _DetailRow(icon: Icons.email_outlined, text: item.email),
          if (item.phone.isNotEmpty)
            _DetailRow(icon: Icons.phone_outlined, text: item.phone),

          const SizedBox(height: 14),

          // Action Buttons
          if (statusText == 'APPROVED' || statusText == 'VERIFIED')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onMarkPending,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isNgo ? 'Mark Pending' : 'Unverify',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                if (isNgo) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.15),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Reject NGO',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ],
              ],
            )
          else if (statusText == 'REJECTED')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onMarkPending,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Mark Pending',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Approve NGO',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                if (isNgo)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Reject',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                if (isNgo) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isNgo ? 'Approve' : 'Verify',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colors.textSecondary,
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
//  Weekly Trend Section
// ─────────────────────────────────────────────
class _WeeklyTrendSection extends StatelessWidget {
  final List<double> trendValues;
  final int totalCount;
  final String label;

  const _WeeklyTrendSection({
    required this.trendValues,
    required this.totalCount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasData = trendValues.any((v) => v > 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                '$totalCount total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasData ? 'Applications in last 7 days' : 'No activity in last 7 days',
            style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
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
                      fontSize: 10, color: colors.textSecondary)),
              Text('Today',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: colors.textSecondary)),
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
class _EmptyStateForTab extends StatelessWidget {
  final String tab;
  const _EmptyStateForTab(this.tab);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    IconData icon;
    String title;
    String subtitle;

    switch (tab) {
      case 'approved':
        icon = Icons.verified_user_outlined;
        title = 'No Approved NGOs';
        subtitle = 'Approved NGO applications will appear here.';
        break;
      case 'rejected':
        icon = Icons.gpp_bad_outlined;
        title = 'No Rejected NGOs';
        subtitle = 'Rejected applications will be stored here.';
        break;
      default:
        icon = Icons.verified_outlined;
        title = 'No Pending Approvals';
        subtitle = 'NGO applications will appear here once submitted.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon,
                size: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.publicSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                  fontSize: 13, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
