import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/donor/donation_model.dart';
import '../../services/storage_service.dart';
import '../../services/donor_verification.dart';
import '../../services/geocoding_helper.dart';
import '../../utils/geo_distance.dart';
import '../../utils/responsive.dart';
import '../../widgets/location/location_map_section.dart';
import '../../widgets/donor_notification_bell.dart';
import 'food_photo_camera_screen.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  // Form Field State
  String _selectedFoodCategory = 'Veg'; // 'Veg' | 'Non-Veg'
  int _servingsCount = 1;

  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _pickupDateTime;
  DateTime? _expiryDateTime;
  double? _selectedLat;
  double? _selectedLng;

  // Food Safety T&C Governance State
  bool _termsAcknowledged = false;
  DateTime? _termsAcceptedTimestamp;

  // NGO Selection State (Real Registered NGO details)
  String _selectedNgoId = '';
  final TextEditingController _ngoSearchController = TextEditingController();
  List<_DonorNgoOption> _availableNgos = [];
  final Map<String, (double, double)> _geocodedCoords = {};
  final Set<String> _geocodeTried = {};
  bool _geocodeRunning = false;

  bool _isSubmitting = false;
  XFile? _selectedXFile;
  Uint8List? _selectedImageBytes;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _foodNameController.dispose();
    _quantityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _ngoSearchController.dispose();
    super.dispose();
  }

  /// Camera opens in-app live preview. Gallery opens the photo library only.
  Future<void> _captureWithDeviceCamera() async {
    final granted = await _ensureMediaPermission(ImageSource.camera);
    if (!granted) return;
    if (!mounted) return;

    try {
      final Uint8List? bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => const FoodPhotoCameraScreen(),
          fullscreenDialog: true,
        ),
      );

      if (bytes == null || !mounted) return;

      setState(() {
        _selectedXFile = null;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open camera: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final granted = await _ensureMediaPermission(ImageSource.gallery);
    if (!granted) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedXFile = image;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open gallery. Please try again.')),
      );
    }
  }

  /// Returns true only when the donor allows the needed permission.
  Future<bool> _ensureMediaPermission(ImageSource source) async {
    // Web browsers handle media prompts themselves.
    if (kIsWeb) return true;

    final isCamera = source == ImageSource.camera;
    final permission = isCamera ? Permission.camera : Permission.photos;

    var status = await permission.status;

    // Android gallery: photos may map to storage / photos depending on API level.
    if (!isCamera && (status.isDenied || status.isRestricted)) {
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;
    }

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await _showPermissionSettingsDialog(
        isCamera ? 'Camera' : 'Gallery',
        isCamera
            ? 'Sahyog needs camera access to capture a fresh food photo. Please enable Camera in Settings.'
            : 'Sahyog needs gallery access to choose a food photo. Please enable Photos in Settings.',
      );
      return false;
    }

    status = await permission.request();

    // Fallback for older Android gallery access.
    if (!isCamera && !(status.isGranted || status.isLimited)) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
    }

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await _showPermissionSettingsDialog(
        isCamera ? 'Camera' : 'Gallery',
        isCamera
            ? 'Camera permission was denied. Enable it in Settings to take a donation photo.'
            : 'Gallery permission was denied. Enable it in Settings to choose a donation photo.',
      );
      return false;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCamera
                ? 'Camera permission is required to take a food photo.'
                : 'Gallery permission is required to choose a food photo.',
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _showPermissionSettingsDialog(String title, String message) async {
    if (!mounted) return;
    final c = context.colors;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('$title Permission Needed', style: TextStyle(color: c.textPrimary)),
        content: Text(message, style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Not Now', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await openAppSettings();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Material(
          color: c.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Food Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Allow Camera or Gallery permission when asked, then continue.',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text('Take Photo (Camera)', style: TextStyle(color: c.textPrimary)),
                subtitle: Text(
                  'Opens live camera to capture a fresh photo',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  // Let the sheet close fully before launching camera.
                  await Future<void>.delayed(const Duration(milliseconds: 200));
                  await _captureWithDeviceCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: Text('Choose from Gallery', style: TextStyle(color: c.textPrimary)),
                subtitle: Text(
                  'Opens your photo gallery only',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Future<void>.delayed(const Duration(milliseconds: 200));
                  await _pickFromGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Explicit Location Pick & Reverse Geocoding (OpenStreetMap / Nominatim fallback)
  void _showFoodSafetyTermsModal() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text(
              'Food Safety Declaration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'By submitting this donation, you agree to Sahyog Food Safety Governance Standards:',
                style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('1. Hygiene: Food prepared in sanitary kitchens following safety protocols.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              SizedBox(height: 8),
              Text('2. Freshness: Cooked food dispatched within 4 hours of preparation.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              SizedBox(height: 8),
              Text('3. Packaging: Food packed in food-grade, leak-proof containers.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _termsAcknowledged = true;
                _termsAcceptedTimestamp = DateTime.now();
              });
              Navigator.pop(context);
            },
            child: const Text('I Agree & Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isPickup) async {
    final c = context.colors;
    final DateTime initial = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial,
      lastDate: initial.add(const Duration(days: 7)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: c.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: c.textPrimary,
            ),
          ),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        final fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isPickup) {
            _pickupDateTime = fullDateTime;
          } else {
            _expiryDateTime = fullDateTime;
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Select Date & Time';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  double? _parseCoord(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _isApprovedNgo(Map<String, dynamic> data) {
    final status = (data['status'] ?? data['verificationStatus'] ?? data['approvalStatus'] ?? data['adminStatus'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final verified = data['verified'] == true || data['isApproved'] == true || data['approved'] == true;
    if (verified) return true;
    return status == 'approved' || status == 'verified' || status == 'active';
  }

  List<String> _parseAreas(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  (double, double)? _coordsFor(_DonorNgoOption ngo) {
    if (ngo.latitude != null && ngo.longitude != null) {
      return (ngo.latitude!, ngo.longitude!);
    }
    return _geocodedCoords[ngo.id];
  }

  double? _distanceKm(_DonorNgoOption ngo) {
    if (_selectedLat == null || _selectedLng == null) return null;
    final coords = _coordsFor(ngo);
    if (coords == null) return null;
    return GeoDistance.km(_selectedLat!, _selectedLng!, coords.$1, coords.$2);
  }

  bool _matchesPickupArea(_DonorNgoOption ngo) {
    final pickup = _addressController.text.trim().toLowerCase();
    if (pickup.isEmpty) return false;
    for (final area in ngo.workingAreas) {
      final a = area.toLowerCase();
      if (a.isNotEmpty && pickup.contains(a)) return true;
    }
    final address = ngo.address.toLowerCase();
    if (address.isEmpty || address == 'address not updated') return false;
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.length > 2);
    return parts.any((part) => pickup.contains(part));
  }

  List<_DonorNgoOption> _rankedNearbyNgos(List<_DonorNgoOption> source) {
    final ranked = [...source];
    ranked.sort((a, b) {
      final da = _distanceKm(a);
      final db = _distanceKm(b);
      if (da != null && db != null) return da.compareTo(db);
      if (da != null) return -1;
      if (db != null) return 1;
      final ta = _matchesPickupArea(a);
      final tb = _matchesPickupArea(b);
      if (ta != tb) return ta ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return ranked;
  }

  _DonorNgoOption? _resolveTargetNgo() {
    if (_selectedNgoId.isEmpty) return null;
    for (final ngo in _availableNgos) {
      if (ngo.id == _selectedNgoId) return ngo;
    }
    return null;
  }

  void _selectNgo(_DonorNgoOption ngo) {
    setState(() {
      _selectedNgoId = ngo.id;
    });
  }

  void _queueMissingNgoGeocodes(List<_DonorNgoOption> ngos) {
    if (_geocodeRunning || _selectedLat == null || _selectedLng == null) return;
    final pending = ngos
        .where((n) =>
            n.latitude == null &&
            n.longitude == null &&
            n.address.isNotEmpty &&
            n.address.toLowerCase() != 'address not updated' &&
            !_geocodeTried.contains(n.id))
        .take(8)
        .toList();
    if (pending.isEmpty) return;
    _geocodeRunning = true;
    Future(() async {
      for (final ngo in pending) {
        _geocodeTried.add(ngo.id);
        final result = await GeocodingHelper.resolveAddress('${ngo.address}, India');
        if (result != null) {
          _geocodedCoords[ngo.id] = (result.latitude, result.longitude);
        }
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      _geocodeRunning = false;
      if (mounted) setState(() {});
    });
  }

  /// Submission Contract to Firestore
  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_foodNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the food name.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_servingsCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set meal impact servings (at least 1).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the food quantity.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture a food photo before submitting.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_termsAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please acknowledge the Food Safety & Pickup Terms before proceeding.'),
          backgroundColor: AppColors.statusPending,
        ),
      );
      _showFoodSafetyTermsModal();
      return;
    }

    if (_pickupDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Pickup Date & Time.')),
      );
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pin or enter a pickup address so nearby NGOs can be matched.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to submit a donation.')),
      );
      return;
    }

    final profile = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    if (!DonorVerification.isAllowedToDonate(profile.data())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your donor account is pending admin verification. You can donate after approval.'),
          backgroundColor: AppColors.statusPending,
        ),
      );
      return;
    }

    final assigned = _resolveTargetNgo();
    if (assigned == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an NGO to receive this donation.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String uploadedUrl = '';
      setState(() => _isUploadingImage = true);
      final url = await _storageService.uploadDonationImage(
        _selectedXFile ?? _selectedImageBytes,
      );
      if (url != null && url.isNotEmpty) {
        uploadedUrl = url;
      }

      final donation = DonationModel(
        donorId: currentUser.uid,
        foodName: _foodNameController.text.trim(),
        foodType: _selectedFoodCategory,
        foodQuantity: _quantityController.text.trim(),
        servings: _servingsCount,
        pickupAddress: _addressController.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        pickupTime: _formatDateTime(_pickupDateTime),
        expiryTime: _formatDateTime(_expiryDateTime),
        notes: '${_notesController.text.trim()}${_termsAcceptedTimestamp != null ? ' • Safety Terms Accepted: ${_termsAcceptedTimestamp!.toIso8601String()}' : ''}',
        imageUrl: uploadedUrl,
        status: 'pending',
        ngoId: assigned.id,
        ngoName: assigned.name,
        ngoAddress: assigned.address.isNotEmpty ? assigned.address : null,
        ngoPhone: assigned.phone.isNotEmpty ? assigned.phone : null,
      );

      await FirebaseFirestore.instance.collection('donations').add(donation.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation Request Submitted Successfully!'),
            backgroundColor: AppColors.statusDelivered,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting donation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _foodNameController.clear();
    _quantityController.clear();
    _addressController.clear();
    _notesController.clear();
    setState(() {
      _selectedFoodCategory = 'Veg';
      _servingsCount = 1;
      _pickupDateTime = null;
      _expiryDateTime = null;
      _selectedLat = null;
      _selectedLng = null;
      _selectedXFile = null;
      _selectedImageBytes = null;
      _termsAcknowledged = false;
      _termsAcceptedTimestamp = null;
      _selectedNgoId = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(user),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: r.pagePadding, vertical: 16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Food Donation',
                      style: TextStyle(
                        fontSize: r.pageTitleSize,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your surplus meals safely with verified NGO partners in real-time.',
                      style: TextStyle(fontSize: 14, color: c.textSecondary),
                    ),
                    if (user != null)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData || DonorVerification.isAllowedToDonate(snap.data?.data())) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.statusPending.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.statusPending),
                              ),
                              child: const Text(
                                'Your donor account is waiting for admin verification. Donating is unlocked after an admin verifies you.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
                    SizedBox(height: r.sectionGap),

                    // 1. Food Name (before category)
                    _buildSectionHeader('1. Food Name'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _foodNameController,
                      style: TextStyle(color: c.textPrimary),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Please enter the food name' : null,
                      decoration: InputDecoration(
                        labelText: 'Food Name',
                        labelStyle: TextStyle(color: c.textSecondary),
                        prefixIcon: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: c.borderLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Food Type Selection Cards (Veg / Non-Veg)
                    _buildSectionHeader('2. Select Food Category'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFoodCategoryCard('Veg', Icons.eco_rounded, Colors.green),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFoodCategoryCard('Non-Veg', Icons.kebab_dining_rounded, AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 3. Quantity & Servings Count Stepper
                    _buildSectionHeader('3. Quantity & Meal Impact Servings'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _quantityController,
                            style: TextStyle(color: c.textPrimary),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Please enter quantity' : null,
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              helperText: 'Physical amount being donated',
                              labelStyle: TextStyle(color: c.textSecondary),
                              prefixIcon: const Icon(Icons.scale_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: c.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: c.borderLight),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stack = constraints.maxWidth < 360;
                              final label = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Meal Impact Servings',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
                                  ),
                                  Text(
                                    'How many people can this feed?',
                                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                                  ),
                                ],
                              );
                              final stepper = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (_servingsCount > 1) {
                                        setState(() => _servingsCount -= 1);
                                      }
                                    },
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary, size: 30),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTint,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$_servingsCount',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _servingsCount += 1);
                                    },
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 30),
                                  ),
                                ],
                              );

                              if (stack) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label,
                                    const SizedBox(height: 8),
                                    Align(alignment: Alignment.centerRight, child: stepper),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: label),
                                  stepper,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Food Condition Photo Upload (unchanged)
                    _buildSectionHeader('4. Food Condition Photo'),
                    const SizedBox(height: 12),
                    _buildPhotoUploadContainer(),
                    const SizedBox(height: 24),

                    // 5. Pickup Location (map UI matching reference)
                    LocationMapSection(
                      title: 'Pickup Location or Drop-off Center',
                      addressController: _addressController,
                      addressHint: 'Enter specific address',
                      latitude: _selectedLat,
                      longitude: _selectedLng,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter or select pickup address'
                          : null,
                      onLocationChanged: (address, lat, lng) {
                        setState(() {
                          _addressController.text = address;
                          _selectedLat = lat;
                          _selectedLng = lng;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // 6. Select Registered NGO Partner with Name, Address, & Mobile Number
                    _buildSectionHeader('6. Select Verified NGO Partner'),
                    const SizedBox(height: 12),
                    _buildNgoSelectionDropdown(),
                    const SizedBox(height: 24),

                    // 7. Pickup & Expiry Time Window Pickers
                    _buildSectionHeader('7. Logistics Time Windows'),
                    const SizedBox(height: 12),
                    ResponsiveRow(
                      spacing: 12,
                      children: [
                        _buildTimePickerCard(
                          title: 'Pickup Window',
                          value: _formatDateTime(_pickupDateTime),
                          icon: Icons.access_time_rounded,
                          onTap: () => _selectDateTime(context, true),
                        ),
                        _buildTimePickerCard(
                          title: 'Expiry Window',
                          value: _formatDateTime(_expiryDateTime),
                          icon: Icons.timer_outlined,
                          onTap: () => _selectDateTime(context, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 8. Additional Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Special handling or preparation notes',
                        labelStyle: TextStyle(color: c.textSecondary),
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: c.borderLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 9. Food Safety Governance Checkbox
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _termsAcknowledged ? AppColors.primary : c.borderLight),
                      ),
                      child: Material(
                        color: _termsAcknowledged ? AppColors.primaryTint.withValues(alpha: 0.5) : c.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: CheckboxListTile(
                            activeColor: AppColors.primary,
                            title: Text(
                              'Food Safety Governance & Hygiene Agreement',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.textPrimary),
                            ),
                            subtitle: Text(
                              'Tap to read & acknowledge food safety standards before submission.',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                            value: _termsAcknowledged,
                            onChanged: (bool? val) {
                              if (val == true) {
                                _showFoodSafetyTermsModal();
                              } else {
                                setState(() {
                                  _termsAcknowledged = false;
                                  _termsAcceptedTimestamp = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                    // Submit CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: (_isSubmitting || _isUploadingImage) ? null : _submitDonation,
                        child: (_isSubmitting || _isUploadingImage)
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                'Submit Donation Request',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
);
  }

  Widget _buildTopAppBar(User? user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user != null
          ? FirebaseFirestore.instance.collection('donors').doc(user.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        return Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Sahyog',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const DonorNotificationBell(size: 24),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                          child: profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    final c = context.colors;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: c.textPrimary,
      ),
    );
  }

  Widget _buildFoodCategoryCard(String label, IconData icon, Color iconColor) {
    final c = context.colors;
    final isSelected = _selectedFoodCategory == label;

    return InkWell(
      onTap: () => setState(() => _selectedFoodCategory = label),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint.withValues(alpha: 0.4) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : c.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoUploadContainer() {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        children: [
          if (_selectedImageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _selectedImageBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  label: const Text('Change Photo', style: TextStyle(color: AppColors.primary)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedXFile = null;
                      _selectedImageBytes = null;
                    });
                  },
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  label: const Text('Remove', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ] else ...[
            Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            Text(
              'Upload Fresh Food Photo',
              style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Required for quality verification by pickup volunteers',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture or Select Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _upsertNgo(
    Map<String, _DonorNgoOption> byId, {
    required String id,
    required Map<String, dynamic> data,
  }) {
    if (id.isEmpty) return;
    final rawName = (data['name'] ??
            data['organizationName'] ??
            data['ngoName'] ??
            data['fullName'] ??
            data['orgName'] ??
            data['displayName'] ??
            data['title'] ??
            data['email'] ??
            'Registered NGO')
        .toString()
        .trim();
    final name = rawName.isNotEmpty ? rawName : 'Registered NGO';
    final address = (data['address'] ??
            data['officialAddress'] ??
            data['location'] ??
            data['ngoAddress'] ??
            '')
        .toString()
        .trim();
    final phone = (data['phone'] ??
            data['contactPhone'] ??
            data['phoneNumber'] ??
            data['mobile'] ??
            '')
        .toString()
        .trim();
    final lat = _parseCoord(data['latitude']);
    final lng = _parseCoord(data['longitude']);
    final areas = _parseAreas(data['workingAreas'] ?? data['workingArea']);

    final existing = byId[id];
    if (existing == null) {
      byId[id] = _DonorNgoOption(
        id: id,
        name: name,
        address: address.isNotEmpty ? address : 'Address not updated',
        phone: phone.isNotEmpty ? phone : 'Phone not updated',
        latitude: lat,
        longitude: lng,
        workingAreas: areas,
      );
      return;
    }
    byId[id] = _DonorNgoOption(
      id: id,
      name: existing.name != 'Registered NGO' && existing.name.isNotEmpty ? existing.name : name,
      address: existing.address == 'Address not updated' && address.isNotEmpty
          ? address
          : existing.address,
      phone: existing.phone == 'Phone not updated' && phone.isNotEmpty
          ? phone
          : existing.phone,
      latitude: existing.latitude ?? lat,
      longitude: existing.longitude ?? lng,
      workingAreas: existing.workingAreas.isNotEmpty ? existing.workingAreas : areas,
    );
  }

  /// NGO Selection — all verified/approved NGOs with dropdown selection.
  Widget _buildNgoSelectionDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('ngos').snapshots(),
          builder: (context, ngosSnap) {
            final c = context.colors;
            final Map<String, _DonorNgoOption> byId = {};

            if (usersSnap.hasData) {
              for (final doc in usersSnap.data!.docs) {
                final data = doc.data();
                final role = (data['role'] ?? data['type'] ?? data['userType'] ?? '').toString().toLowerCase().trim();
                final isNgoRole = role == 'ngo' || (data['organizationName'] != null && data['organizationName'].toString().isNotEmpty);
                if (isNgoRole && _isApprovedNgo(data)) {
                  _upsertNgo(byId, id: doc.id, data: data);
                }
              }
            }

            if (ngosSnap.hasData) {
              for (final doc in ngosSnap.data!.docs) {
                final data = doc.data();
                final userData = usersSnap.data?.docs
                    .where((d) => d.id == doc.id)
                    .map((d) => d.data())
                    .firstOrNull;
                final isAppr = _isApprovedNgo(data) || (userData != null && _isApprovedNgo(userData));
                if (isAppr) {
                  _upsertNgo(byId, id: doc.id, data: data);
                }
              }
            }

            final allNgos = byId.values.toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _availableNgos = allNgos;
              _queueMissingNgoGeocodes(allNgos);
            });

            final ngoQuery = _ngoSearchController.text.trim().toLowerCase();
            final searched = allNgos.where((ngo) {
              if (ngoQuery.isEmpty) return true;
              return ngo.name.toLowerCase().contains(ngoQuery) ||
                  ngo.address.toLowerCase().contains(ngoQuery) ||
                  ngo.phone.toLowerCase().contains(ngoQuery);
            }).toList();

            final ranked = _rankedNearbyNgos(searched);
            final selectedNgo = allNgos.where((n) => n.id == _selectedNgoId).firstOrNull;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Count badge
                Text(
                  '${allNgos.length} verified NGO${allNgos.length == 1 ? '' : 's'} available',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary),
                ),
                const SizedBox(height: 8),

                // Search box
                TextField(
                  controller: _ngoSearchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search NGOs by name, address, or phone...',
                    hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _ngoSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: c.textSecondary, size: 18),
                            onPressed: () {
                              _ngoSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: c.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.borderLight),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // NGO Dropdown Button with Downward Arrow
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedNgoId.isNotEmpty ? AppColors.primary : c.borderLight,
                      width: _selectedNgoId.isNotEmpty ? 1.6 : 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedNgoId.isNotEmpty && ranked.any((n) => n.id == _selectedNgoId)
                          ? _selectedNgoId
                          : null,
                      hint: Row(
                        children: [
                          const Icon(Icons.domain_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Select from verified NGO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      dropdownColor: c.surface,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          final selected = ranked.firstWhere((n) => n.id == newValue);
                          _selectNgo(selected);
                        }
                      },
                      items: ranked.map((ngo) {
                        final km = _distanceKm(ngo);
                        return DropdownMenuItem<String>(
                          value: ngo.id,
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  km != null
                                      ? '${ngo.name} (${km.toStringAsFixed(1)} km away)'
                                      : ngo.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Selected NGO Info Card Display
                if (selectedNgo != null) ...[
                  Text(
                    'Selected Recipient NGO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  _buildNgoInfoCard(
                    c,
                    title: selectedNgo.name,
                    subtitle: [
                      if (_distanceKm(selectedNgo) != null)
                        '${_distanceKm(selectedNgo)!.toStringAsFixed(1)} km away',
                      if (selectedNgo.address.isNotEmpty && selectedNgo.address != 'Address not updated')
                        selectedNgo.address,
                    ].join(' • '),
                    phone: selectedNgo.phone,
                    selected: true,
                  ),
                ],

                if (ranked.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.borderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.domain_disabled_outlined, color: c.textSecondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ngoQuery.isEmpty
                                ? 'No verified NGOs available yet.'
                                : 'No NGO matches "$ngoQuery".',
                            style: TextStyle(fontSize: 13, color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNgoInfoCard(
    AppColorSet c, {
    required String title,
    required String subtitle,
    required String phone,
    required bool selected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryTint.withValues(alpha: 0.45)
            : AppColors.primaryTint.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty && phone != 'Phone not updated') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DonorNgoOption {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final List<String> workingAreas;

  const _DonorNgoOption({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.latitude,
    this.longitude,
    this.workingAreas = const [],
  });
}
