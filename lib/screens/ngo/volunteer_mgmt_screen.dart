import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/ngo/donation_model.dart';
import '../../models/ngo/volunteer_model.dart';
import '../../services/firestore_service.dart';

class VolunteerMgmtScreen extends StatefulWidget {
  const VolunteerMgmtScreen({super.key});

  @override
  State<VolunteerMgmtScreen> createState() => _VolunteerMgmtScreenState();
}

class _VolunteerMgmtScreenState extends State<VolunteerMgmtScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentNgoId => FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppColors.surfaceContainerLow,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'VOLUNTEER TEAM'),
              Tab(text: 'ASSIGN PICKUPS'),
            ],
          ),
        ),
      ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Sub-Tab 1: Registered Volunteers List
          _buildVolunteerListSection(),

          // Sub-Tab 2: Accepted Donations Needing Volunteer Assignment
          _buildAssignmentSection(),
        ],
      ),
    );
  }

  // ─── SUB-TAB 1: VOLUNTEER LIST SECTION ───────────────────────────────────

  Widget _buildVolunteerListSection() {
    return StreamBuilder<List<VolunteerModel>>(
      stream: _firestoreService.streamVolunteers(_currentNgoId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final volunteers = snapshot.data ?? [];

        if (volunteers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_outlined, size: 48, color: AppColors.outline),
                const SizedBox(height: 12),
                Text(
                  'No Volunteers Registered Yet',
                  style: GoogleFonts.publicSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the "+ Register Volunteer" button below to add your first member.',
                  style: GoogleFonts.publicSans(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: volunteers.length,
          itemBuilder: (context, index) {
            final vol = volunteers[index];
            final bool isAvailable = vol.status.toLowerCase() == 'available';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.surfaceContainerHighest),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Volunteer Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isAvailable
                          ? AppColors.secondaryContainer
                          : AppColors.primaryContainer,
                      child: Text(
                        vol.name.isNotEmpty ? vol.name[0].toUpperCase() : 'V',
                        style: GoogleFonts.publicSans(
                          fontWeight: FontWeight.w800,
                          color: isAvailable ? AppColors.secondary : Colors.white,
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppColors.outline),
                              const SizedBox(width: 4),
                              Text(
                                vol.phone,
                                style: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (vol.assignedDonationId != null &&
                              vol.assignedDonationId!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.tertiary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Pickup ID: ${vol.assignedDonationId}',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      color: AppColors.tertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFF1D514F)
                            : const Color(0xFFC49100).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAvailable ? AppColors.secondary : AppColors.tertiary,
                        ),
                      ),
                      child: Text(
                        isAvailable ? 'Available' : 'On Delivery',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAvailable ? AppColors.secondary : AppColors.tertiary,
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
                  const Icon(Icons.task_alt_outlined, size: 48, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text(
                    'No Pending Volunteer Assignments',
                    style: GoogleFonts.publicSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Accept new food requests in the Feed tab to assign volunteers here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(color: AppColors.textSecondary, fontSize: 13),
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
              color: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.surfaceContainerHighest),
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACCEPTED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 16, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Text(
                          'Donor: ${donation.donorName}',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.outline),
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

                    const SizedBox(height: 14),
                    const Divider(color: AppColors.surfaceContainerHighest, height: 1),
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
          backgroundColor: AppColors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Register New Volunteer',
            style: GoogleFonts.publicSans(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
                    style: GoogleFonts.publicSans(color: AppColors.textPrimary),
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
                    style: GoogleFonts.publicSans(color: AppColors.textPrimary),
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
                    style: GoogleFonts.publicSans(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: areaCtrl,
                    style: GoogleFonts.publicSans(color: AppColors.textPrimary),
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
                style: GoogleFonts.publicSans(color: AppColors.textSecondary),
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
                        backgroundColor: AppColors.secondaryContainer,
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
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<List<VolunteerModel>>(
          stream: _firestoreService.streamVolunteers(_currentNgoId),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Food: ${donation.foodTitle} (${donation.pickupLocation})',
                    style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 16),

                  if (availableVolunteers.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.tertiary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No available volunteers right now. Please register a volunteer first or wait for active deliveries to complete.',
                              style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Select an Available Volunteer:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
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
                            color: AppColors.surfaceContainerHigh,
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${vol.phone} • Area: ${vol.workingArea}',
                                style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.outline),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                onPressed: () async {
                                  await _firestoreService.assignVolunteerToDonation(
                                    donationId: donation.id,
                                    volunteerId: vol.id,
                                    volunteerName: vol.name,
                                    volunteerPhone: vol.phone,
                                    donorId: donation.donorId,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.secondaryContainer,
                                        content: Text(
                                          'Assigned ${vol.name} to pickup! Donation status updated to "Volunteer Assigned".',
                                          style: GoogleFonts.publicSans(color: Colors.white),
                                        ),
                                      ),
                                    );
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
