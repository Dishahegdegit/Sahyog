import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/ngo_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../auth/login_screen.dart';

class NgoProfileScreen extends ConsumerStatefulWidget {
  const NgoProfileScreen({super.key});

  @override
  ConsumerState<NgoProfileScreen> createState() => _NgoProfileScreenState();
}

class _NgoProfileScreenState extends ConsumerState<NgoProfileScreen> {
  NgoTheme get t => NgoTheme.of(context);

  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  bool _isEditing = false;
  bool _isUploading = false;
  bool _fieldsInitialised = false;

  final _nameController = TextEditingController();
  final _regController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _workingAreasController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String _profileImageUrl = '';

  String get _currentNgoId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  double? _lat;
  double? _lng;
  bool _isGettingLocation = false;
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _nameController.dispose();
    _regController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _workingAreasController.dispose();
    super.dispose();
  }

  /// Only populate controllers once on first load, and again when NOT editing.
  void _initFields(NgoModel ngo, Map<String, dynamic> ngoData) {
    if (_fieldsInitialised && _isEditing) return;
    _fieldsInitialised = true;
    _nameController.text = ngo.name;
    _regController.text = ngo.registrationNumber;

    final cleanedAddress = LocationService.cleanAddress(ngo.address, fallbackName: 'Official Registered Location');
    _addressController.text = (cleanedAddress != 'Location not provided' && cleanedAddress.isNotEmpty)
        ? cleanedAddress
        : (ngo.address.isNotEmpty ? ngo.address : 'Official Registered Location');

    _phoneController.text = ngo.phone;
    _emailController.text = ngo.email;
    _workingAreasController.text = ngo.workingAreas.join(', ');
    if (_selectedImageBytes == null && (_profileImageUrl.isEmpty || !_isEditing)) {
      _profileImageUrl = ngo.profileImageUrl;
    }
    if (_lat == null && _lng == null && !_isEditing) {
      if (ngoData['latitude'] != null) {
        _lat = (ngoData['latitude'] as num).toDouble();
      }
      if (ngoData['longitude'] != null) {
        _lng = (ngoData['longitude'] as num).toDouble();
      }
      if (_lat != null && _lng != null) {
        // Reverse-geocode lat/lng to get exact venue/street/place name address
        LocationService.getAddressFromCoordinates(_lat!, _lng!).then((fetched) {
          if (fetched != null && fetched.isNotEmpty && mounted) {
            setState(() {
              _addressController.text = fetched;
            });
          }
        });
      } else if (ngo.address.isNotEmpty) {
        _geocodeAddress(ngo.address);
      }
    }
  }

  Future<void> _geocodeAddress(String address) async {
    if (address.trim().isEmpty) return;
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(address)}&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'SahyogApp/1.0'});
      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        if (list.isNotEmpty) {
          final first = list[0];
          final double lat = double.parse(first['lat'].toString());
          final double lon = double.parse(first['lon'].toString());
          setState(() {
            _lat = lat;
            _lng = lon;
          });
          _mapController.move(LatLng(lat, lon), 15.0);
        }
      }
    } catch (_) {}
  }

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

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw 'Could not determine GPS position';
      }

      setState(() {
        _lat = position!.latitude;
        _lng = position.longitude;
        _isGettingLocation = false;
      });

      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);

      // Fetch Real Street Address with Pincode via Dual-Tier Geocoding API
      final fetchedAddress = await LocationService.getAddressFromCoordinates(
          position.latitude, position.longitude);

      if (fetchedAddress != null && fetchedAddress.isNotEmpty) {
        setState(() {
          _addressController.text = fetchedAddress;
        });
      }

    } catch (e) {
      // Graceful fallback to default demo location (Mumbai CST) if GPS/permission fails
      final double fallbackLat = 19.0760;
      final double fallbackLng = 72.8777;

      setState(() {
        _lat = fallbackLat;
        _lng = fallbackLng;
        _isGettingLocation = false;
      });

      _mapController.move(LatLng(fallbackLat, fallbackLng), 15.0);

      final fallbackAddress = await LocationService.getAddressFromCoordinates(fallbackLat, fallbackLng);
      if (fallbackAddress != null && fallbackAddress.isNotEmpty) {
        setState(() {
          _addressController.text = fallbackAddress;
        });
      } else if (_addressController.text.trim().isEmpty) {
        _addressController.text = "Chhatrapati Shivaji Terminus Area, Fort, Mumbai, Maharashtra, PIN: 400001";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Location services unavailable. Used demo location (Mumbai).',
              style: GoogleFonts.publicSans(color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();

      setState(() {
        _selectedImageBytes = bytes;
        _isUploading = true;
      });

      String? newUrl;
      try {
        newUrl = await _cloudinaryService.uploadImageBytes(bytes, filename: picked.name);
      } catch (_) {
        newUrl = null;
      }

      if (newUrl == null || newUrl.isEmpty) {
        final base64Str = base64Encode(bytes);
        newUrl = 'data:image/jpeg;base64,$base64Str';
      }

      setState(() {
        _profileImageUrl = newUrl!;
        _isUploading = false;
      });

      // Auto-save updated profile image to Firestore so it persists immediately
      if (_currentNgoId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('ngos')
            .doc(_currentNgoId)
            .set({'profileImageUrl': _profileImageUrl}, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentNgoId)
            .set({'profileImageUrl': _profileImageUrl}, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Profile photo updated!',
              style: GoogleFonts.publicSans(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              'Failed to select image from gallery: $e',
              style: GoogleFonts.publicSans(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile(NgoModel currentNgo) async {
    final updatedAreas = _workingAreasController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final updatedModel = currentNgo.copyWith(
      name: _nameController.text.trim(),
      registrationNumber: _regController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      profileImageUrl: _profileImageUrl,
      workingAreas: updatedAreas,
      latitude: _lat,
      longitude: _lng,
    );

    await _firestoreService.saveNgoProfile(updatedModel);

    // Also persist lat/lng
    if (_currentNgoId.isNotEmpty && _lat != null && _lng != null) {
      await FirebaseFirestore.instance.collection('ngos').doc(_currentNgoId).set({
        'latitude': _lat,
        'longitude': _lng,
      }, SetOptions(merge: true));
    }

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text(
            'Profile saved successfully!',
            style: GoogleFonts.publicSans(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: t.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: t.surfaceContainerHighest, width: 1),
          ),
          title: Text(
            'Confirm Logout',
            style: GoogleFonts.publicSans(
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.publicSans(
              fontSize: 14,
              color: t.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.publicSans(
                  color: t.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(72, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: GoogleFonts.publicSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final nav = Navigator.of(context);
                Navigator.of(dialogContext).pop();
                await FirebaseAuth.instance.signOut();
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNgoId.isEmpty) {
      return Scaffold(
        backgroundColor: t.background,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.background,
      appBar: null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ngos')
            .doc(_currentNgoId)
            .snapshots(),
        builder: (context, ngoSnap) {
          // Also read from users collection for registration name/email fallback
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentNgoId)
                .snapshots(),
            builder: (context, userSnap) {
              if (ngoSnap.connectionState == ConnectionState.waiting ||
                  userSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              // Build NgoModel from Firestore data — no dummy fallbacks
              final ngoData = (ngoSnap.hasData && ngoSnap.data!.exists)
                  ? ngoSnap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};
              final userData = (userSnap.hasData && userSnap.data!.exists)
                  ? userSnap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

              // Name priority: ngo doc > users doc > Firebase Auth displayName
              final resolvedName = (ngoData['name'] as String? ?? '').isNotEmpty
                  ? ngoData['name'] as String
                  : (userData['name'] as String? ?? '').isNotEmpty
                      ? userData['name'] as String
                      : FirebaseAuth.instance.currentUser?.displayName ?? '';

              // Email priority: ngo doc > users doc > Firebase Auth email
              final resolvedEmail = (ngoData['email'] as String? ?? '').isNotEmpty
                  ? ngoData['email'] as String
                  : (userData['email'] as String? ??
                      FirebaseAuth.instance.currentUser?.email ?? '');

              final ngo = NgoModel(
                id: _currentNgoId,
                name: resolvedName,
                registrationNumber: ngoData['registrationNumber'] as String? ?? '',
                address: ngoData['address'] as String? ?? '',
                phone: ngoData['phone'] as String? ?? '',
                email: resolvedEmail,
                profileImageUrl: ngoData['profileImageUrl'] as String? ?? '',
                workingAreas: ngoData['workingAreas'] != null
                    ? List<String>.from(ngoData['workingAreas'] as List)
                    : [],
                verificationStatus:
                    ngoData['verificationStatus'] as String? ?? 'Pending',
                latitude: ngoData['latitude'] != null ? (ngoData['latitude'] as num).toDouble() : null,
                longitude: ngoData['longitude'] != null ? (ngoData['longitude'] as num).toDouble() : null,
              );

              _initFields(ngo, ngoData);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // NGO Profile Title & Edit/Cancel Button Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                              'NGO Profile',
                              style: GoogleFonts.publicSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: t.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = !_isEditing;
                              if (!_isEditing) _fieldsInitialised = false;
                            });
                          },
                          icon: Icon(
                            _isEditing ? Icons.close : Icons.edit_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            _isEditing ? 'Cancel' : 'Edit',
                            style: GoogleFonts.publicSans(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Profile Photo
                    _buildAvatar(),
                    const SizedBox(height: 12),

                    // ── NGO Name below avatar (from resolved data)
                    if (ngo.name.isNotEmpty)
                      Text(
                        ngo.name,
                        style: GoogleFonts.publicSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: t.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (ngo.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          ngo.email,
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 24),

                    // ── Organisation Details Card
                    _buildDetailsCard(ngo),

                    const SizedBox(height: 20),

                    // ── Save Button (Edit mode only)
                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _saveProfile(ngo),
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            'SAVE CHANGES',
                            style: GoogleFonts.publicSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── App Theme Preference Card
                    _buildThemeCard(),

                    const SizedBox(height: 24),

                    // ── Logout Button (always visible at bottom)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogoutDialog(),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        label: Text(
                          'LOG OUT',
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── THEME PREFERENCE CARD ───────────────────────────────────────────────

  Widget _buildThemeCard() {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkPrimary.withValues(alpha: 0.18) : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeColor: AppColors.primary,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
    );
  }

  // ── AVATAR WIDGET ─────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.surfaceContainerHigh,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: ClipOval(
            child: _buildAvatarImage(),
          ),
        ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (_selectedImageBytes != null && _selectedImageBytes!.isNotEmpty) {
      return Image.memory(_selectedImageBytes!, fit: BoxFit.cover);
    }
    if (_profileImageUrl.isNotEmpty) {
      if (_profileImageUrl.startsWith('data:image') ||
          (!_profileImageUrl.startsWith('http') && _profileImageUrl.contains('base64,'))) {
        try {
          final base64Data = _profileImageUrl.contains('base64,')
              ? _profileImageUrl.split('base64,').last
              : _profileImageUrl;
          final bytes = base64Decode(base64Data);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.domain, size: 50, color: AppColors.primary),
          );
        } catch (_) {
          return Icon(Icons.domain, size: 50, color: t.outline);
        }
      }
      if (_profileImageUrl.startsWith('http://') || _profileImageUrl.startsWith('https://')) {
        return Image.network(
          _profileImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.domain, size: 50, color: AppColors.primary),
        );
      }
    }
    return Icon(Icons.domain, size: 50, color: t.outline);
  }

  // ── VERIFICATION BADGE ────────────────────────────────────────────────────


  // ── DETAILS CARD ──────────────────────────────────────────────────────────

  Widget _buildDetailsCard(NgoModel ngo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organization Details',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Edit your details and tap Save Changes',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: t.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildField(
            label: 'NGO / Organization Name',
            controller: _nameController,
            icon: Icons.business_outlined,
          ),
          _buildDivider(),
          _buildField(
            label: 'Registration Number',
            controller: _regController,
            icon: Icons.verified_user_outlined,
          ),
          _buildDivider(),
          // ── Official Address with Map ──────────────────────────────────────
          _buildAddressWithMap(),
          _buildDivider(),
          _buildField(
            label: 'Phone Contact',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _buildDivider(),
          _buildField(
            label: 'Official Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          _buildDivider(),
          _buildField(
            label: 'Working Areas',
            controller: _workingAreasController,
            icon: Icons.map_outlined,
            hint: 'e.g. Downtown, North Zone',
          ),
        ],
      ),
    );
  }

  Widget _buildAddressWithMap() {
    final hasPin = _lat != null && _lng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row with icon
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: t.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official Address',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isEditing)
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      style: GoogleFonts.publicSans(
                        color: t.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Street address, area, city...',
                        hintStyle: GoogleFonts.publicSans(color: t.textHint),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 0),
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                          onPressed: () => _geocodeAddress(_addressController.text),
                          tooltip: 'Find on map',
                        ),
                      ),
                    )
                  else
                    Text(
                      _addressController.text.trim().isNotEmpty
                          ? LocationService.cleanAddress(_addressController.text, fallbackName: 'Official Registered Location')
                          : 'Official Registered Location',
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Use Current Location button (always shown)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGettingLocation ? null : _getCurrentLocation,
            icon: _isGettingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.my_location, size: 16, color: AppColors.primary),
            label: Text(
              _isGettingLocation ? 'Getting location...' : 'Use Current Location',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // Google Map Preview (using flutter_map)
        if (hasPin) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_lat!, _lng!),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.sahyog',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_lat!, _lng!),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider() =>
      Divider(color: t.surfaceContainerHighest, height: 24);

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    if (_isEditing) {
      return TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.publicSans(color: t.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: t.outline, size: 20),
        ),
      );
    }

    // View mode — only show if value exists, else show a subtle empty state
    final value = controller.text.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: t.outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              value.isNotEmpty
                  ? Text(
                      value,
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    )
                  : Text(
                      'Tap Edit to add',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: t.outline,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
