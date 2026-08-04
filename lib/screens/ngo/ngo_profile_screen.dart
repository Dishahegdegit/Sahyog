import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/ngo/ngo_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';

class NgoProfileScreen extends StatefulWidget {
  const NgoProfileScreen({super.key});

  @override
  State<NgoProfileScreen> createState() => _NgoProfileScreenState();
}

class _NgoProfileScreenState extends State<NgoProfileScreen> {
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
  void _initFields(NgoModel ngo) {
    if (_fieldsInitialised && _isEditing) return;
    _fieldsInitialised = true;
    _nameController.text = ngo.name;
    _regController.text = ngo.registrationNumber;
    _addressController.text = ngo.address;
    _phoneController.text = ngo.phone;
    _emailController.text = ngo.email;
    _workingAreasController.text = ngo.workingAreas.join(', ');
    if (_selectedImageBytes == null && (_profileImageUrl.isEmpty || !_isEditing)) {
      _profileImageUrl = ngo.profileImageUrl;
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
            backgroundColor: AppColors.secondaryContainer,
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
    );

    await _firestoreService.saveNgoProfile(updatedModel);

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.secondaryContainer,
          content: Text(
            'Profile saved successfully!',
            style: GoogleFonts.publicSans(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNgoId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NGO Profile'),
        actions: [
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
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppColors.primary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: AppColors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.surfaceContainerHighest, width: 1),
                    ),
                    title: Text(
                      'Confirm Logout',
                      style: GoogleFonts.publicSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to log out?',
                      style: GoogleFonts.publicSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.publicSans(
                            color: AppColors.textSecondary,
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
                        child: const Text('Yes'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
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
              );

              _initFields(ngo);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                          color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // ── Verification Badge
                    _buildVerificationBadge(ngo.verificationStatus),

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
                  ],
                ),
              );
            },
          );
        },
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
            color: AppColors.surfaceContainerHigh,
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
          return const Icon(Icons.domain, size: 50, color: AppColors.outline);
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
    return const Icon(Icons.domain, size: 50, color: AppColors.outline);
  }

  // ── VERIFICATION BADGE ────────────────────────────────────────────────────

  Widget _buildVerificationBadge(String status) {
    final bool isApproved = status.toLowerCase() == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isApproved
            ? const Color(0xFF1D514F)
            : const Color(0xFFC49100).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApproved ? AppColors.secondary : AppColors.tertiary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.verified_outlined : Icons.pending_actions_outlined,
            size: 16,
            color: isApproved ? AppColors.secondary : AppColors.tertiary,
          ),
          const SizedBox(width: 6),
          Text(
            isApproved ? 'VERIFIED NGO (APPROVED)' : 'VERIFICATION PENDING',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isApproved ? AppColors.secondary : AppColors.tertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── DETAILS CARD ──────────────────────────────────────────────────────────

  Widget _buildDetailsCard(NgoModel ngo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organization Details',
            style: GoogleFonts.publicSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Edit your details and tap Save Changes',
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
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
          _buildField(
            label: 'Official Address',
            controller: _addressController,
            icon: Icons.location_on_outlined,
            maxLines: 2,
          ),
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

  Widget _buildDivider() =>
      const Divider(color: AppColors.surfaceContainerHighest, height: 24);

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
        style: GoogleFonts.publicSans(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.outline, size: 20),
        ),
      );
    }

    // View mode — only show if value exists, else show a subtle empty state
    final value = controller.text.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              value.isNotEmpty
                  ? Text(
                      value,
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      'Tap Edit to add',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.outline,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
