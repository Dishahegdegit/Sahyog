import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'donation_detail_screen.dart';
import 'donation_history_screen.dart';

class DonorDashboard extends StatefulWidget {
  final Function(int)? onTabChange;

  const DonorDashboard({super.key, this.onTabChange});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  static const primaryOrange = Color(0xFFFF5E2B);
  static const darkCardBg = Color(0xFF222629);
  static const darkBorderColor = Color(0xFF2A2F33);
  static const tealAccent = Color(0xFF00B8A9);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1D1F),
          title: const Text('Sahyog'),
        ),
        body: const Center(
          child: Text('Please log in to view dashboard.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Universal Top App Bar (Logo + App Name | Bell + Profile Avatar)
                  _buildUniversalTopBar(context, user),
                  const SizedBox(height: 24),

                  // Main Body Header Section (Welcome greeting & Subtitle)
                  _buildBodyHeader(user),
                  const SizedBox(height: 24),

                  // Hero Metric Card ("TOTAL MEALS SHARED") & 2-Column Grid
                  _buildMetricsSection(user.uid),
                  const SizedBox(height: 20),

                  // Primary Orange CTA Card ("Donate Surplus Food")
                  _buildPrimaryCtaCard(context),
                  const SizedBox(height: 28),

                  // Active Donations Section
                  _buildActiveDonationsSection(context, user.uid),
                  const SizedBox(height: 28),

                  // Recent History Section
                  _buildRecentHistorySection(context, user.uid),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top Row: Logo + App Name ("Sahyog") on left; Notification Bell + Profile Avatar on right
  Widget _buildUniversalTopBar(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Logo + App Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryOrange.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      color: primaryOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sahyog',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              // Right: Notification Bell + Profile Avatar
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No new notifications')),
                      );
                    },
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                    tooltip: 'Notifications',
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(3); // Switch to Profile tab
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryOrange.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: primaryOrange.withValues(alpha: 0.3),
                        backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                        child: profileUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white, size: 18)
                            : null,
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

  /// Page Body Header (Welcome title + Subtitle below the app bar)
  Widget _buildBodyHeader(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String donorName = user.displayName ?? '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null && data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
            donorName = data['fullName'];
          }
        }
        if (donorName.isEmpty && user.email != null) {
          donorName = user.email!.split('@').first;
        }
        if (donorName.isEmpty) donorName = 'Donor';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $donorName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your contributions directly reduce food waste and support local communities.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9EA5AD),
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Hero Card ("TOTAL MEALS SHARED") & 2-Column Stats from Real Firestore
  Widget _buildMetricsSection(String uid) {
    return StreamBuilder<QuerySnapshot>(
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
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final servings = data['servings'] is int
                  ? data['servings'] as int
                  : int.tryParse(data['servings']?.toString() ?? '0') ?? 0;
              final status = data['status']?.toString().toLowerCase() ?? '';
              if (status == 'completed' || status == 'delivered') {
                totalMeals += servings;
                peopleServed += servings;
              }
              final ngoName = data['ngoName'] as String?;
              if (ngoName != null && ngoName.isNotEmpty && ngoName != 'Not Assigned' && ngoName != 'Unassigned') {
                ngoSet.add(ngoName);
              }
            }
          }
          ngosHelped = ngoSet.length;
        }

        return Column(
          children: [
            // Top Hero Card: TOTAL MEALS SHARED
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: darkBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: primaryOrange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL MEALS SHARED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8C959E),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          totalMeals.toString(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2-Column Stats Row: NGOS HELPED & PEOPLE SERVED
            Row(
              children: [
                Expanded(
                  child: _buildSubStatCard(
                    'NGOS HELPED',
                    ngosHelped.toString(),
                    Icons.business_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSubStatCard(
                    'PEOPLE SERVED',
                    peopleServed.toString(),
                    Icons.people_outline,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryOrange, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C959E),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  /// Primary Orange CTA Card ("Donate Surplus Food") with Hover Effects
  Widget _buildPrimaryCtaCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onTabChange != null) {
            widget.onTabChange!(1); // Switch to Donate tab
          }
        },
        hoverColor: Colors.orangeAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryOrange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryOrange.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Donate Surplus Food',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'TAP TO START A NEW FOOD DONATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 32,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Active Donations Section with Live Tracking Indicator
  Widget _buildActiveDonationsSection(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryOrange));
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

          // Filter out legacy test entries like '15box'
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
                  'Active Donations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (widget.onTabChange != null) {
                      widget.onTabChange!(2); // Switch to History tab
                    }
                  },
                  child: const Text(
                    'Live Track',
                    style: TextStyle(
                      color: primaryOrange,
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
                  color: darkCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: darkBorderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: primaryOrange.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    const Text(
                      'No active donations right now',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Share your surplus food to start tracking live progress!',
                      style: TextStyle(color: Color(0xFF8C959E), fontSize: 12),
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

                  final lowerStatus = status.toLowerCase();
                  if (lowerStatus.contains('accepted')) {
                    progressValue = 0.50;
                    statusSubtext = ngoName != null && ngoName.isNotEmpty
                        ? 'Accepted by "$ngoName"'
                        : 'Accepted by NGO';
                  } else if (lowerStatus.contains('assigned') || lowerStatus.contains('transit') || lowerStatus.contains('picked')) {
                    progressValue = 0.75;
                    statusSubtext = volunteerName != null && volunteerName.isNotEmpty
                        ? '$volunteerName is in transit'
                        : 'Volunteer assigned for pickup';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: darkCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: darkBorderColor),
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
                                    color: primaryOrange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.restaurant, color: primaryOrange, size: 20),
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
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'ID: $shortId${foodQuantity.isNotEmpty ? ' • $foodQuantity' : ''}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF8C959E)),
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
                                    color: tealAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tealAccent),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: tealAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Delete Request',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        backgroundColor: darkCardBg,
                                        title: const Text('Delete Donation Request', style: TextStyle(color: Colors.white)),
                                        content: const Text('Are you sure you want to remove this donation request?', style: TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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

                        // Real Dynamic Status Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: const Color(0xFF1E2225),
                            valueColor: const AlwaysStoppedAnimation<Color>(tealAccent),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.directions_bike, size: 14, color: Color(0xFF8C959E)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusSubtext,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF8C959E)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

  /// Recent History Section from Real Firestore
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
            const Text(
              'Recent History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (historyDocs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: darkCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: darkBorderColor),
                ),
                child: const Text(
                  'No past donation history available yet.',
                  style: TextStyle(color: Color(0xFF8C959E), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Column(
                children: historyDocs.take(3).map((doc) {
                  final data = doc.data();
                  final foodType = data['foodType'] as String? ?? 'Veg';
                  final servings = data['servings']?.toString() ?? '0';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: darkCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: darkBorderColor),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restaurant, color: primaryOrange, size: 18),
                      ),
                      title: Text(
                        foodType,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      subtitle: const Text('COMPLETED', style: TextStyle(fontSize: 11, color: Color(0xFF8C959E))),
                      trailing: Text(
                        '+$servings Meals',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryOrange,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DonationDetailScreen(donationId: doc.id),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  if (widget.onTabChange != null) {
                    widget.onTabChange!(2); // Navigate to History
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DonationHistoryScreen(),
                      ),
                    );
                  }
                },
                child: const Text(
                  'VIEW FULL HISTORY',
                  style: TextStyle(
                    color: primaryOrange,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
