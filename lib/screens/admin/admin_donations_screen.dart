import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/donor/donation_model.dart';
import 'package:intl/intl.dart';

class AdminDonationsScreen extends StatefulWidget {
  const AdminDonationsScreen({super.key});

  @override
  State<AdminDonationsScreen> createState() => _AdminDonationsScreenState();
}

class _AdminDonationsScreenState extends State<AdminDonationsScreen> {
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snapshot.data?.docs ?? [];
          final donations = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final title = (data['foodType'] ?? '').toString().toLowerCase();
            final address = (data['pickupAddress'] ?? '').toString().toLowerCase();
            
            final matchesStatus = _selectedStatus == 'all' || status == _selectedStatus;
            final matchesSearch = title.contains(_searchQuery.toLowerCase()) || 
                                 address.contains(_searchQuery.toLowerCase());
            
            return matchesStatus && matchesSearch;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donation Monitoring',
                          style: GoogleFonts.publicSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Track all platform donation activities',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Search Bar
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search donations or locations...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textHint),
                      prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'all', 'pending', 'accepted', 'completed', 'cancelled'
                    ].map((s) {
                      final isActive = _selectedStatus == s;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStatus = s),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isActive ? AppColors.primary : colors.outlineVariant),
                          ),
                          child: Text(
                            s.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.white : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                if (donations.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('No donations found', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: donations.length,
                    itemBuilder: (context, index) {
                      final doc = donations[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final donation = DonationModel.fromMap(data, doc.id);
                      return _DonationItemCard(donation: donation);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DonationItemCard extends StatelessWidget {
  final DonationModel donation;
  const _DonationItemCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color statusColor;
    IconData statusIcon;
    switch (donation.status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        statusColor = AppColors.secondary;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'accepted':
      case 'volunteer assigned':
      case 'picked up':
      case 'on delivery':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.tertiary;
        statusIcon = Icons.pending_actions_rounded;
    }

    final hasIssue = donation.notes.toLowerCase().contains('issue') || donation.notes.toLowerCase().contains('report');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasIssue ? AppColors.error.withValues(alpha: 0.5) : colors.outlineVariant.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasIssue ? AppColors.error : AppColors.primary).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donation.foodType,
                          style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 16, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        if (donation.createdAt != null)
                          Text(
                            DateFormat('MMM dd • hh:mm a').format(donation.createdAt!),
                            style: GoogleFonts.inter(fontSize: 12, color: colors.textHint),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          donation.status.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Info row (Quantity & Location)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.scale_rounded, size: 14, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Quantity', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${donation.foodQuantity}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 30, color: colors.outlineVariant),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.group_outlined, size: 14, color: colors.textSecondary),
                                const SizedBox(width: 4),
                                Text('Servings', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${donation.servings}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      donation.pickupAddress,
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              

              
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: colors.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 12, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Safety & Quality Guidelines Accepted by Donor',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
