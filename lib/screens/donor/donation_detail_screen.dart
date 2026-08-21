import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/donor/donation_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/donation_tracking.dart';
import '../../widgets/donor_donation_timeline.dart';
import '../../services/ticket_service.dart';

class DonationDetailScreen extends StatelessWidget {
  final String donationId;

  const DonationDetailScreen({super.key, required this.donationId});

  Color _getStatusColor(String status) => DonationTracking.statusColor(status);

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
      builder: (context) {
        final c = context.colors;
        return AlertDialog(
        backgroundColor: c.surface,
        title: Text('Cancel Donation', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this donation request?', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      );
      },
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

  Future<void> _reportIssue(BuildContext context) async {
    final subject = TextEditingController(text: 'Issue with donation $donationId');
    final details = TextEditingController();
    final c = context.colors;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Report an issue', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: details,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'What went wrong?'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit ticket'),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) return;
    try {
      await TicketService.createTicket(
        subject: subject.text.trim().isEmpty ? 'Donation issue' : subject.text.trim(),
        description: details.text.trim().isEmpty ? 'No details provided.' : details.text.trim(),
        donationId: donationId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket submitted. An admin will review it.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit ticket: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Donation Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .doc(donationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Donation not found', style: TextStyle(color: c.textPrimary)));
          }

          final data = snapshot.data!.data()!;
          final donation = DonationModel.fromMap(data, snapshot.data!.id);
          final statusColor = _getStatusColor(donation.status);
          final volunteerName = (data['assignedVolunteerName'] ?? data['volunteerName'] ?? '').toString();
          final volunteerPhone = (data['assignedVolunteerPhone'] ?? data['volunteerPhone'] ?? '').toString();
          final ngoName = (donation.ngoName ?? data['acceptedByNgoName'] ?? '').toString();

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
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderLight),
                        boxShadow: const [
                          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Logistics Status:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              DonationTracking.displayLabel(donation.status).toUpperCase(),
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

                    _buildSectionTitle('Tracking Timeline'),
                    DonorDonationTimeline(status: donation.status),
                    const SizedBox(height: 16),
                    _buildPickupDeliveryCards(c, donation.status),
                    const SizedBox(height: 24),
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
                    _buildInfoRow(c, Icons.restaurant_menu, 'Type', donation.foodType),
                    _buildInfoRow(c, Icons.scale_outlined, 'Quantity', donation.foodQuantity),
                    _buildInfoRow(c, Icons.people_outline, 'Servings', '~${donation.servings} people'),
                    const SizedBox(height: 20),

                    // Pickup Info Section
                    _buildSectionTitle('Pickup Information'),
                    _buildInfoRow(c, Icons.location_on_outlined, 'Address', donation.pickupAddress),
                    _buildInfoRow(c, Icons.access_time, 'Pickup Window', donation.pickupTime),
                    _buildInfoRow(c, Icons.timer_outlined, 'Expiry Time', donation.expiryTime),
                    if (ngoName.isNotEmpty && ngoName != 'Unassigned')
                      _buildInfoRow(c, Icons.business_outlined, 'NGO Partner', ngoName),
                    if (volunteerName.isNotEmpty)
                      _buildInfoRow(c, Icons.badge_outlined, 'Volunteer', volunteerName),
                    if (volunteerPhone.isNotEmpty)
                      _buildInfoRow(c, Icons.phone_outlined, 'Volunteer Phone', volunteerPhone),
                    const SizedBox(height: 20),

                    if (donation.notes.isNotEmpty) ...[
                      _buildSectionTitle('Additional Notes'),
                      Text(donation.notes, style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.4)),
                      const SizedBox(height: 20),
                    ],

                    _buildSectionTitle('Submitted'),
                    _buildInfoRow(c, Icons.calendar_today_outlined, 'Submitted On', _formatDate(donation.createdAt)),
                    
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _reportIssue(context),
                        icon: const Icon(Icons.report_gmailerrorred_outlined),
                        label: const Text('Report an issue'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cancel Action Button
                    if (DonationTracking.normalize(donation.status) == 'submitted')
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

  Widget _buildPickupDeliveryCards(AppColorSet c, String status) {
    return Row(
      children: [
        Expanded(
          child: _statusMiniCard(
            c,
            'Pickup Status',
            DonationTracking.pickupStatus(status),
            DonationTracking.pickupColor(status),
            Icons.local_shipping_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusMiniCard(
            c,
            'Delivery Status',
            DonationTracking.deliveryStatus(status),
            DonationTracking.deliveryColor(status),
            Icons.volunteer_activism_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statusMiniCard(
    AppColorSet c,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(AppColorSet c, IconData icon, String label, String value) {
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
                Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
