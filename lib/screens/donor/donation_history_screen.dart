import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/donor/donation_model.dart';
import 'donation_detail_screen.dart';

class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key});

  static const primaryOrange = Color(0xFFFF5E2B);
  static const darkCardBg = Color(0xFF222629);
  static const darkBorderColor = Color(0xFF2A2F33);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted by ngo':
      case 'accepted':
        return Colors.blueAccent;
      case 'volunteer assigned':
        return primaryOrange;
      case 'picked up':
        return const Color(0xFF00B8A9);
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: const Center(
          child: Text('Please log in to view your donation history.', style: TextStyle(color: Colors.white)),
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
                  // Universal Top App Bar
                  _buildTopAppBar(user),
                  const SizedBox(height: 24),

                  // Header Title Section
                  const Text(
                    'Donation History',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Review your past contributions, accepted requests, and completed donations.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9EA5AD),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Real Firestore Stream
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('donations')
                        .where('donorId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(color: primaryOrange),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Error loading donation history: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      final allDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                        snapshot.data?.docs ?? [],
                      );

                      // Filter accepted, completed, delivered, or cancelled records into History
                      final historyDocs = allDocs.where((doc) {
                        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
                        return status.contains('accepted') || status == 'completed' || status == 'delivered' || status == 'cancelled';
                      }).toList();

                      historyDocs.sort((a, b) {
                        final aTime = a.data()['createdAt'];
                        final bTime = b.data()['createdAt'];
                        if (aTime is Timestamp && bTime is Timestamp) {
                          return bTime.compareTo(aTime);
                        }
                        return 0;
                      });

                      if (historyDocs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: darkCardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: darkBorderColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.history, size: 54, color: primaryOrange),
                              SizedBox(height: 16),
                              Text(
                                'No donation history yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Accepted NGO requests and completed donations will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8C959E), fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: historyDocs.length,
                        itemBuilder: (context, index) {
                          final docData = historyDocs[index].data();
                          final docId = historyDocs[index].id;
                          final donation = DonationModel.fromMap(docData, docId);
                          final ngoName = docData['ngoName'] as String? ?? 'Not Assigned';
                          final statusColor = _getStatusColor(donation.status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            decoration: BoxDecoration(
                              color: darkCardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: darkBorderColor),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DonationDetailScreen(
                                      donationId: docId,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: primaryOrange.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.restaurant,
                                                size: 20,
                                                color: primaryOrange,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              donation.foodType,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Text(
                                            donation.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailTile(
                                            Icons.scale_outlined,
                                            'Quantity',
                                            donation.foodQuantity.isEmpty ? 'N/A' : donation.foodQuantity,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDetailTile(
                                            Icons.people_outline,
                                            'People Served',
                                            '~${donation.servings}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailTile(
                                            Icons.business_outlined,
                                            'NGO Name',
                                            ngoName,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDetailTile(
                                            Icons.calendar_today_outlined,
                                            'Donation Date',
                                            _formatDate(donation.createdAt),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(color: darkBorderColor, height: 24),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: const [
                                        Text(
                                          'View Details',
                                          style: TextStyle(
                                            color: primaryOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: primaryOrange,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('donors').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.volunteer_activism, color: primaryOrange, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Sahyog',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryOrange.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryOrange.withValues(alpha: 0.3),
                    backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                    child: profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8C959E)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8C959E)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
