import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/donor/donation_model.dart';

class DonationDetailScreen extends StatelessWidget {
  final String donationId;

  const DonationDetailScreen({super.key, required this.donationId});

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
      case 'pending':
      default:
        return AppColors.statusPending;
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
        backgroundColor: Colors.white,
        title: const Text('Cancel Donation', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this donation request?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Donation Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('donations')
            .doc(donationId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Donation not found', style: TextStyle(color: AppColors.textPrimary)));
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
                    // Status Header Card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Logistics Status:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              donation.status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
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
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          donation.imageUrl,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    if (donation.imageUrl.isNotEmpty) const SizedBox(height: 24),

                    // Food Info Section
                    _buildSectionTitle('Food Information'),
                    _buildInfoRow(Icons.restaurant_menu, 'Type', donation.foodType),
                    _buildInfoRow(Icons.scale_outlined, 'Quantity', donation.foodQuantity),
                    _buildInfoRow(Icons.people_outline, 'Servings', '~${donation.servings} people'),
                    const SizedBox(height: 20),

                    // Pickup Info Section
                    _buildSectionTitle('Pickup Information'),
                    _buildInfoRow(Icons.location_on_outlined, 'Address', donation.pickupAddress),
                    _buildInfoRow(Icons.access_time, 'Pickup Window', donation.pickupTime),
                    _buildInfoRow(Icons.timer_outlined, 'Expiry Time', donation.expiryTime),
                    const SizedBox(height: 20),

                    if (donation.notes.isNotEmpty) ...[
                      _buildSectionTitle('Additional Notes'),
                      Text(donation.notes, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                      const SizedBox(height: 20),
                    ],

                    _buildSectionTitle('Timeline'),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Submitted On', _formatDate(donation.createdAt)),
                    
                    const SizedBox(height: 40),

                    // Cancel Action Button
                    if (donation.status.toLowerCase() == 'pending')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelDonation(context),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel Donation Request'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
