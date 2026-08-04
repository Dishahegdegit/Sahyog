import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/ngo/donation_model.dart';
import '../../services/firestore_service.dart';

class DonationFeedScreen extends StatefulWidget {
  const DonationFeedScreen({super.key});

  @override
  State<DonationFeedScreen> createState() => _DonationFeedScreenState();
}

class _DonationFeedScreenState extends State<DonationFeedScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFoodType = 'All'; // 'All', 'Veg', 'Non-Veg'
  String _selectedUrgency = 'All';  // 'All', 'High', 'Medium'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _firestoreService.purgeDummyFoodDonations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DonationModel> _filterDonations(List<DonationModel> list) {
    return list.where((item) {
      // 1. Food Type Filter
      if (_selectedFoodType != 'All' &&
          item.foodType.toLowerCase() != _selectedFoodType.toLowerCase()) {
        return false;
      }
      // 2. Urgency Filter
      if (_selectedUrgency != 'All' &&
          item.urgency.toLowerCase() != _selectedUrgency.toLowerCase()) {
        return false;
      }
      // 3. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = item.foodTitle.toLowerCase().contains(query);
        final donorMatch = item.donorName.toLowerCase().contains(query);
        final locMatch = item.pickupLocation.toLowerCase().contains(query);
        if (!titleMatch && !donorMatch && !locMatch) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filter Header
            _buildSearchAndFilters(),

            // Donation Requests List
            Expanded(
              child: StreamBuilder<List<DonationModel>>(
                stream: _firestoreService.streamAvailableDonations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading donations. Please retry.',
                        style: GoogleFonts.publicSans(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  final allDonations = snapshot.data ?? [];
                  final filtered = _filterDonations(allDonations);

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildDonationCard(filtered[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SEARCH & FILTER HEADER ─────────────────────────────────────────────

  Widget _buildSearchAndFilters() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHighest, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Back Header
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid)
                .snapshots(),
            builder: (context, userSnap) {
              // Read name from users doc first
              String name = '';
              if (userSnap.hasData && userSnap.data!.exists) {
                final data = userSnap.data!.data() as Map<String, dynamic>;
                name = (data['name'] as String? ?? '').trim();
              }
              // Fallback to Firebase Auth displayName
              if (name.isEmpty) {
                name = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
              }

              final String welcomeText = name.isNotEmpty
                  ? 'Welcome back, $name!'
                  : 'Welcome back!';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      welcomeText,
                      style: GoogleFonts.publicSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discover and accept nearby food donations',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search Input Bar
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            style: GoogleFonts.publicSans(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search food type, location, or donor...',
              prefixIcon: const Icon(Icons.search, color: AppColors.outline),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.outline, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: AppColors.outline),
                const SizedBox(width: 8),
                Text(
                  'Filters:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),

                // Food Type Chips
                _buildFilterChip('Food: All', _selectedFoodType == 'All', () {
                  setState(() => _selectedFoodType = 'All');
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Veg Only', _selectedFoodType == 'Veg', () {
                  setState(() => _selectedFoodType = 'Veg');
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Non-Veg Only', _selectedFoodType == 'Non-Veg', () {
                  setState(() => _selectedFoodType = 'Non-Veg');
                }),
                const SizedBox(width: 12),

                // Urgency Chips
                _buildFilterChip('Urgency: All', _selectedUrgency == 'All', () {
                  setState(() => _selectedUrgency = 'All');
                }),
                const SizedBox(width: 6),
                _buildFilterChip('High Urgency', _selectedUrgency == 'High', () {
                  setState(() => _selectedUrgency = 'High');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── DONATION CARD WIDGET ───────────────────────────────────────────────

  Widget _buildDonationCard(DonationModel donation) {
    final bool isVeg = donation.foodType.toLowerCase() == 'veg';
    final DateFormat timeFormat = DateFormat('h:mm a');

    final String pickupStr = donation.pickupTime != null
        ? timeFormat.format(donation.pickupTime!)
        : 'Immediate';
    final String expiryStr = donation.expiryTime != null
        ? timeFormat.format(donation.expiryTime!)
        : 'In 4 hours';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: donation.urgency == 'High'
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.surfaceContainerHighest,
          width: donation.urgency == 'High' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Food Title & Veg/Non-Veg Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donation.foodTitle,
                        style: GoogleFonts.publicSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 14, color: AppColors.outline),
                          const SizedBox(width: 4),
                          Text(
                            donation.donorName,
                            style: GoogleFonts.publicSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Veg / Non-Veg Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVeg
                        ? const Color(0xFF1D514F)
                        : const Color(0xFF5D1900),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isVeg ? AppColors.secondary : AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isVeg ? const Color(0xFF9DD0CD) : const Color(0xFFFFB59D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        donation.foodType.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isVeg ? const Color(0xFF9DD0CD) : const Color(0xFFFFB59D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: AppColors.surfaceContainerHighest, height: 1),
            const SizedBox(height: 12),

            // Middle Grid Details: Quantity, Distance & Servings
            Row(
              children: [
                // Quantity & Servings
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, size: 18, color: AppColors.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${donation.quantity} (~${donation.servesCount} people)',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pickup Distance Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        donation.distance,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Pickup Location & Timings
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    donation.pickupLocation,
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: AppColors.outline),
                const SizedBox(width: 6),
                Text(
                  'Pickup: $pickupStr',
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.outline)),
                const SizedBox(width: 12),
                Text(
                  'Expires: $expiryStr',
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: donation.urgency == 'High' ? AppColors.error : AppColors.tertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card Action Bar: Urgency tag + View & Accept Button
            Row(
              children: [
                if (donation.urgency == 'High')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          'URGENT PICKUP',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Action Button
                ElevatedButton.icon(
                  onPressed: () => _openDonationDetailsSheet(donation),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('View & Accept'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(140, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── FULL DETAILS & ACCEPT MODAL SHEET ──────────────────────────────────

  void _openDonationDetailsSheet(DonationModel donation) {
    final bool isVeg = donation.foodType.toLowerCase() == 'veg';
    final DateFormat timeFormat = DateFormat('MMM d, h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Title & Type Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          donation.foodTitle,
                          style: GoogleFonts.publicSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isVeg ? const Color(0xFF1D514F) : const Color(0xFF5D1900),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          donation.foodType.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isVeg ? const Color(0xFF9DD0CD) : const Color(0xFFFFB59D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Offered by ${donation.donorName}',
                    style: GoogleFonts.publicSans(
                      fontSize: 15,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Showcase (if images exist)
                  if (donation.images.isNotEmpty) ...[
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: donation.images.length,
                        itemBuilder: (context, idx) {
                          return Container(
                            width: 260,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(donation.images[idx]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Details Grid Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceContainerHighest),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.inventory_2_outlined, 'Quantity', donation.quantity),
                        const Divider(color: AppColors.surfaceContainerHighest, height: 16),
                        _buildDetailRow(Icons.groups_outlined, 'Servings', '~${donation.servesCount} People'),
                        const Divider(color: AppColors.surfaceContainerHighest, height: 16),
                        _buildDetailRow(
                          Icons.location_on_outlined,
                          'Pickup Address',
                          '${donation.pickupLocation} (${donation.distance})',
                        ),
                        const Divider(color: AppColors.surfaceContainerHighest, height: 16),
                        _buildDetailRow(
                          Icons.phone_outlined,
                          'Donor Contact',
                          donation.donorPhone.isNotEmpty ? donation.donorPhone : 'Contact visible after accept',
                        ),
                        const Divider(color: AppColors.surfaceContainerHighest, height: 16),
                        _buildDetailRow(
                          Icons.schedule_outlined,
                          'Available Pickup',
                          donation.pickupTime != null
                              ? timeFormat.format(donation.pickupTime!)
                              : 'Immediate Pickup',
                        ),
                        const Divider(color: AppColors.surfaceContainerHighest, height: 16),
                        _buildDetailRow(
                          Icons.timer_outlined,
                          'Expiry Time',
                          donation.expiryTime != null
                              ? timeFormat.format(donation.expiryTime!)
                              : 'Within 4 Hours',
                          valueColor: donation.urgency == 'High' ? AppColors.error : AppColors.tertiary,
                        ),
                      ],
                    ),
                  ),

                  // Special Notes Section
                  if (donation.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Donor Notes',
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        donation.notes,
                        style: GoogleFonts.publicSans(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Accept Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final currentNgoId = FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';
                        const currentNgoName = 'Sahyog Relief Foundation';

                        await _firestoreService.acceptDonation(
                          donationId: donation.id,
                          ngoId: currentNgoId,
                          ngoName: currentNgoName,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.secondaryContainer,
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.secondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Donation Accepted! Added to Volunteer Assignment tab.',
                                      style: GoogleFonts.publicSans(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.handshake_outlined, size: 22),
                      label: Text(
                        'ACCEPT DONATION',
                        style: GoogleFonts.publicSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
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

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.outline),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── EMPTY STATE WIDGET ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerHigh,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(Icons.restaurant_outlined, size: 40, color: AppColors.outline),
            ),
            const SizedBox(height: 16),
            Text(
              'No Available Food Requests',
              style: GoogleFonts.publicSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back shortly for new food donations from nearby donors.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
