import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/donation_tracking.dart';
import '../../widgets/donor_notification_bell.dart';
import 'donation_detail_screen.dart';

class DonorDashboard extends StatefulWidget {
  final Function(int)? onTabChange;

  const DonorDashboard({super.key, this.onTabChange});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _donorStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _donationsStream;

  static const List<_CarouselSlideData> _carouselSlides = [
    _CarouselSlideData(
      imagePath: 'assets/images/carousel_1.png',
      slogan: 'Share surplus. Serve hope.',
    ),
    _CarouselSlideData(
      imagePath: 'assets/images/carousel_2.png',
      slogan: 'Every meal reaches someone in need.',
    ),
    _CarouselSlideData(
      imagePath: 'assets/images/carousel_3.png',
      slogan: 'Donate food. Build community.',
    ),
    _CarouselSlideData(
      imagePath: 'assets/images/carousel_4.png',
      slogan: 'From your kitchen to their plate.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Cache streams so rebuilds do not resubscribe and flicker the UI.
      _donorStream =
          FirebaseFirestore.instance.collection('donors').doc(uid).snapshots();
      _donationsStream = FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(user),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: r.pagePadding, vertical: 16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPersonalizedHero(user),
                        SizedBox(height: r.sectionGap),
                        // Isolated carousel — its setState no longer rebuilds the whole dashboard
                        const _DashboardCarousel(slides: _carouselSlides),
                        SizedBox(height: r.sectionGap),
                        _buildPrimaryCtaCard(context),
                        SizedBox(height: r.isCompact ? 20 : 28),
                        _buildDonationsContent(context, user?.uid ?? ''),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(User? user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _donorStream,
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        final r = Responsive.of(context);
        final iconSize = r.isCompact ? 36.0 : 42.0;

        return Container(
          width: double.infinity,
          height: r.isCompact ? 64 : 76,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: r.headerPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.volunteer_activism, color: Colors.white, size: r.isCompact ? 20 : 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sahyog',
                      style: TextStyle(
                        fontSize: r.isCompact ? 20 : 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: const CircleBorder(),
                    child: DonorNotificationBell(size: r.isCompact ? 20 : 22),
                  ),
                  SizedBox(width: r.isCompact ? 8 : 12),
                  Tooltip(
                    message: 'Donor Profile',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => widget.onTabChange?.call(3),
                        child: Container(
                          width: iconSize,
                          height: iconSize,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                            child: profileUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalizedHero(User? user) {
    final c = context.colors;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _donorStream,
      builder: (context, snapshot) {
        String donorName = 'Donor';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          donorName = data?['fullName'] ?? data?['name'] ?? 'Donor';
        } else if (user?.displayName != null && user!.displayName!.isNotEmpty) {
          donorName = user.displayName!;
        }

        final r = Responsive.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $donorName',
              style: TextStyle(
                fontSize: r.heroTitleSize,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              r.isCompact
                  ? 'Connecting surplus food to those in need'
                  : 'Connecting food to those in need • Collaboration for community impact',
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDonationsContent(BuildContext context, String uid) {
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _donationsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsSection(docs),
            const SizedBox(height: 28),
            _buildActiveDonationsSection(context, docs, isLoading: isLoading),
            const SizedBox(height: 28),
            _buildRecentHistorySection(context, docs),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryCtaCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.onTabChange != null) {
              widget.onTabChange!(1); // Switch to Donate tab
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(Responsive.of(context).isCompact ? 16.0 : 22.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Donate Surplus Food',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'TAP TO START A NEW FOOD DONATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final c = context.colors;
    int totalMeals = 0;
    int ngosHelped = 0;
    int peopleServed = 0;

    final Set<String> ngoSet = {};
    for (var doc in docs) {
      final data = doc.data();
      final servingsVal = data['servings'];
      final servings = servingsVal is int
          ? servingsVal
          : int.tryParse(servingsVal?.toString() ?? '0') ?? 0;

      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'completed' || status == 'delivered') {
        totalMeals += servings;
        peopleServed += servings;
      }

      final ngoName = data['ngoName'] as String?;
      if (ngoName != null &&
          ngoName.isNotEmpty &&
          ngoName != 'Not Assigned' &&
          ngoName != 'Unassigned') {
        ngoSet.add(ngoName);
      }
    }
    ngosHelped = ngoSet.length;

    return Column(
      children: [
        // Top KPI Card: TOTAL MEALS SHARED
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(Responsive.of(context).cardPadding),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL MEALS SHARED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: c.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$totalMeals',
                      style: TextStyle(
                        fontSize: Responsive.of(context).isCompact ? 28 : 32,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2-Column Metrics Cards
        ResponsiveRow(
          spacing: 12,
          breakpoint: 360,
          children: [
            _buildKpiCard(
              title: 'NGOS HELPED',
              value: '$ngosHelped',
              icon: Icons.domain_rounded,
              accentColor: AppColors.statusTransit,
            ),
            _buildKpiCard(
              title: 'PEOPLE SERVED',
              value: '$peopleServed',
              icon: Icons.people_alt_rounded,
              accentColor: AppColors.secondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: c.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 20, color: accentColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDonationsSection(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs, {
    bool isLoading = false,
  }) {
    final c = context.colors;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final activeDocs = allDocs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final foodQuantity = (data['foodQuantity'] ?? '').toString().trim();
      final servingsVal = data['servings'];
      final intServings = servingsVal is int
          ? servingsVal
          : int.tryParse(servingsVal?.toString() ?? '0') ?? 0;

      if (foodQuantity == '15box') return false;

      final isValidDonation = intServings > 0 || foodQuantity.isNotEmpty;

      return isValidDonation &&
          status != 'completed' &&
          status != 'delivered' &&
          status != 'cancelled';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Active Dispatch Tracker',
                style: TextStyle(
                  fontSize: Responsive.of(context).sectionTitleSize,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
                  onPressed: () {
                    if (widget.onTabChange != null) {
                      widget.onTabChange!(2); // History tab
                    }
                  },
                  child: Text(
                    'Live Track',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeDocs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.borderLight),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text(
                      'No active donations right now',
                      style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your surplus food to start tracking live progress!',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: activeDocs.map((doc) {
                  final data = doc.data();
                  final foodType = data['foodType'] as String? ?? 'Veg';
                  final foodName = (data['foodName'] as String?)?.trim().isNotEmpty == true
                      ? (data['foodName'] as String).trim()
                      : ((data['foodTitle'] as String?)?.trim().isNotEmpty == true
                          ? (data['foodTitle'] as String).trim()
                          : foodType);
                  final foodQuantity = data['foodQuantity'] as String? ?? '';
                  final servingsVal = data['servings'];
                  final servings = servingsVal is int
                      ? servingsVal
                      : int.tryParse(servingsVal?.toString() ?? '0') ?? 0;
                  final imageUrl = (data['imageUrl'] as String?)?.trim() ?? '';
                  final status = data['status'] as String? ?? 'Pending';
                  final shortId = '#SH-${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length).toUpperCase()}';
                  final volunteerName =
                      (data['assignedVolunteerName'] ?? data['volunteerName'] ?? '').toString();
                  final ngoName = data['ngoName'] as String?;

                  final step = DonationTracking.stepIndex(status);
                  final progressValue = DonationTracking.isCancelled(status)
                      ? 0.0
                      : ((step + 1) / DonationTracking.steps.length);
                  final statusColor = DonationTracking.statusColor(status);
                  String statusSubtext = DonationTracking.displayLabel(status);
                  if (DonationTracking.normalize(status) == 'accepted' &&
                      ngoName != null &&
                      ngoName.isNotEmpty) {
                    statusSubtext = 'Accepted by "$ngoName"';
                  } else if (DonationTracking.normalize(status) == 'volunteer_assigned' &&
                      volunteerName.isNotEmpty) {
                    statusSubtext = '$volunteerName assigned for pickup';
                  } else if (DonationTracking.normalize(status) == 'picked_up') {
                    statusSubtext = volunteerName.isNotEmpty
                        ? '$volunteerName picked up the donation'
                        : 'Food picked up';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.borderLight),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.03),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) => _buildFoodThumbFallback(),
                                    )
                                  : _buildFoodThumbFallback(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foodName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: c.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$foodType  •  ID: $shortId',
                                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (foodQuantity.isNotEmpty) 'Qty: $foodQuantity',
                                      if (servings > 0) 'Servings: $servings',
                                    ].join('  •  '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  tooltip: 'Delete Request',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) {
                                        final dc = dialogCtx.colors;
                                        return AlertDialog(
                                        backgroundColor: dc.surface,
                                        title: Text('Delete Donation Request', style: TextStyle(color: dc.textPrimary)),
                                        content: Text('Are you sure you want to remove this donation request?', style: TextStyle(color: dc.textSecondary)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                            child: Text('Cancel', style: TextStyle(color: dc.textSecondary)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                      },
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance.collection('donations').doc(doc.id).delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Donation request removed.')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Progress Step Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: AppColors.surfaceContainerLow,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.directions_bike_outlined, size: 14, color: statusColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusSubtext,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildRecentHistorySection(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    final c = context.colors;
    final historyDocs = allDocs.where((doc) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      return status.contains('accepted') || status == 'completed' || status == 'delivered';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent History',
                style: TextStyle(
                  fontSize: Responsive.of(context).sectionTitleSize,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
            ),
            if (historyDocs.isNotEmpty)
              TextButton(
                onPressed: () {
                  if (widget.onTabChange != null) {
                    widget.onTabChange!(2); // History tab
                  }
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (historyDocs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.borderLight),
            ),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 42, color: c.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  'No donation history yet',
                  style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accepted NGO requests and completed donations will appear here.',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )
        else
          Column(
            children: historyDocs.take(3).map((doc) {
              final data = doc.data();
              final foodType = data['foodType'] as String? ?? 'Veg';
              final foodName = (data['foodName'] as String?)?.trim().isNotEmpty == true
                  ? (data['foodName'] as String).trim()
                  : ((data['foodTitle'] as String?)?.trim().isNotEmpty == true
                      ? (data['foodTitle'] as String).trim()
                      : foodType);
              final foodQuantity = data['foodQuantity'] as String? ?? '';
              final servingsVal = data['servings'];
              final servings = servingsVal is int
                  ? servingsVal
                  : int.tryParse(servingsVal?.toString() ?? '0') ?? 0;
              final imageUrl = (data['imageUrl'] as String?)?.trim() ?? '';
              final status = data['status'] as String? ?? 'Completed';
              final ngoName = data['ngoName'] as String? ?? 'NGO Partner';
              final detailParts = <String>[
                foodType,
                'Assigned to: $ngoName',
                if (foodQuantity.isNotEmpty) 'Qty: $foodQuantity',
                if (servings > 0) 'Servings: $servings',
              ];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.borderLight),
                ),
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DonationDetailScreen(donationId: doc.id),
                        ),
                      );
                    },
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => _buildFoodThumbFallback(size: 44),
                            )
                          : _buildFoodThumbFallback(size: 44),
                    ),
                    title: Text(
                      foodName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      detailParts.join('  •  '),
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusDelivered.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusDelivered,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFoodThumbFallback({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(size > 44 ? 10 : 8),
      ),
      child: Icon(Icons.restaurant, color: AppColors.primary, size: size * 0.42),
    );
  }
}

/// Isolated carousel so auto-play setState does not rebuild the whole dashboard.
class _DashboardCarousel extends StatefulWidget {
  final List<_CarouselSlideData> slides;

  const _DashboardCarousel({required this.slides});

  @override
  State<_DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends State<_DashboardCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _goNext());
  }

  Future<void> _goNext() async {
    if (!mounted || !_controller.hasClients || widget.slides.isEmpty || _animating) {
      return;
    }
    _animating = true;
    final next = (_index + 1) % widget.slides.length;
    try {
      await _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    } catch (_) {
      // Ignore animation errors during dispose/rebuild.
    } finally {
      _animating = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = Responsive.of(context);
    return Column(
      children: [
        SizedBox(
          height: r.carouselHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) {
              if (_index != i) setState(() => _index = i);
            },
            itemBuilder: (context, index) {
              final slide = widget.slides[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.12),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        slide.imagePath,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.volunteer_activism, size: 54, color: Colors.white70),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.65),
                              ],
                            ),
                          ),
                          child: Text(
                            slide.slogan,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.slides.length, (i) {
            final isActive = _index == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isActive ? 24 : 8,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : c.borderLight,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CarouselSlideData {
  final String imagePath;
  final String slogan;

  const _CarouselSlideData({
    required this.imagePath,
    required this.slogan,
  });
}
