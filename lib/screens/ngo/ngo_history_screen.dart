import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/donation_model.dart';

class NgoHistoryScreen extends StatefulWidget {
  const NgoHistoryScreen({super.key});

  @override
  State<NgoHistoryScreen> createState() => _NgoHistoryScreenState();
}

class _NgoHistoryScreenState extends State<NgoHistoryScreen> {
  NgoTheme get t => NgoTheme.of(context);
  String get _currentNgoId => FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';

  String _statusFilter = 'All'; // 'All', 'Active', 'Delivered', 'Accepted', 'Volunteer Assigned'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Donated Food History',
          style: GoogleFonts.publicSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search & Filter Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: t.surfaceContainerHighest, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: GoogleFonts.publicSans(color: t.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by food, donor, location, volunteer...',
                    hintStyle: GoogleFonts.publicSans(color: t.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: t.outline, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: t.outline, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: t.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Active', 'Delivered', 'Accepted', 'Volunteer Assigned'].map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            status,
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : t.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: t.surfaceContainerHigh,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _statusFilter = status);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── History List View ──────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading history: ${snapshot.error}',
                      style: GoogleFonts.publicSans(color: AppColors.error),
                    ),
                  );
                }

                var docs = (snapshot.data?.docs ?? []).where((d) {
                  final data = d.data();
                  final ngoId = data['acceptedByNgoId'] ?? data['ngoId'] ?? data['requestedNgoId'];
                  return ngoId == _currentNgoId;
                }).toList();
                var donations = docs.map((d) => DonationModel.fromMap(d.data(), d.id)).toList();

                // Sort by createdAt descending
                donations.sort((a, b) {
                  final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return tB.compareTo(tA);
                });

                // Status Filtering
                if (_statusFilter == 'Active') {
                  donations = donations.where((d) => d.status == 'Accepted' || d.status == 'Volunteer Assigned' || d.status == 'Picked Up').toList();
                } else if (_statusFilter != 'All') {
                  donations = donations.where((d) => d.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
                }

                // Search Filtering
                if (_searchQuery.isNotEmpty) {
                  donations = donations.where((d) {
                    final title = d.foodTitle.toLowerCase();
                    final donor = d.donorName.toLowerCase();
                    final loc = d.pickupLocation.toLowerCase();
                    final vol = (d.assignedVolunteerName ?? '').toLowerCase();
                    return title.contains(_searchQuery) ||
                        donor.contains(_searchQuery) ||
                        loc.contains(_searchQuery) ||
                        vol.contains(_searchQuery);
                  }).toList();
                }

                if (donations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 64, color: t.outline),
                          const SizedBox(height: 16),
                          Text(
                            'No food donation records found',
                            style: GoogleFonts.publicSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusFilter != 'All' || _searchQuery.isNotEmpty
                                ? 'Try clearing filters or search queries'
                                : 'Accepted and completed donations will appear here',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.publicSans(fontSize: 13, color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: donations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final donation = donations[i];
                    return _buildHistoryCard(donation);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(DonationModel d) {
    Color statusColor = AppColors.primary;
    IconData statusIcon = Icons.pending_outlined;

    if (d.status == 'Delivered') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (d.status == 'Picked Up') {
      statusColor = Colors.blue;
      statusIcon = Icons.local_shipping_outlined;
    } else if (d.status == 'Volunteer Assigned') {
      statusColor = Colors.orange;
      statusIcon = Icons.person_outlined;
    } else if (d.status == 'Accepted') {
      statusColor = AppColors.primary;
      statusIcon = Icons.handshake_outlined;
    }

    final isVeg = d.foodType.toLowerCase().contains('veg') && !d.foodType.toLowerCase().contains('non');
    final dateStr = d.createdAt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(d.createdAt!) : 'Recent';

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDonationFullDetailsModal(d),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title, Veg Badge, Status
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isVeg ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.foodTitle,
                      style: GoogleFonts.publicSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          d.status,
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Details Grid
              Row(
                children: [
                  Expanded(
                    child: _buildDetailChip(
                      icon: Icons.scale_outlined,
                      label: 'Quantity',
                      value: d.quantity.isNotEmpty ? d.quantity : '${d.servesCount} Servings',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailChip(
                      icon: Icons.person_outline,
                      label: 'Donor',
                      value: d.donorName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: t.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pickup: ${d.pickupLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.publicSans(fontSize: 12, color: t.textSecondary),
                    ),
                  ),
                ],
              ),

              if (d.assignedVolunteerName != null && d.assignedVolunteerName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.directions_bike_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Volunteer: ${d.assignedVolunteerName}',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],

              if (d.deliveredAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Delivered on: ${DateFormat('MMM dd, yyyy • hh:mm a').format(d.deliveredAt!)}',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.publicSans(fontSize: 11, color: t.textSecondary),
                  ),
                  Row(
                    children: [
                      Text(
                        'View Full Details',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: t.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.publicSans(fontSize: 9, color: t.textSecondary)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: t.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDonationFullDetailsModal(DonationModel d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isVeg = d.foodType.toLowerCase().contains('veg') && !d.foodType.toLowerCase().contains('non');
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Title & Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.foodTitle,
                              style: GoogleFonts.publicSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: t.textPrimary,
                              ),
                            ),
                            Text(
                              'Donation ID: #${d.id.substring(0, d.id.length > 8 ? 8 : d.id.length)}',
                              style: GoogleFonts.publicSans(fontSize: 12, color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isVeg ? const Color(0xFF1D514F) : const Color(0xFF5D1900),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          d.foodType.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Metadata Cards
                  _buildSectionHeader('DONATION DETAILS'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Quantity / Portion', d.quantity.isNotEmpty ? d.quantity : '${d.servesCount} Servings'),
                  _buildInfoRow('Serves Count', '${d.servesCount} People'),
                  _buildInfoRow('Urgency Level', d.urgency),
                  if (d.pickupTime != null)
                    _buildInfoRow('Pickup Time', DateFormat('MMM dd, yyyy • hh:mm a').format(d.pickupTime!)),
                  if (d.expiryTime != null)
                    _buildInfoRow('Expiry Time', DateFormat('MMM dd, yyyy • hh:mm a').format(d.expiryTime!)),
                  if (d.notes.isNotEmpty) _buildInfoRow('Notes & Instructions', d.notes),

                  const SizedBox(height: 20),
                  _buildSectionHeader('DONOR & LOCATION'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Donor Name', d.donorName),
                  if (d.donorPhone.isNotEmpty) _buildInfoRow('Donor Phone', d.donorPhone),
                  _buildInfoRow('Pickup Address', d.pickupLocation),

                  const SizedBox(height: 20),
                  _buildSectionHeader('FULFILLMENT & VOLUNTEER'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Current Status', d.status),
                  _buildInfoRow('NGO Accepted By', d.acceptedByNgoName ?? 'Sahyog Relief'),
                  if (d.assignedVolunteerName != null) ...[
                    _buildInfoRow('Volunteer Name', d.assignedVolunteerName!),
                    if (d.assignedVolunteerPhone != null)
                      _buildInfoRow('Volunteer Contact', d.assignedVolunteerPhone!),
                  ],
                  if (d.foodDelivered != null) _buildInfoRow('Food Quantity Delivered', d.foodDelivered!),
                  if (d.beneficiariesServed != null)
                    _buildInfoRow('Beneficiaries Served', '${d.beneficiariesServed} People'),
                  if (d.deliveryLocation != null) _buildInfoRow('Delivery Drop Location', d.deliveryLocation!),
                  if (d.deliveredAt != null)
                    _buildInfoRow('Delivered Timestamp', DateFormat('MMM dd, yyyy • hh:mm a').format(d.deliveredAt!)),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'CLOSE DETAILS',
                        style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: GoogleFonts.publicSans(fontSize: 13, color: t.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700, color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
