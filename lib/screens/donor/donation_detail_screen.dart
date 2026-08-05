import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/donor/donation_model.dart';

class DonationDetailScreen extends StatelessWidget {
  final String donationId;

  const DonationDetailScreen({super.key, required this.donationId});

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
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'N/A';
    }
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  Future<void> _cancelDonation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Donation'),
        content: const Text('Are you sure you want to cancel this donation request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('donations')
            .doc(donationId)
            .update({'status': 'cancelled'});
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Donation cancelled successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel donation: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Details'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('donations')
            .doc(donationId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Donation not found'));
          }

          final data = snapshot.data!.data()!;
          final donation = DonationModel.fromMap(data, snapshot.data!.id);
          final statusColor = _getStatusColor(donation.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status:',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              donation.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Food Image (if available)
                    if (donation.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          donation.imageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    if (donation.imageUrl.isNotEmpty) const SizedBox(height: 24),

                    // Info Section
                    _buildSectionTitle(context, 'Food Information'),
                    _buildInfoRow(context, Icons.restaurant_menu, 'Type',
                        donation.foodType),
                    _buildInfoRow(context, Icons.scale_outlined, 'Quantity',
                        donation.foodQuantity),
                    _buildInfoRow(context, Icons.people_outline, 'Servings',
                        '~${donation.servings} people'),
                    const SizedBox(height: 16),

                    _buildSectionTitle(context, 'Pickup Information'),
                    _buildInfoRow(context, Icons.location_on_outlined,
                        'Address', donation.pickupAddress),
                    _buildInfoRow(context, Icons.access_time, 'Pickup Time',
                        donation.pickupTime),
                    _buildInfoRow(context, Icons.timer_outlined, 'Expiry Time',
                        donation.expiryTime),
                    const SizedBox(height: 16),

                    if (donation.notes.isNotEmpty) ...[
                      _buildSectionTitle(context, 'Additional Notes'),
                      Text(donation.notes, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                    ],

                    _buildSectionTitle(context, 'Timeline'),
                    _buildInfoRow(context, Icons.calendar_today_outlined,
                        'Submitted On', _formatDate(donation.createdAt)),
                    
                    const SizedBox(height: 40),

                    // Actions
                    if (donation.status.toLowerCase() == 'pending')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelDonation(context),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel Donation Request'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
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
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
