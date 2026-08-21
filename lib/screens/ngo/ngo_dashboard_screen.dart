import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/donation_model.dart';
import '../../models/ngo/volunteer_model.dart';
import '../../services/firestore_service.dart';


class NgoDashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const NgoDashboardScreen({super.key, required this.onTabChange});

  @override
  State<NgoDashboardScreen> createState() => _NgoDashboardScreenState();
}

class _NgoDashboardScreenState extends State<NgoDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final PageController _pageController;
  late final Timer _carouselTimer;
  int _activeSlide = 0;

  final List<Map<String, String>> _carouselData = [
    {
      'image': 'assets/images/ngo_carousel_1.jpg',
      'title': 'A Helping Hand',
      'subtitle': 'Together we end hunger, one meal at a time.',
    },
    {
      'image': 'assets/images/ngo_carousel_2.jpg',
      'title': 'Share & Care',
      'subtitle': 'Empowering local heroes, one donation at a time.',
    },
    {
      'image': 'assets/images/ngo_carousel_3.jpg',
      'title': 'Lives Transformed',
      'subtitle': 'A simple act of giving changes everything.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int next = _activeSlide + 1;
        if (next >= _carouselData.length) {
          next = 0;
        }
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String get _currentNgoId => FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';

  @override
  Widget build(BuildContext context) {
    final t = NgoTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Overview',
                  style: GoogleFonts.publicSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'NGO dashboard & donation tracker overview',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                color: t.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Carousel
          _buildCarouselSection(t),
          const SizedBox(height: 16),

          // Stats Grid
          _buildStatsCards(t),
          const SizedBox(height: 24),

          // Map Card
          _buildMapCard(t),
          const SizedBox(height: 24),

          // Top Volunteers This Week
          _buildTopVolunteers(t),
          const SizedBox(height: 24),

          // Donation Trend Graph
          _buildDonationTrendGraph(t),
          const SizedBox(height: 24),

          // Available Donations Nearby
          _buildAvailableDonationsNearby(t),
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  // ─── CAROUSEL SECTION ────────────────────────────────────────────────────

  Widget _buildCarouselSection(NgoTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() {
                  _activeSlide = idx;
                });
              },
              itemCount: _carouselData.length,
              itemBuilder: (context, idx) {
                final slide = _carouselData[idx];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: AssetImage(slide['image']!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.38),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Slide badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            slide['title']!,
                            style: GoogleFonts.publicSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slide['subtitle']!,
                          style: GoogleFonts.publicSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _carouselData.length,
              (index) => Container(
                width: _activeSlide == index ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _activeSlide == index ? AppColors.primary : t.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS CARDS ─────────────────────────────────────────────────────────

  Widget _buildStatsCards(NgoTheme t) {
    return StreamBuilder<List<DonationModel>>(
      stream: FirebaseFirestore.instance.collection('donations').snapshots().map((snap) =>
          snap.docs.map((doc) => DonationModel.fromMap(doc.data(), doc.id)).toList()),
      builder: (context, donationSnap) {
        return StreamBuilder<List<VolunteerModel>>(
          stream: FirebaseFirestore.instance.collection('volunteers').snapshots().map((snap) =>
              snap.docs.map((doc) => VolunteerModel.fromMap(doc.data(), doc.id)).toList()),
          builder: (context, volunteerSnap) {
            final allDonations = donationSnap.data ?? [];
            final allVolunteers = volunteerSnap.data ?? [];

            // ── This NGO's donations ──────────────────────────────────────
            final myDonations = allDonations
                .where((d) => d.acceptedByNgoId == _currentNgoId)
                .toList();

            // 1. Total Donations Received (ever accepted by this NGO)
            final totalReceived = myDonations.length;

            // 2. Active Donations (in-progress: Accepted / Volunteer Assigned / Picked Up)
            final activeCount = myDonations.where((d) =>
                d.status == 'Accepted' ||
                d.status == 'Volunteer Assigned' ||
                d.status == 'Picked Up').length;

            // 3. Completed Donations (Delivered)
            final completedCount =
                myDonations.where((d) => d.status == 'Delivered').length;

            // 4. Total Food Distributed (sum of servesCount for delivered donations)
            int foodDistributed = 0;
            for (final d in myDonations.where((d) => d.status == 'Delivered')) {
              foodDistributed += d.servesCount;
            }

            // 5. People Served (sum of beneficiariesServed recorded in delivery dialog)
            int peopleServed = 0;
            for (final d in myDonations.where((d) => d.status == 'Delivered')) {
              peopleServed += d.beneficiariesServed ?? 0;
            }

            // 6. Volunteers registered to this NGO
            final volsCount =
                allVolunteers.where((v) => v.ngoId == _currentNgoId).length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Row 1 — Total Received (accent) + Active
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          t: t,
                          count: totalReceived.toString(),
                          label: 'Total\nReceived',
                          icon: Icons.inventory_2_outlined,
                          accentColor: AppColors.primary,
                          onTap: () => widget.onTabChange(1),
                          isOrangeCard: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          t: t,
                          count: activeCount.toString(),
                          label: 'Active\nDonations',
                          icon: Icons.restaurant_menu_outlined,
                          accentColor: AppColors.primary,
                          onTap: () => widget.onTabChange(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2 — Completed + Food Distributed
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          t: t,
                          count: completedCount.toString(),
                          label: 'Completed\nDeliveries',
                          icon: Icons.check_circle_outline,
                          accentColor: AppColors.primary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          t: t,
                          count: foodDistributed.toString(),
                          label: 'Food\nDistributed',
                          icon: Icons.fastfood_outlined,
                          accentColor: AppColors.primary,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 3 — People Served + Volunteers
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          t: t,
                          count: peopleServed.toString(),
                          label: 'People\nServed',
                          icon: Icons.volunteer_activism_outlined,
                          accentColor: AppColors.primary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          t: t,
                          count: volsCount.toString(),
                          label: 'Volunteers',
                          icon: Icons.people_outline,
                          accentColor: AppColors.primary,
                          onTap: () => widget.onTabChange(3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required NgoTheme t,
    required String count,
    required String label,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isOrangeCard = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isOrangeCard ? AppColors.primary : t.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOrangeCard ? AppColors.primary : t.surfaceContainerHighest,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isOrangeCard ? Colors.white24 : accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isOrangeCard ? Colors.white : accentColor, size: 18),
                ),
                Text(
                  count,
                  style: GoogleFonts.publicSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isOrangeCard ? Colors.white : t.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isOrangeCard ? Colors.white : t.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 28,
              decoration: BoxDecoration(
                color: isOrangeCard ? Colors.white : accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AVAILABLE DONATIONS NEARBY (HORIZONTAL) ──────────────────────────────

  Widget _buildAvailableDonationsNearby(NgoTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Donations Nearby',
                style: GoogleFonts.publicSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => widget.onTabChange(2), // Go to Requests Feed
                child: Text(
                  'View All',
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: StreamBuilder<List<DonationModel>>(
            stream: _firestoreService.streamAvailableDonations(limit: 50),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final list = snapshot.data ?? [];

              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No nearby donations available right now.',
                      style: GoogleFonts.publicSans(color: t.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final donation = list[index];
                  final String displayImage = donation.images.isNotEmpty
                      ? donation.images.first
                      : 'assets/images/donation_placeholder.jpg';

                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.surfaceContainerHighest),
                      boxShadow: [
                        BoxShadow(
                          color: t.surfaceContainerHighest.withValues(alpha: 0.8),
                          blurRadius: 4,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Image with Badge
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: displayImage.startsWith('http')
                                  ? Image.network(
                                      displayImage,
                                      height: 90,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      displayImage,
                                      height: 90,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: t.surfaceContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Food details
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. ${donation.foodTitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                donation.donorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.scale_outlined, size: 12, color: t.outline),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      donation.quantity,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: t.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 2),
                                  Text(
                                    donation.distance.isNotEmpty ? donation.distance : '',  // show real distance only
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Accept Button — uses real NGO name from outer stream
                              GestureDetector(
                                onTap: () async {
                                  // Resolve current NGO name from Firestore at time of tap
                                  String resolvedNgoName = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
                                  try {
                                    final snap = await FirebaseFirestore.instance
                                        .collection('ngos')
                                        .doc(_currentNgoId)
                                        .get();
                                    if (snap.exists) {
                                      resolvedNgoName = (snap.data()?['name'] as String? ?? '').trim();
                                    }
                                  } catch (_) {}

                                  await _firestoreService.acceptDonation(
                                    donationId: donation.id,
                                    ngoId: _currentNgoId,
                                    ngoName: resolvedNgoName,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.primary,
                                        content: Text(
                                          '"${donation.foodTitle}" accepted!',
                                          style: GoogleFonts.publicSans(color: Colors.white),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Accept',
                                    style: GoogleFonts.publicSans(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── MAP CARD ─────────────────────────────────────────────────────────────

  Widget _buildMapCard(NgoTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Map Card',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => widget.onTabChange(1), // Go to Map tab
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.surfaceContainerHighest),
                image: const DecorationImage(
                  image: AssetImage('assets/images/onboarding_3.jpg'), // Placeholder background
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    AppColors.surfaceContainerHighest,
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // Mock drawing of map/roads
                  CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: MapRoadPainter(),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.surfaceContainerLow.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: t.textPrimary.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        'Pickup Locations',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
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

  // ─── TOP VOLUNTEERS ──────────────────────────────────────────────────────

  Widget _buildTopVolunteers(NgoTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Volunteers This Week',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: StreamBuilder<List<VolunteerModel>>(
              stream: _firestoreService.streamVolunteers(_currentNgoId, limit: 50),
              builder: (context, snapshot) {
                final volsList = snapshot.data ?? [];

                if (volsList.isEmpty) {
                  return Center(
                    child: Text(
                      'No volunteers registered yet.',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: volsList.length,
                  itemBuilder: (context, idx) {
                    final vol = volsList[idx];
                    return Container(
                      width: 75,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                child: Text(
                                  vol.name.isNotEmpty ? vol.name[0] : 'V',
                                  style: GoogleFonts.publicSans(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: AppColors.onPrimary,
                                  size: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            vol.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── DONATION TREND GRAPH ────────────────────────────────────────────────

  Widget _buildDonationTrendGraph(NgoTheme t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donation Activity',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly pickup trend',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            decoration: BoxDecoration(
              color: t.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    size: const Size(double.infinity, 100),
                    painter: TrendLinePainter(),
                  ),
                ),
                const SizedBox(height: 8),
                // Day labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: days
                      .map((d) => Text(
                            d,
                            style: GoogleFonts.publicSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw roads on the mock Map Card
class MapRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Background road lines
    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.lineTo(size.width * 0.4, size.height * 0.2);
    path.lineTo(size.width * 0.6, size.height * 0.8);
    path.lineTo(size.width, size.height * 0.8);

    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.3, size.height);

    path.moveTo(size.width * 0.7, 0);
    path.lineTo(size.width * 0.7, size.height);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, roadPaint);

    // Draw some pin points
    final pinPaintGreen = Paint()..color = AppColors.secondary;
    final pinPaintRed = Paint()..color = AppColors.primary;
    final pinPaintYellow = Paint()..color = AppColors.tertiary;

    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.2), 6, pinPaintRed);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 5, pinPaintGreen);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 5, pinPaintYellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter to draw the smooth trend line wave
class TrendLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Fill gradient under curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Trend line in primary brand colour
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.82);
    path.cubicTo(
      size.width * 0.15, size.height * 0.82,
      size.width * 0.28, size.height * 0.20,
      size.width * 0.42, size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.56, size.height * 0.88,
      size.width * 0.72, size.height * 0.10,
      size.width,       size.height * 0.10,
    );

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Data point dots on the curve
    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final dotWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final points = [
      Offset(0, size.height * 0.82),
      Offset(size.width * 0.16, size.height * 0.50),
      Offset(size.width * 0.33, size.height * 0.25),
      Offset(size.width * 0.50, size.height * 0.58),
      Offset(size.width * 0.67, size.height * 0.75),
      Offset(size.width * 0.83, size.height * 0.18),
      Offset(size.width,       size.height * 0.10),
    ];
    for (final pt in points) {
      canvas.drawCircle(pt, 5, dotPaint);
      canvas.drawCircle(pt, 3, dotWhite);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
