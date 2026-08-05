import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

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

  static const primaryOrange = Color(0xFFFF5E2B);
  static const darkCardBg = Color(0xFF222629);
  static const darkBorderColor = Color(0xFF2A2F33);

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
      backgroundColor: darkCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryOrange),
              title: const Text('Take Photo from Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryOrange),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Reverse Geocode Current GPS Position into Real Street Address
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable GPS.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _selectedLat = position.latitude;
      _selectedLng = position.longitude;

      // Fetch Real Street Address via Reverse Geocoding API
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');
        final response = await http.get(url, headers: {'User-Agent': 'SahyogApp/1.0'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            setState(() {
              _addressController.text = displayName;
            });
          }
        }
      } catch (_) {
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = 'Location Pin (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exact location address fetched successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  /// Combined Date & Time Picker for Pickup Window and Expiry Time
  Future<void> _selectDateTime(BuildContext context, bool isPickup) async {
    final initialDate = isPickup
        ? (_pickupDateTime ?? DateTime.now())
        : (_expiryDateTime ?? DateTime.now());

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryOrange,
              onPrimary: Colors.white,
              surface: darkCardBg,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: primaryOrange,
                onPrimary: Colors.white,
                surface: darkCardBg,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
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

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_servingsCount <= 0 && _quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter food quantity or number of servings.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedXFile == null || _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture a food photo before submitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_pickupDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Pickup Date & Time.')),
      );
      return;
    }

    if (_expiryDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Expiry Date & Time.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a donation.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isUploadingImage = true;
    });

    try {
      final uploadedUrl = await _cloudinaryService.uploadImage(_selectedXFile!);
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw 'Image upload failed. Please try again.';
      }

      setState(() {
        _isUploadingImage = false;
      });

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
        notes: _notesController.text.trim(),
        imageUrl: uploadedUrl,
        status: 'pending',
      );

      await FirebaseFirestore.instance
          .collection('donations')
          .add(donation.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food donation request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission Error: $e'),
            backgroundColor: Colors.red,
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
      _selectedXFile = null;
      _selectedImageBytes = null;
      _selectedLat = null;
      _selectedLng = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Universal Top Bar
                    _buildTopAppBar(user),
                    const SizedBox(height: 24),

                    // Clean Screen Header ("New Donation") - Removed STEP 1 OF 3
                    const Text(
                      'New Donation',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 1: WHAT ARE YOU DONATING?
                    _buildSectionHeader('WHAT ARE YOU DONATING?'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectableFoodCard(
                            label: 'Vegetarian',
                            icon: Icons.eco_outlined,
                            categoryKey: 'Veg',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSelectableFoodCard(
                            label: 'Non-Veg',
                            icon: Icons.kebab_dining_outlined,
                            categoryKey: 'Non-Veg',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // SECTION 2: IMPACT & QUANTITY
                    _buildSectionHeader('IMPACT & QUANTITY'),
                    const SizedBox(height: 12),
                    _buildQuantityStepperCard(),
                    const SizedBox(height: 28),

                    // SECTION 3: FOOD CONDITION & PHOTO
                    _buildSectionHeader('FOOD CONDITION'),
                    const SizedBox(height: 12),
                    _buildPhotoUploadCard(),
                    const SizedBox(height: 28),

                    // Pickup Address & Map Location
                    _buildSectionHeader('PICKUP LOCATION & TIME'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Pickup Address / Real Location *',
                        labelStyle: const TextStyle(color: Color(0xFF8C959E)),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: primaryOrange),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: darkCardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: darkBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: darkBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryOrange, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: _isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryOrange),
                                )
                              : const Icon(Icons.my_location, color: primaryOrange),
                          tooltip: 'Select Location from GPS Map Address',
                          onPressed: _isGettingLocation ? null : _getCurrentLocation,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter pickup address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pickup & Expiry Date/Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDateTime(context, true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: darkCardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: darkBorderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: primaryOrange, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pickup Date & Time *', style: TextStyle(fontSize: 11, color: Color(0xFF8C959E))),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateTime(_pickupDateTime),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _pickupDateTime != null ? Colors.white : const Color(0xFF8C959E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDateTime(context, false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: darkCardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: darkBorderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, color: primaryOrange, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Expiry Date & Time *', style: TextStyle(fontSize: 11, color: Color(0xFF8C959E))),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateTime(_expiryDateTime),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _expiryDateTime != null ? Colors.white : const Color(0xFF8C959E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
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

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.volunteer_activism, color: primaryOrange, size: 22),
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
                    border: Border.all(color: primaryOrange.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryOrange.withValues(alpha: 0.3),
                    backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                    child: profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF8C959E),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSelectableFoodCard({
    required String label,
    required IconData icon,
    required String categoryKey,
  }) {
    final isSelected = _selectedFoodCategory == categoryKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFoodCategory = categoryKey;
          });
        },
        hoverColor: primaryOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: darkCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryOrange : darkBorderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryOrange.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 36,
                color: isSelected ? primaryOrange : const Color(0xFF8C959E),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF8C959E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityStepperCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkBorderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'People it can\nserve',
                style: TextStyle(fontSize: 15, color: Color(0xFF8C959E), height: 1.3),
              ),
              Row(
                children: [
                  _buildStepperButton(
                    icon: Icons.remove,
                    onTap: () {
                      if (_servingsCount > 0) {
                        setState(() {
                          _servingsCount--;
                          _quantityController.text = _servingsCount > 0 ? '$_servingsCount meals' : '';
                        });
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      '$_servingsCount',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: primaryOrange,
                      ),
                    ),
                  ),
                  _buildStepperButton(
                    icon: Icons.add,
                    onTap: () {
                      setState(() {
                        _servingsCount++;
                        _quantityController.text = '$_servingsCount meals';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: darkBorderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volunteer_activism_outlined, size: 16, color: primaryOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _servingsCount > 0
                      ? 'THIS DONATION PROVIDES A FULL MEAL FOR $_servingsCount NEIGHBORS.'
                      : 'ENTER OR SELECT NUMBER OF SERVINGS TO VIEW MEAL IMPACT.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8C959E),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: primaryOrange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A2F33),
            border: Border.all(color: darkBorderColor),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPhotoUploadCard() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedImageBytes == null ? darkBorderColor : primaryOrange,
          width: _selectedImageBytes == null ? 1 : 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showImageSourceDialog,
          hoverColor: primaryOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          child: _selectedImageBytes != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _selectedImageBytes!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                          onPressed: _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_a_photo_outlined, size: 42, color: primaryOrange),
                    SizedBox(height: 10),
                    Text(
                      'Upload or Take Photo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
