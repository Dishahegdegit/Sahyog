import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/donation_model.dart';

class PickupDetailsScreen extends StatefulWidget {
  final String donationId;
  const PickupDetailsScreen({super.key, required this.donationId});

  @override
  State<PickupDetailsScreen> createState() => _PickupDetailsScreenState();
}

class _PickupDetailsScreenState extends State<PickupDetailsScreen> {
  NgoTheme get t => NgoTheme.of(context);

  bool _isUpdating = false;

  Future<void> _updateStatus(DonationModel donation, String newStatus) async {
    if (newStatus == 'Delivered') {
      _showDistributionDialog(donation);
      return;
    }
    await _updateStatusWithTracking(
      donation: donation,
      newStatus: newStatus,
    );
  }

  void _showDistributionDialog(DonationModel donation) {
    final foodCtrl = TextEditingController(text: donation.quantity);
    final beneficiariesCtrl = TextEditingController(
      text: donation.servesCount > 0 ? donation.servesCount.toString() : '',
    );
    final locationCtrl = TextEditingController(text: donation.pickupLocation);

    DateTime selectedDate = DateTime.now();
    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(selectedDate),
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Record Food Distribution',
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
                      Text(
                        'Please record the distribution details to complete this delivery.',
                        style: GoogleFonts.publicSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Food Delivered (quantity)
                      TextFormField(
                        controller: foodCtrl,
                        style: GoogleFonts.publicSans(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Food Delivered (Quantity) *',
                          prefixIcon: Icon(Icons.scale_outlined, size: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter food quantity' : null,
                      ),
                      const SizedBox(height: 12),

                      // Number of Beneficiaries Served
                      TextFormField(
                        controller: beneficiariesCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.publicSans(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Number of Beneficiaries Served *',
                          prefixIcon: Icon(Icons.people_outline, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter number of beneficiaries';
                          if (int.tryParse(v.trim()) == null) return 'Enter a valid integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Delivery Location
                      TextFormField(
                        controller: locationCtrl,
                        style: GoogleFonts.publicSans(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Delivery Location *',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter delivery location' : null,
                      ),
                      const SizedBox(height: 12),

                      // Delivery Date
                      TextFormField(
                        controller: dateCtrl,
                        readOnly: true,
                        style: GoogleFonts.publicSans(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Delivery Date *',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.date_range, color: AppColors.primary),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDate = picked;
                                  dateCtrl.text = DateFormat('yyyy-MM-dd').format(selectedDate);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.publicSans(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 42),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final foodQty = foodCtrl.text.trim();
                      final beneficiaries = int.parse(beneficiariesCtrl.text.trim());
                      final delLocation = locationCtrl.text.trim();
                      
                      Navigator.pop(dialogCtx);
                      
                      await _updateStatusWithTracking(
                        donation: donation,
                        newStatus: 'Delivered',
                        foodDelivered: foodQty,
                        beneficiariesServed: beneficiaries,
                        deliveryLocation: delLocation,
                        deliveryDate: selectedDate,
                      );
                    }
                  },
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatusWithTracking({
    required DonationModel donation,
    required String newStatus,
    String? foodDelivered,
    int? beneficiariesServed,
    String? deliveryLocation,
    DateTime? deliveryDate,
  }) async {
    setState(() => _isUpdating = true);
    try {
      final db = FirebaseFirestore.instance;

      // 1. Update Donation Status & details
      final Map<String, dynamic> updateData = {
        'status': newStatus,
      };
      if (newStatus == 'Delivered') {
        updateData['foodDelivered'] = foodDelivered;
        updateData['beneficiariesServed'] = beneficiariesServed;
        updateData['deliveryLocation'] = deliveryLocation;
        updateData['deliveredAt'] = deliveryDate?.toIso8601String() ?? DateTime.now().toIso8601String();
      }

      await db.collection('donations').doc(donation.id).update(updateData);

      // 2. If status is Delivered, free the assigned volunteer
      if (newStatus == 'Delivered' && donation.assignedVolunteerId != null) {
        await db.collection('volunteers').doc(donation.assignedVolunteerId).update({
          'status': 'Available',
          'assignedDonationId': FieldValue.delete(),
        });
      }

      // 3. Add notification for donor
      if (donation.donorId.isNotEmpty) {
        await db.collection('notifications').add({
          'userId': donation.donorId,
          'donationId': donation.id,
          'title': newStatus == 'Picked Up' ? 'Food Picked Up' : 'Food Delivered',
          'body': newStatus == 'Picked Up'
              ? 'Your food donation is on its way to the NGO!'
              : 'Thank you! Your donation has been successfully delivered.',
          'status': newStatus,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondaryContainer,
            content: Text(
              'Pickup status marked as $newStatus!',
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
            content: Text('Failed to update status: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('donations').doc(widget.donationId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: t.background,
            body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: t.background,
            appBar: AppBar(title: const Text('Pickup Details')),
            body: Center(
              child: Text(
                'Donation record not found.',
                style: GoogleFonts.publicSans(color: t.textSecondary),
              ),
            ),
          );
        }

        final donation = DonationModel.fromMap(
          snapshot.data!.data() as Map<String, dynamic>,
          snapshot.data!.id,
        );

        return Scaffold(
          backgroundColor: t.background,
          appBar: AppBar(
            backgroundColor: t.background,
            elevation: 0,
            leadingWidth: 80,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_back_ios, color: t.secondary, size: 16),
                  Text(
                    'back',
                    style: GoogleFonts.publicSans(
                      color: t.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              'Pickup Details',
              style: GoogleFonts.publicSans(
                color: t.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share, color: AppColors.secondary),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppColors.secondary),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Map Card
                    _buildMapCard(donation),
                    const SizedBox(height: 20),

                    // Status Stepper
                    Text(
                      'Status Stepper/Progress Bar',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusStepper(donation.status),
                    const SizedBox(height: 20),

                    // Donor Info Card
                    Text(
                      'Donor info',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDonorInfoCard(donation),
                    const SizedBox(height: 20),

                    // Food Details Card
                    Text(
                      'Food details',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFoodDetailsCard(donation),
                    const SizedBox(height: 20),

                    // Assigned Volunteer Card
                    Text(
                      'Assigned Volunteer',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildVolunteerCard(donation),
                  ],
                ),
              ),

              // Bottom Persistent Actions
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomActions(donation),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── ROUTE MAP CARD ──────────────────────────────────────────────────────

  Widget _buildMapCard(DonationModel donation) {
    final String labelId = donation.id.length > 7 ? donation.id.substring(0, 7).toUpperCase() : donation.id.toUpperCase();

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Stack(
        children: [
          // Map Road Painting
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: RouteMapPainter(),
            ),
          ),

          // Floating Start/End Label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
                      const SizedBox(width: 6),
                      Text(
                        'Donor location',
                        style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 2,
                    height: 10,
                    color: Colors.grey.shade400,
                  ),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary)),
                      const SizedBox(width: 6),
                      Text(
                        'NGO drop point',
                        style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      '#$labelId',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Delivery Scooter Time Card
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Arriving in 12 mins',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    donation.distance.isNotEmpty ? donation.distance : '3.4 km',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Google Map watermark style mockup
          Positioned(
            bottom: 8,
            right: 12,
            child: Text(
              'Google',
              style: GoogleFonts.publicSans(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATUS STEPPER / PROGRESS BAR ────────────────────────────────────────

  Widget _buildStatusStepper(String status) {
    // Status hierarchy:
    // 0: Accepted ('Request Accepted')
    // 1: Volunteer Assigned ('Volunteer Assigned')
    // 2: Picked Up ('Picked Up')
    // 3: Delivered ('Delivered')
    int currentStep = 0;
    if (status == 'Volunteer Assigned') currentStep = 1;
    if (status == 'Picked Up') currentStep = 2;
    if (status == 'Delivered') currentStep = 3;

    final steps = ['Request\nAccepted', 'Volunteer\nAssigned', 'Picked Up', 'Delivered'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (idx) {
          final isCompleted = idx <= currentStep;
          final isLast = idx == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Node circle
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? AppColors.secondary : Colors.grey.shade300,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[idx],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.publicSans(
                          fontSize: 9,
                          fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w500,
                          color: isCompleted ? AppColors.secondary : AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 20,
                    height: 2,
                    color: isCompleted ? AppColors.secondary : Colors.grey.shade300,
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── DONOR INFO CARD ──────────────────────────────────────────────────────

  Widget _buildDonorInfoCard(DonationModel donation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          // Donor Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              donation.donorName.isNotEmpty ? donation.donorName[0].toUpperCase() : 'D',
              style: GoogleFonts.publicSans(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.donorName,
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Address: ${donation.pickupLocation}',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Call & Chat buttons
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.phone, color: AppColors.secondary, size: 16),
              ),
              const SizedBox(height: 2),
              Text('Call', style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.chat_bubble, color: AppColors.secondary, size: 16),
              ),
              const SizedBox(height: 2),
              Text('Chat', style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FOOD DETAILS CARD ────────────────────────────────────────────────────

  Widget _buildFoodDetailsCard(DonationModel donation) {
    final String displayImage = donation.images.isNotEmpty
        ? donation.images.first
        : 'assets/images/donation_placeholder.jpg';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: displayImage.startsWith('http')
                ? Image.network(
                    displayImage,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    displayImage,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),

          // Food Title & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.foodTitle,
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${donation.quantity} (~${donation.servesCount} servings)',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: 'Packaging: ',
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Eco-friendly containers',
                        style: GoogleFonts.publicSans(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (donation.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      text: 'Special Notes: ',
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error),
                      children: [
                        TextSpan(
                          text: donation.notes,
                          style: GoogleFonts.publicSans(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ASSIGNED VOLUNTEER CARD ──────────────────────────────────────────────

  Widget _buildVolunteerCard(DonationModel donation) {
    if (donation.assignedVolunteerId == null || donation.assignedVolunteerId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceContainerHighest),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No Volunteer Assigned. Use Community > Assign Pickups tab to register a helper.',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          // Volunteer Avatar with yellow container color background
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.amber.shade200,
            child: Text(
              donation.assignedVolunteerName!.isNotEmpty ? donation.assignedVolunteerName![0].toUpperCase() : 'V',
              style: GoogleFonts.publicSans(
                fontWeight: FontWeight.w800,
                color: Colors.amber.shade800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Volunteer details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.assignedVolunteerName!,
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.motorcycle, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Bike',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rating stars (5 stars)
          Row(
            children: List.generate(
              5,
              (idx) => const Icon(Icons.star, color: Colors.orange, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM ACTIONS BAR ───────────────────────────────────────────────────

  Widget _buildBottomActions(DonationModel donation) {
    final String currentStatus = donation.status;
    final bool isAssigned = donation.assignedVolunteerId != null;

    if (currentStatus == 'Delivered') {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'DELIVERY COMPLETED',
            style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    // Determine target status
    String buttonText = 'Mark as Picked Up';
    String nextStatus = 'Picked Up';
    bool showButton = isAssigned;

    if (currentStatus == 'Picked Up') {
      buttonText = 'Mark as Delivered';
      nextStatus = 'Delivered';
    }

    if (!showButton && currentStatus == 'Accepted') {
      // If accepted but no volunteer assigned, show button to let them know they need assignment
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Text(
            'Awaiting Volunteer Assignment',
            style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.amber.shade800),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Mark as Picked Up / Delivered Button
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () => _updateStatus(donation, nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        buttonText,
                        style: GoogleFonts.publicSans(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Report an Issue Button
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Report filed. Support will reach out shortly.',
                        style: GoogleFonts.publicSans(),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(
                  'Report an Issue',
                  style: GoogleFonts.publicSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw route roads and markers on map preview
class RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid roads
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadCenterPaint = Paint()
      ..color = AppColors.surfaceContainerHighest
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.lineTo(size.width * 0.35, size.height * 0.4);
    path.lineTo(size.width * 0.6, size.height * 0.25);
    path.lineTo(size.width * 0.6, size.height * 0.7);
    path.lineTo(size.width, size.height * 0.7);

    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path, roadCenterPaint);

    // Route path (active line)
    final routePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final routePath = Path();
    routePath.moveTo(size.width * 0.2, size.height * 0.4);
    routePath.lineTo(size.width * 0.35, size.height * 0.4);
    routePath.lineTo(size.width * 0.6, size.height * 0.25);
    routePath.lineTo(size.width * 0.6, size.height * 0.55);

    canvas.drawPath(routePath, routePaint);

    // Start Location pin: yellow pin
    final startPinPaint = Paint()..color = Colors.amber;
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.4), 6, startPinPaint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.4), 10, startPinPaint..style = PaintingStyle.stroke);

    // End Location pin: green pin
    final endPinPaint = Paint()..color = AppColors.secondary;
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.25), 6, endPinPaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.25), 10, endPinPaint..style = PaintingStyle.stroke);

    // Delivery boy icon (represented as scooter bubble on map)
    final scooterBubblePaint = Paint()..color = Colors.white;
    final scooterPos = Offset(size.width * 0.48, size.height * 0.32);
    canvas.drawCircle(scooterPos, 12, scooterBubblePaint);
    canvas.drawCircle(scooterPos, 12, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Tiny delivery motor icon representation
    final bikeIconPainter = TextPainter(
      text: const TextSpan(
        text: '🛵',
        style: TextStyle(fontSize: 12),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    bikeIconPainter.layout();
    bikeIconPainter.paint(canvas, scooterPos - Offset(bikeIconPainter.width / 2, bikeIconPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
