import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/donation_model.dart';
import '../../services/app_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../widgets/animated_driver_marker.dart';

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
    final theme = t;
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
              backgroundColor: theme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Record Food Distribution',
                style: GoogleFonts.publicSans(
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
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
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Food Delivered (quantity)
                      TextFormField(
                        controller: foodCtrl,
                        style: GoogleFonts.publicSans(color: theme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Food Delivered (Quantity) *',
                          labelStyle: TextStyle(color: theme.textSecondary),
                          prefixIcon: Icon(Icons.scale_outlined, size: 20, color: theme.primary),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter food quantity' : null,
                      ),
                      const SizedBox(height: 12),

                      // Number of Beneficiaries Served
                      TextFormField(
                        controller: beneficiariesCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.publicSans(color: theme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Number of Beneficiaries Served *',
                          labelStyle: TextStyle(color: theme.textSecondary),
                          prefixIcon: Icon(Icons.people_outline, size: 20, color: theme.primary),
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
                        style: GoogleFonts.publicSans(color: theme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Delivery Location *',
                          labelStyle: TextStyle(color: theme.textSecondary),
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: theme.primary),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter delivery location' : null,
                      ),
                      const SizedBox(height: 12),

                      // Delivery Date
                      TextFormField(
                        controller: dateCtrl,
                        readOnly: true,
                        style: GoogleFonts.publicSans(color: theme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Delivery Date *',
                          labelStyle: TextStyle(color: theme.textSecondary),
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20, color: theme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.date_range, color: theme.primary),
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
                    style: GoogleFonts.publicSans(color: theme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.isDark ? Colors.white : Colors.black,
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
                  child: Text(
                    'Complete',
                    style: GoogleFonts.publicSans(
                      fontWeight: FontWeight.w800,
                      color: theme.isDark ? Colors.white : Colors.black,
                    ),
                  ),
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
        await AppNotifications.send(
          userId: donation.donorId,
          donationId: donation.id,
          title: newStatus == 'Picked Up' ? 'Food Picked Up' : 'Food Delivered',
          body: newStatus == 'Picked Up'
              ? 'Your food donation is on its way to the NGO!'
              : 'Thank you! Your donation has been successfully delivered.',
          status: newStatus,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1E1E),
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
                  Icon(Icons.arrow_back_ios, color: t.primary, size: 16),
                  Text(
                    'back',
                    style: GoogleFonts.publicSans(
                      color: t.primary,
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
                        color: t.textPrimary,
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
                        color: t.textPrimary,
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
                        color: t.textPrimary,
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
                        color: t.textPrimary,
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
    final pickupLat = donation.latitude ?? 19.0760;
    final pickupLng = donation.longitude ?? 72.8777;
    final pickupPos = LatLng(pickupLat, pickupLng);
    final ngoPos = LatLng(pickupLat - 0.020, pickupLng - 0.015);
    final realGps = (donation.driverLatitude != null && donation.driverLongitude != null)
        ? LatLng(donation.driverLatitude!, donation.driverLongitude!)
        : null;

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pickupPos,
                initialZoom: 12.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sahyog.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [pickupPos, ngoPos],
                      color: AppColors.primary,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Pickup Location Pin (Donor)
                    Marker(
                      point: pickupPos,
                      width: 36,
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    // Drop-off Pin (NGO Hub)
                    Marker(
                      point: ngoPos,
                      width: 36,
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                AnimatedDriverMarker(
                  polyline: [pickupPos, ngoPos],
                  realGpsPosition: realGps,
                ),
              ],
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
                        style: GoogleFonts.publicSans(fontSize: 11, color: t.textSecondary, fontWeight: FontWeight.w500),
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
                        style: GoogleFonts.publicSans(fontSize: 11, color: t.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      '#$labelId',
                      style: GoogleFonts.inter(fontSize: 10, color: t.textSecondary, fontWeight: FontWeight.bold),
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
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
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
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    donation.distance.isNotEmpty ? donation.distance : '3.4 km',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      color: t.textSecondary,
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
    if (status == 'On Delivery') currentStep = 3;
    if (status == 'Delivered') currentStep = 4;

    final steps = ['Accepted', 'Volunteer\nAssigned', 'Picked Up', 'On Delivery', 'Completed'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
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
                          color: isCompleted ? t.primary : t.outline.withValues(alpha: 0.3),
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
                          color: isCompleted ? t.primary : t.textSecondary,
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
                    color: isCompleted ? t.primary : t.outline.withValues(alpha: 0.3),
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
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          // Donor Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: t.primary.withValues(alpha: 0.1),
            child: Text(
              donation.donorName.isNotEmpty ? donation.donorName[0].toUpperCase() : 'D',
              style: GoogleFonts.publicSans(
                fontWeight: FontWeight.w800,
                color: t.primary,
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
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Address: ${donation.pickupLocation}',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    color: t.textSecondary,
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
                  color: t.primary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.phone, color: t.primary, size: 16),
              ),
              const SizedBox(height: 2),
              Text('Call', style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w600, color: t.primary)),
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
                  color: t.primary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.chat_bubble, color: t.primary, size: 16),
              ),
              const SizedBox(height: 2),
              Text('Chat', style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w600, color: t.primary)),
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
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
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
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${donation.quantity} (~${donation.servesCount} servings)',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: 'Packaging: ',
                    style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: t.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Eco-friendly containers',
                        style: GoogleFonts.publicSans(fontWeight: FontWeight.w500, color: t.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (donation.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      text: 'Special Notes: ',
                      style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: t.error),
                      children: [
                        TextSpan(
                          text: donation.notes,
                          style: GoogleFonts.publicSans(fontWeight: FontWeight.w500, color: t.textSecondary),
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
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.surfaceContainerHighest),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: t.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No Volunteer Assigned. Use Community > Assign Pickups tab to register a helper.',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: t.textSecondary,
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
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          // Volunteer Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.amber.shade200,
            child: Text(
              donation.assignedVolunteerName!.isNotEmpty ? donation.assignedVolunteerName![0].toUpperCase() : 'V',
              style: GoogleFonts.publicSans(
                fontWeight: FontWeight.w800,
                color: Colors.amber.shade900,
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
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.motorcycle, size: 14, color: t.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Bike',
                      style: GoogleFonts.publicSans(
                        fontSize: 11,
                        color: t.textSecondary,
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
        color: t.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'DELIVERY COMPLETED',
            style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: t.textSecondary),
          ),
        ),
      );
    }

    // Determine target status
    String buttonText = 'Mark as Picked Up';
    String nextStatus = 'Picked Up';

    if (currentStatus == 'Accepted' || currentStatus == 'Volunteer Assigned') {
      buttonText = 'Mark as Picked Up';
      nextStatus = 'Picked Up';
    } else if (currentStatus == 'Picked Up') {
      buttonText = 'Mark On Delivery';
      nextStatus = 'On Delivery';
    } else if (currentStatus == 'On Delivery') {
      buttonText = 'Mark as Completed';
      nextStatus = 'Delivered';
    }

    if (!isAssigned && currentStatus == 'Accepted') {
      // If accepted but no volunteer assigned, show button to let them know they need assignment
      return Container(
        color: t.surface,
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
        color: t.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isUpdating
              ? null
              : () => _updateStatus(donation, nextStatus),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.primary,
            foregroundColor: t.isDark ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: _isUpdating
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: t.isDark ? Colors.white : Colors.black, strokeWidth: 2),
                )
              : Text(
                  buttonText,
                  style: GoogleFonts.publicSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: t.isDark ? Colors.white : Colors.black,
                  ),
                ),
        ),
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
