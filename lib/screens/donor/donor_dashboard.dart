import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import 'donation_detail_screen.dart';

class DonorDashboard extends StatefulWidget {
  final Function(int)? onTabChange;

  const DonorDashboard({super.key, this.onTabChange});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final PageController _carouselController = PageController();
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;
  bool _isCarouselHovered = false;

  final List<_CarouselSlideData> _carouselSlides = [
    _CarouselSlideData(imagePath: 'assets/images/carousel_1.png'),
    _CarouselSlideData(imagePath: 'assets/images/carousel_2.png'),
    _CarouselSlideData(imagePath: 'assets/images/carousel_3.png'),
    _CarouselSlideData(imagePath: 'assets/images/carousel_4.png'),
  ];

  @override
  void initState() {
    super.initState();
    _startCarouselAutoPlay();
  }

  void _startCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_isCarouselHovered) return;
      if (_carouselController.hasClients) {
        int currentIndex = _currentCarouselIndex;
        int nextSlide = (currentIndex + 1) % _carouselSlides.length;
        _carouselController.animateToPage(
          nextSlide,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Universal App Bar
                  _buildTopAppBar(user),
                  const SizedBox(height: 24),

                  // Hero Welcome & Impact Tagline
                  _buildPersonalizedHero(user),
                  const SizedBox(height: 20),

                  // Image Carousel Banner (Styled matching reference NGO dashboard)
                  _buildHeroCarousel(),
                  const SizedBox(height: 24),

                  // Primary Orange CTA Card ("Donate Surplus Food")
                  _buildPrimaryCtaCard(context),
                  const SizedBox(height: 28),

                  // Live KPI Metrics Dashboard (Firestore stream)
                  _buildMetricsSection(user?.uid ?? ''),
                  const SizedBox(height: 28),

                  // Active Dispatch / Donations Tracker
                  _buildActiveDonationsSection(context, user?.uid ?? ''),
                  const SizedBox(height: 28),

                  // Recent History Teaser
                  _buildRecentHistorySection(context, user?.uid ?? ''),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(User? user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user != null
          ? FirebaseFirestore.instance.collection('donors').doc(user.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sahyog',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                      child: profileUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 20)
                          : null,
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user != null
          ? FirebaseFirestore.instance.collection('donors').doc(user.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String donorName = 'Donor';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          donorName = data?['fullName'] ?? data?['name'] ?? 'Donor';
        } else if (user?.displayName != null && user!.displayName!.isNotEmpty) {
          donorName = user.displayName!;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $donorName',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connecting food to those in need • Collaboration for community impact',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemCount: _carouselSlides.length,
            itemBuilder: (context, index) {
              final slide = _carouselSlides[index];
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
                  child: Image.asset(
                    slide.imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
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
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_carouselSlides.length, (index) {
            final isActive = _currentCarouselIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isActive ? 24 : 8,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.borderLight,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
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
            padding: const EdgeInsets.all(22.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Donate Surplus Food',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'TAP TO START A NEW FOOD DONATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  Widget _buildMetricsSection(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalMeals = 0;
        int ngosHelped = 0;
        int peopleServed = 0;

        if (snapshot.hasData) {
          final Set<String> ngoSet = {};
          for (var doc in snapshot.data!.docs) {
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
        }

        return Column(
          children: [
            // Top KPI Card: TOTAL MEALS SHARED
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
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
                        const Text(
                          'TOTAL MEALS SHARED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$totalMeals',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
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
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'NGOS HELPED',
                    value: '$ngosHelped',
                    icon: Icons.domain_rounded,
                    accentColor: AppColors.statusTransit,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    title: 'PEOPLE SERVED',
                    value: '$peopleServed',
                    icon: Icons.people_alt_rounded,
                    accentColor: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 20, color: accentColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDonationsSection(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allDocs = snapshot.data?.docs ?? [];
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Dispatch Tracker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (widget.onTabChange != null) {
                      widget.onTabChange!(2); // History tab
                    }
                  },
                  child: const Text(
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    const Text(
                      'No active donations right now',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Share your surplus food to start tracking live progress!',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: activeDocs.map((doc) {
                  final data = doc.data();
                  final foodType = data['foodType'] as String? ?? 'Veg';
                  final foodQuantity = data['foodQuantity'] as String? ?? '';
                  final status = data['status'] as String? ?? 'Pending';
                  final shortId = '#SH-${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length).toUpperCase()}';
                  final volunteerName = data['volunteerName'] as String?;
                  final ngoName = data['ngoName'] as String?;

                  double progressValue = 0.25;
                  String statusSubtext = 'Awaiting NGO acceptance';
                  Color statusColor = AppColors.statusPending;

                  final lowerStatus = status.toLowerCase();
                  if (lowerStatus.contains('accepted')) {
                    progressValue = 0.50;
                    statusColor = AppColors.statusAccepted;
                    statusSubtext = ngoName != null && ngoName.isNotEmpty
                        ? 'Accepted by "$ngoName"'
                        : 'Accepted by NGO Partner';
                  } else if (lowerStatus.contains('assigned') || lowerStatus.contains('transit') || lowerStatus.contains('picked')) {
                    progressValue = 0.75;
                    statusColor = AppColors.statusTransit;
                    statusSubtext = volunteerName != null && volunteerName.isNotEmpty
                        ? '$volunteerName is in transit'
                        : 'Volunteer assigned for pickup';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foodType,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'ID: $shortId${foodQuantity.isNotEmpty ? ' • $foodQuantity' : ''}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  tooltip: 'Delete Request',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: const Text('Delete Donation Request', style: TextStyle(color: AppColors.textPrimary)),
                                        content: const Text('Are you sure you want to remove this donation request?', style: TextStyle(color: AppColors.textSecondary)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
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
                            Text(
                              statusSubtext,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
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
      },
    );
  }

  Widget _buildRecentHistorySection(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        );

        final historyDocs = allDocs.where((doc) {
          final status = (doc.data()['status'] ?? '').toString().toLowerCase();
          return status.contains('accepted') || status == 'completed' || status == 'delivered';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (historyDocs.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(2); // History tab
                      }
                    },
                    child: const Text(
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, size: 42, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    const Text(
                      'No donation history yet',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Accepted NGO requests and completed donations will appear here.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: historyDocs.take(3).map((doc) {
                  final data = doc.data();
                  final foodType = data['foodType'] as String? ?? 'Veg';
                  final foodQuantity = data['foodQuantity'] as String? ?? '';
                  final status = data['status'] as String? ?? 'Completed';
                  final ngoName = data['ngoName'] as String? ?? 'NGO Partner';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Material(
                      color: Colors.white,
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
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                        ),
                        title: Text(
                          foodType,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'Assigned to: $ngoName • $foodQuantity',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.statusDelivered.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
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
      },
    );
  }
}

class _CarouselSlideData {
  final String imagePath;

  _CarouselSlideData({
    required this.imagePath,
  });
}
