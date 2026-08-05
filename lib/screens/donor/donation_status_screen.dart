import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'donation_detail_screen.dart';

class DonationStatusScreen extends StatelessWidget {
  const DonationStatusScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted by ngo':
      case 'accepted':
        return Colors.blue;
      case 'volunteer assigned':
        return Colors.orange;
      case 'picked up':
        return Colors.purple;
      case 'delivered':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'request submitted':
      case 'submitted':
      case 'pending':
      default:
        return Colors.grey;
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
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Track Donations'),
        ),
        body: const Center(
          child: Text('Please log in to view your donations.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Donations'),
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
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No donations found',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your submitted donations will appear here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Sort documents client-side by createdAt descending to avoid missing Firestore index errors
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
              constraints: const BoxConstraints(maxWidth: 600),
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

                  final isVeg = foodType.toLowerCase() == 'veg';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Food Type & Status Chip
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isVeg ? Icons.eco : Icons.kebab_dining,
                                      color: isVeg ? Colors.green : Colors.redAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      foodType,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Chip(
                                  label: Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: statusColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Quantity & Servings
                            Row(
                              children: [
                                const Icon(Icons.scale_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Quantity: $foodQuantity',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.people_outline, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$servings Servings',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Address
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pickupAddress.isNotEmpty
                                        ? pickupAddress
                                        : 'No address provided',
                                    style: theme.textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Pickup Time
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Pickup Time: $pickupTime',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Footer: Created Date
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Submitted: $formattedDate',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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

