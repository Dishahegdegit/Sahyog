import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_colors.dart';
import '../../models/donor/donation_model.dart';
import '../../services/cloudinary_service.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  // Form Field State
  String _selectedFoodCategory = 'Veg'; // 'Veg' | 'Non-Veg'
  int _servingsCount = 0;

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
  String _selectedNgoOption = 'Auto-Assign Nearest NGO';
  String _selectedNgoAddress = '';
  String _selectedNgoPhone = '';

  bool _isSubmitting = false;
  XFile? _selectedXFile;
  Uint8List? _selectedImageBytes;
  bool _isUploadingImage = false;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Photo capture/upload pipeline
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedXFile = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Material(
          color: Colors.white,
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo from Camera', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Explicit Location Pick & Reverse Geocoding (NO FALSE THIRTHAHALLI ASSUMPTIONS)
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please turn on GPS.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
      });

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
      );

      final response = await http.get(url, headers: {'User-Agent': 'SahyogApp/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;

        if (displayName != null && displayName.isNotEmpty) {
          setState(() {
            _addressController.text = displayName;
          });
        } else {
          setState(() {
            _addressController.text = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
          });
        }
      } else {
        setState(() {
          _addressController.text = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location pin confirmed and address resolved!'),
            backgroundColor: AppColors.statusDelivered,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location resolution error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  void _showFoodSafetyTermsModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text(
              'Food Safety Declaration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'By submitting this donation, you agree to Sahyog Food Safety Governance Standards:',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('1. Hygiene: Food prepared in sanitary kitchens following safety protocols.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('2. Freshness: Cooked food dispatched within 4 hours of preparation.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              SizedBox(height: 8),
              Text('3. Packaging: Food packed in food-grade, leak-proof containers.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
    final DateTime initial = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial,
      lastDate: initial.add(const Duration(days: 7)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
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
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
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

  /// Submission Contract to Firestore
  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_servingsCount <= 0 && _quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter food quantity or number of servings.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedXFile == null || _selectedImageBytes == null) {
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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to submit a donation.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String uploadedUrl = '';
      if (_selectedXFile != null) {
        setState(() => _isUploadingImage = true);
        final url = await _cloudinaryService.uploadImage(_selectedXFile!);
        if (url != null && url.isNotEmpty) {
          uploadedUrl = url;
        }
      }

      final donation = DonationModel(
        donorId: currentUser.uid,
        foodType: _selectedFoodCategory,
        foodQuantity: _quantityController.text.trim().isNotEmpty
            ? _quantityController.text.trim()
            : '$_servingsCount meals',
        servings: _servingsCount,
        pickupAddress: _addressController.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        pickupTime: _formatDateTime(_pickupDateTime),
        expiryTime: _formatDateTime(_expiryDateTime),
        notes: '${_notesController.text.trim()}${_termsAcceptedTimestamp != null ? ' • Safety Terms Accepted: ${_termsAcceptedTimestamp!.toIso8601String()}' : ''}',
        imageUrl: uploadedUrl,
        status: 'pending',
        ngoName: _selectedNgoOption != 'Auto-Assign Nearest NGO' ? _selectedNgoOption : 'Unassigned',
        ngoAddress: _selectedNgoAddress.isNotEmpty ? _selectedNgoAddress : null,
        ngoPhone: _selectedNgoPhone.isNotEmpty ? _selectedNgoPhone : null,
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
    _quantityController.clear();
    _addressController.clear();
    _notesController.clear();
    setState(() {
      _selectedFoodCategory = 'Veg';
      _servingsCount = 0;
      _pickupDateTime = null;
      _expiryDateTime = null;
      _selectedLat = null;
      _selectedLng = null;
      _selectedXFile = null;
      _selectedImageBytes = null;
      _termsAcknowledged = false;
      _termsAcceptedTimestamp = null;
      _selectedNgoOption = 'Auto-Assign Nearest NGO';
      _selectedNgoAddress = '';
      _selectedNgoPhone = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopAppBar(user),
                    const SizedBox(height: 20),

                    const Text(
                      'Create Food Donation',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Share your surplus meals safely with verified NGO partners in real-time.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // 1. Food Type Selection Cards (Veg / Non-Veg)
                    _buildSectionHeader('1. Select Food Category'),
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

                    // 2. Quantity & Servings Count Stepper
                    _buildSectionHeader('2. Quantity & Estimated Servings'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _quantityController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Quantity Description (e.g. 50 Meals / 10 Large Trays)',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.scale_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Meal Impact Servings',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    'How many people can this feed?',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (_servingsCount > 0) {
                                        setState(() => _servingsCount -= 5);
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
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _servingsCount += 5);
                                    },
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 30),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Food Condition Photo Upload
                    _buildSectionHeader('3. Food Condition Photo'),
                    const SizedBox(height: 12),
                    _buildPhotoUploadContainer(),
                    const SizedBox(height: 24),

                    // 4. Pickup Address & Google Maps Location Selector (No False Thirthahalli Assumptions)
                    _buildSectionHeader('4. Pickup Address & Location Pin'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            style: const TextStyle(color: AppColors.textPrimary),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter or select pickup address' : null,
                            decoration: InputDecoration(
                              labelText: 'Pickup Address',
                              hintText: 'Search area or drop pin on map to set pickup location',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isGettingLocation ? null : _getCurrentLocation,
                              icon: _isGettingLocation
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded, color: AppColors.primary),
                              label: Text(
                                _isGettingLocation ? 'Resolving GPS Address...' : 'Fetch Device GPS Location Pin',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. Select Registered NGO Partner with Name, Address, & Mobile Number
                    _buildSectionHeader('5. Select Verified NGO Partner'),
                    const SizedBox(height: 12),
                    _buildNgoSelectionDropdown(),
                    const SizedBox(height: 24),

                    // 6. Pickup & Expiry Time Window Pickers
                    _buildSectionHeader('6. Logistics Time Windows'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerCard(
                            title: 'Pickup Window',
                            value: _formatDateTime(_pickupDateTime),
                            icon: Icons.access_time_rounded,
                            onTap: () => _selectDateTime(context, true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePickerCard(
                            title: 'Expiry Window',
                            value: _formatDateTime(_expiryDateTime),
                            icon: Icons.timer_outlined,
                            onTap: () => _selectDateTime(context, false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 7. Additional Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Special Handling / Preparation Notes (Optional)',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 8. Food Safety Governance Checkbox
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _termsAcknowledged ? AppColors.primary : AppColors.borderLight),
                      ),
                      child: Material(
                        color: _termsAcknowledged ? AppColors.primaryTint.withValues(alpha: 0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: CheckboxListTile(
                            activeColor: AppColors.primary,
                            title: const Text(
                              'Food Safety Governance & Hygiene Agreement',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            subtitle: const Text(
                              'Tap to read & acknowledge food safety standards before submission.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                            : const Text(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
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
                  const Icon(Icons.notifications_none, color: Colors.white, size: 24),
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
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFoodCategoryCard(String label, IconData icon, Color iconColor) {
    final isSelected = _selectedFoodCategory == label;

    return InkWell(
      onTap: () => setState(() => _selectedFoodCategory = label),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint.withValues(alpha: 0.4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
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
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoUploadContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
            const Text(
              'Upload Fresh Food Photo',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Required for quality verification by pickup volunteers',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

  /// NGO Selection Dropdown with Real Name, Address, & Mobile Number
  Widget _buildNgoSelectionDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .snapshots(),
      builder: (context, snapshot) {
        final List<Map<String, String>> ngoList = [
          {
            'name': 'Auto-Assign Nearest NGO',
            'address': 'Closest verified NGO based on location pin',
            'phone': '+91 1800-SAHYOG',
          },
        ];

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final role = (data['role'] ?? '').toString().toLowerCase();
            if (role == 'ngo') {
              final name = (data['name'] ?? data['fullName'] ?? data['ngoName'] ?? data['organizationName'] ?? '').toString().trim();
              final address = (data['address'] ?? data['location'] ?? data['ngoAddress'] ?? 'Verified Local NGO Partner').toString().trim();
              final phone = (data['phone'] ?? data['phoneNumber'] ?? data['mobile'] ?? '+91 Verified Partner').toString().trim();

              if (name.isNotEmpty && !ngoList.any((element) => element['name'] == name)) {
                ngoList.add({
                  'name': name,
                  'address': address,
                  'phone': phone,
                });
              }
            }
          }
        }

        final selectedNgo = ngoList.firstWhere(
          (element) => element['name'] == _selectedNgoOption,
          orElse: () => ngoList.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedNgo['name'],
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  dropdownColor: Colors.white,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      final matched = ngoList.firstWhere((element) => element['name'] == newValue);
                      setState(() {
                        _selectedNgoOption = newValue;
                        _selectedNgoAddress = matched['address'] ?? '';
                        _selectedNgoPhone = matched['phone'] ?? '';
                      });
                    }
                  },
                  items: ngoList.map<DropdownMenuItem<String>>((Map<String, String> ngo) {
                    final isAuto = ngo['name'] == 'Auto-Assign Nearest NGO';
                    return DropdownMenuItem<String>(
                      value: ngo['name'],
                      child: Row(
                        children: [
                          Icon(
                            isAuto ? Icons.auto_awesome : Icons.domain,
                            size: 20,
                            color: isAuto ? AppColors.primary : AppColors.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ngo['name']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
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
            if (selectedNgo['name'] != 'Auto-Assign Nearest NGO') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Address: ${selectedNgo['address']}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Mobile: ${selectedNgo['phone']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTimePickerCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
