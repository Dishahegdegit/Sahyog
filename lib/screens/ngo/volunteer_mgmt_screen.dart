import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/donation_model.dart';
import '../../models/ngo/volunteer_model.dart';
import '../../services/firestore_service.dart';

import '../../utils/page_limits.dart';

class VolunteerMgmtScreen extends StatefulWidget {
  const VolunteerMgmtScreen({super.key});

  @override
  State<VolunteerMgmtScreen> createState() => _VolunteerMgmtScreenState();
}

class _VolunteerMgmtScreenState extends State<VolunteerMgmtScreen>
    with SingleTickerProviderStateMixin {
  NgoTheme get t => NgoTheme.of(context);

  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  final TextEditingController _volunteerSearchController = TextEditingController();
  String _volunteerStatusFilter = 'All';
  int _volunteerLimit = PageLimits.pageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _volunteerSearchController.dispose();
    super.dispose();
  }

  String get _currentNgoId => FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVolunteerDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Register Volunteer',
          style: GoogleFonts.publicSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Community Title / Heading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Community',
                  style: GoogleFonts.publicSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Manage your volunteers and assign food pickups',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                color: t.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tab Bar Container
          Container(
            color: t.surfaceContainerLow,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: t.textSecondary,
              labelStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'ASSIGN PICKUPS'),
                Tab(text: 'VOLUNTEER TEAM'),
              ],
            ),
          ),

          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Sub-Tab 1: Accepted Donations Needing Volunteer Assignment
                _buildAssignmentSection(),

                // Sub-Tab 2: Volunteer List & Search
                Column(
                  children: [
                    _buildVolunteerSearchBar(),
                    Expanded(child: _buildVolunteerListSection()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods for active pickup status actions

  Future<void> _resetVolunteerStatus(VolunteerModel vol, {DonationModel? donation}) async {
    try {
      final db = FirebaseFirestore.instance;
      // Update volunteer doc: set status to Available, delete assignedDonationId
      await db.collection('volunteers').doc(vol.id).update({
        'status': 'Available',
        'assignedDonationId': FieldValue.delete(),
      });

      // If the donation status is not 'Delivered' and is currently assigned to this volunteer, reset it back to 'Accepted'
      if (donation != null && donation.status != 'Delivered' && donation.assignedVolunteerId == vol.id) {
        await db.collection('donations').doc(donation.id).update({
          'status': 'Accepted',
          'assignedVolunteerId': FieldValue.delete(),
          'assignedVolunteerName': FieldValue.delete(),
          'assignedVolunteerPhone': FieldValue.delete(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1E1E),
            content: Text(
              'Volunteer ${vol.name} marked as Available!',
              style: GoogleFonts.publicSans(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update volunteer status: $e'),
          ),
        );
      }
    }
  }






  // ─── SUB-TAB 1: VOLUNTEER LIST SECTION ───────────────────────────────────

  Widget _buildVolunteerSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _volunteerSearchController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.publicSans(color: t.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search volunteers by name, phone, or area...',
              prefixIcon: Icon(Icons.search, color: t.outline),
              suffixIcon: _volunteerSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: t.outline, size: 20),
                      onPressed: () {
                        _volunteerSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: t.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.surfaceContainerHighest),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Available', 'On Delivery'].map((chip) {
                final selected = _volunteerStatusFilter == chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(chip),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: t.surfaceContainerLow,
                    labelStyle: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : t.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _volunteerStatusFilter = chip),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerListSection() {
    return StreamBuilder<List<VolunteerModel>>(
      stream: _firestoreService.streamVolunteers(_currentNgoId, limit: _volunteerLimit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final allVolunteers = snapshot.data ?? [];
        final volunteers = allVolunteers.where((vol) {
          final query = _volunteerSearchController.text.trim().toLowerCase();
          final matchesSearch = query.isEmpty ||
              vol.name.toLowerCase().contains(query) ||
              vol.phone.toLowerCase().contains(query) ||
              vol.email.toLowerCase().contains(query) ||
              vol.workingArea.toLowerCase().contains(query);
          final matchesStatus = _volunteerStatusFilter == 'All' ||
              vol.status.toLowerCase() == _volunteerStatusFilter.toLowerCase();
          return matchesSearch && matchesStatus;
        }).toList();

        if (allVolunteers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 48, color: t.outline),
                const SizedBox(height: 12),
                Text(
                  'No Volunteers Registered Yet',
                  style: GoogleFonts.publicSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the "+ Register Volunteer" button below to add your first member.',
                  style: GoogleFonts.publicSans(color: t.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        if (volunteers.isEmpty) {
          return Center(
            child: Text(
              'No volunteers match your search or filter.',
              style: GoogleFonts.publicSans(color: t.textSecondary, fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: volunteers.length + 1,
          itemBuilder: (context, index) {
            if (index == volunteers.length) {
              return LoadMoreBar(
                visibleCount: allVolunteers.length,
                limit: _volunteerLimit,
                onLoadMore: () => setState(() => _volunteerLimit += PageLimits.pageSize),
              );
            }
            final vol = volunteers[index];
            final bool isAvailable = vol.status.toLowerCase() == 'available';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: t.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: t.surfaceContainerHighest),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Volunteer Avatar
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isAvailable
                              ? t.secondary.withValues(alpha: 0.15)
                              : t.primary.withValues(alpha: 0.15),
                          child: Text(
                            vol.name.isNotEmpty ? vol.name[0].toUpperCase() : 'V',
                            style: GoogleFonts.publicSans(
                              fontWeight: FontWeight.w800,
                              color: isAvailable ? t.secondary : t.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vol.name,
                                style: GoogleFonts.publicSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 14, color: t.outline),
                                  const SizedBox(width: 4),
                                  Text(
                                    vol.phone,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Status Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? t.secondary.withValues(alpha: 0.12)
                                : t.tertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAvailable ? t.secondary : t.tertiary,
                            ),
                          ),
                          child: Text(
                            isAvailable ? 'Available' : 'On Delivery',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isAvailable ? t.secondary : t.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (!isAvailable && vol.assignedDonationId != null && vol.assignedDonationId!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(color: t.surfaceContainerHighest, height: 1),
                      const SizedBox(height: 12),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('donations').doc(vol.assignedDonationId).snapshots(),
                        builder: (context, donationSnap) {
                          if (!donationSnap.hasData || !donationSnap.data!.exists) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'No active donation record found',
                                  style: GoogleFonts.publicSans(fontSize: 12, color: t.textSecondary, fontStyle: FontStyle.italic),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _resetVolunteerStatus(vol),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Reset Available'),
                                ),
                              ],
                            );
                          }

                          final donationData = donationSnap.data!.data() as Map<String, dynamic>;
                          final donation = DonationModel.fromMap(donationData, donationSnap.data!.id);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 16, color: t.tertiary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Food: ${donation.foodTitle}',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: t.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      donation.status.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: t.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: t.outline),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pickup: ${donation.pickupLocation}',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12,
                                        color: t.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [

                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: t.primary, width: 1),
                                      foregroundColor: t.primary,
                                      minimumSize: const Size(100, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () => _resetVolunteerStatus(vol, donation: donation),
                                    icon: const Icon(Icons.undo, size: 14),
                                    label: const Text('Free Volunteer'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── SUB-TAB 2: ACCEPTED DONATIONS & ASSIGNMENT ──────────────────────────

  Widget _buildAssignmentSection() {
    return StreamBuilder<List<DonationModel>>(
      stream: _firestoreService.streamAcceptedDonations(_currentNgoId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final acceptedDonations = snapshot.data ?? [];

        if (acceptedDonations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt_outlined, size: 48, color: t.outline),
                  const SizedBox(height: 12),
                  Text(
                    'No Pending Volunteer Assignments',
                    style: GoogleFonts.publicSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Accept new food requests in the Feed tab to assign volunteers here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(color: t.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: acceptedDonations.length,
          itemBuilder: (context, index) {
            final donation = acceptedDonations[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              color: t.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: t.surfaceContainerHighest),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            donation.foodTitle,
                            style: GoogleFonts.publicSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACCEPTED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: t.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(Icons.storefront_outlined, size: 16, color: t.outline),
                        const SizedBox(width: 6),
                        Text(
                          'Donor: ${donation.donorName}',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: t.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            donation.pickupLocation,
                            style: GoogleFonts.publicSans(
                              fontSize: 13,
                              color: t.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Divider(color: t.surfaceContainerHighest, height: 1),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openAssignVolunteerModal(donation),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Assign Volunteer to Pickup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── ADD VOLUNTEER DIALOG ────────────────────────────────────────────────

  void _showAddVolunteerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final areaCtrl = TextEditingController(text: 'Downtown');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: t.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Register New Volunteer',
            style: GoogleFonts.publicSans(
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    style: GoogleFonts.publicSans(color: t.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Volunteer Full Name *',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.publicSans(color: t.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number *',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.publicSans(color: t.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: areaCtrl,
                    style: GoogleFonts.publicSans(color: t.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Working Area / Zone',
                      prefixIcon: Icon(Icons.map_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.publicSans(color: t.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newVol = VolunteerModel(
                    id: '',
                    ngoId: _currentNgoId,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    workingArea: areaCtrl.text.trim(),
                    status: 'Available',
                  );

                  await _firestoreService.addVolunteer(newVol);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1E1E1E),
                        content: Text(
                          'Volunteer "${nameCtrl.text}" registered successfully!',
                          style: GoogleFonts.publicSans(color: Colors.white),
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(110, 42)),
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  // ─── ASSIGN VOLUNTEER MODAL ──────────────────────────────────────────────

  void _openAssignVolunteerModal(DonationModel donation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<List<VolunteerModel>>(
          stream: _firestoreService.streamVolunteers(_currentNgoId, limit: 50),
          builder: (context, snapshot) {
            final allVolunteers = snapshot.data ?? [];
            final availableVolunteers = allVolunteers
                .where((v) => v.status.toLowerCase() == 'available')
                .toList();

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign Volunteer to Pickup',
                    style: GoogleFonts.publicSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Food: ${donation.foodTitle} (${donation.pickupLocation})',
                    style: GoogleFonts.publicSans(fontSize: 13, color: t.secondary),
                  ),
                  const SizedBox(height: 16),

                  if (availableVolunteers.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: t.tertiary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No available volunteers right now. Please register a volunteer first or wait for active deliveries to complete.',
                              style: GoogleFonts.publicSans(fontSize: 13, color: t.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Select an Available Volunteer (${availableVolunteers.length}):',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableVolunteers.length,
                        itemBuilder: (context, index) {
                          final vol = availableVolunteers[index];

                          return Card(
                            color: t.surfaceContainerHigh,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.person, color: Colors.white, size: 20),
                              ),
                              title: Text(
                                vol.name,
                                style: GoogleFonts.publicSans(
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${vol.phone} • Area: ${vol.workingArea}',
                                style: GoogleFonts.publicSans(fontSize: 12, color: t.textSecondary),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                onPressed: () async {
                                  final parentContext = this.context;
                                  // Pop the assignment modal sheet immediately so stream update doesn't flash empty state
                                  Navigator.pop(context);

                                  try {
                                    await _firestoreService.assignVolunteerToDonation(
                                      donationId: donation.id,
                                      volunteerId: vol.id,
                                      volunteerName: vol.name,
                                      volunteerPhone: vol.phone,
                                      donorId: donation.donorId,
                                    );

                                    if (parentContext.mounted) {
                                      ScaffoldMessenger.of(parentContext).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF1E1E1E),
                                          content: Text(
                                            'Assigned ${vol.name} to pickup! Status updated to "Volunteer Assigned".',
                                            style: GoogleFonts.publicSans(color: Colors.white),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (parentContext.mounted) {
                                      ScaffoldMessenger.of(parentContext).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.error,
                                          content: Text('Failed to assign volunteer: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Assign'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
