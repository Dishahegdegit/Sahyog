import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import 'donation_detail_screen.dart';

class DonationStatusScreen extends StatelessWidget {
  const DonationStatusScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted by ngo':
      case 'accepted':
        return AppColors.statusAccepted;
      case 'volunteer assigned':
      case 'in transit':
      case 'picked up':
        return AppColors.statusTransit;
      case 'delivered':
      case 'completed':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'request submitted':
      case 'submitted':
      case 'pending':
      default:
        return AppColors.statusPending;
    }
  }

  String _formatStatusLabel(String? status) {
    if (status == null || status.trim().isEmpty) {
      return 'Request Submitted';
    }
    final lower = status.trim().toLowerCase();
    if (lower == 'pending' || lower == 'submitted') {
      return 'Request Submitted';
    }
    if (lower == 'accepted') {
      return 'Accepted by NGO';
    }
    return status;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'N/A';
    }
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final c = context.colors;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          elevation: 0,
          title: const Text('Track Donations', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text('Please log in to view your donations.', style: TextStyle(color: c.textPrimary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Track Donations', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donorId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading donations: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No donations found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your submitted donations will appear here',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
          sortedDocs.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            DateTime aDate = aTime is Timestamp ? aTime.toDate() : DateTime.now();
            DateTime bDate = bTime is Timestamp ? bTime.toDate() : DateTime.now();
            return bDate.compareTo(aDate);
          });

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final doc = sortedDocs[index];
                  final data = doc.data();
                  final foodType = data['foodType'] ?? 'Veg';
                  final foodQuantity = data['foodQuantity'] ?? '';
                  final servings = data['servings']?.toString() ?? '0';
                  final pickupAddress = data['pickupAddress'] ?? '';
                  final pickupTime = data['pickupTime'] ?? '';
                  final rawStatus = data['status']?.toString();
                  final statusLabel = _formatStatusLabel(rawStatus);
                  final statusColor = _getStatusColor(statusLabel);
                  final formattedDate = _formatDate(data['createdAt']);
                  final foodTitle = (data['foodTitle'] as String?)?.trim().isNotEmpty == true
                      ? (data['foodTitle'] as String).trim()
                      : ((data['foodName'] as String?)?.trim().isNotEmpty == true
                          ? (data['foodName'] as String).trim()
                          : ((data['title'] as String?)?.trim().isNotEmpty == true
                              ? (data['title'] as String).trim()
                              : foodType));

                  final isVeg = foodType.toLowerCase() == 'veg';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
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
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DonationDetailScreen(donationId: doc.id),
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
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        isVeg ? Icons.eco : Icons.kebab_dining,
                                        color: isVeg ? Colors.green : AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          foodTitle,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: c.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    statusLabel.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Divider(color: c.borderLight, height: 24),

                            Row(
                              children: [
                                const Icon(Icons.scale_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Quantity: $foodQuantity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.people_outline, size: 18, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '$servings Servings',
                                  style: TextStyle(color: c.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pickupAddress.isNotEmpty ? pickupAddress : 'No address provided',
                                    style: TextStyle(color: c.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Pickup Time: $pickupTime',
                                  style: TextStyle(color: c.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Submitted: $formattedDate',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
