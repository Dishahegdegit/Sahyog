import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/donor/donor_profile.dart';
import '../../services/donor_profile_service.dart';
import '../../services/cloudinary_service.dart';
import '../auth/login_screen.dart';

class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DonorProfileService _profileService = DonorProfileService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  static const primaryOrange = Color(0xFFFF5E2B);
  static const darkCardBg = Color(0xFF222629);
  static const darkBorderColor = Color(0xFF2A2F33);

  // Text Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _organizationNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isUploadingPhoto = false;

  String _profileImageUrl = '';
  XFile? _newProfileXFile;
  Uint8List? _profileImageBytes;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    _uid = currentUser.uid;
    _emailController.text = currentUser.email ?? '';

    try {
      final profile = await _profileService.getProfile(_uid!);
      if (profile != null) {
        _fullNameController.text = profile.fullName;
        _organizationNameController.text = profile.organizationName;
        _phoneController.text = profile.phoneNumber;
        if (profile.email.isNotEmpty) {
          _emailController.text = profile.email;
        }
        _addressController.text = profile.address;
        _profileImageUrl = profile.profileImageUrl;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
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
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryOrange),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 75,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _newProfileXFile = image;
          _profileImageBytes = bytes;
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_profileImageUrl.isEmpty && _newProfileXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mandatory: Please select a profile photo before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? _uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user found.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String finalImageUrl = _profileImageUrl;

      if (_newProfileXFile != null) {
        setState(() {
          _isUploadingPhoto = true;
        });
        final uploadedUrl = await _cloudinaryService.uploadImage(_newProfileXFile!);
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalImageUrl = uploadedUrl;
        } else {
          throw 'Profile photo upload failed. Please try again.';
        }
        setState(() {
          _isUploadingPhoto = false;
        });
      }

      final updatedProfile = DonorProfile(
        uid: uid,
        fullName: _fullNameController.text.trim(),
        organizationName: _organizationNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        profileImageUrl: finalImageUrl,
      );

      await FirebaseFirestore.instance
          .collection('donors')
          .doc(uid)
          .set(updatedProfile.toMap(), SetOptions(merge: true));

      setState(() {
        _profileImageUrl = finalImageUrl;
        _newProfileXFile = null;
        _profileImageBytes = null;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkCardBg,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryOrange))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Universal Top Bar
                        _buildTopAppBar(currentUser),
                        const SizedBox(height: 24),

                        // Body View
                        _isEditing ? _buildEditProfileForm(isWide) : _buildCleanProfileView(isWide),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTopAppBar(User? user) {
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
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCleanProfileView(bool isWide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkBorderColor),
      ),
      child: Column(
        children: [
          // Profile Photo & Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryOrange, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: primaryOrange.withValues(alpha: 0.2),
                    backgroundImage: _profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) : null,
                    child: _profileImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 55, color: primaryOrange)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _fullNameController.text.isEmpty ? 'Donor Name' : _fullNameController.text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_organizationNameController.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryOrange),
                    ),
                    child: Text(
                      _organizationNameController.text,
                      style: const TextStyle(color: primaryOrange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Divider(color: darkBorderColor),
          const SizedBox(height: 16),

          // Profile Info Tiles
          _buildInfoTile(Icons.email_outlined, 'Email Address', _emailController.text),
          _buildInfoTile(Icons.phone_outlined, 'Phone Number', _phoneController.text),
          _buildInfoTile(Icons.location_on_outlined, 'Address', _addressController.text),
          _buildInfoTile(
            Icons.business_outlined,
            'Organization',
            _organizationNameController.text.isEmpty ? 'Individual Donor' : _organizationNameController.text,
          ),
          const SizedBox(height: 24),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileForm(bool isWide) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Photo Picker with Camera Icon
          Center(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryOrange, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryOrange.withValues(alpha: 0.2),
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : (_profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) as ImageProvider : null),
                    child: (_profileImageBytes == null && _profileImageUrl.isEmpty)
                        ? const Icon(Icons.person, size: 50, color: primaryOrange)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: primaryOrange,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      onPressed: _pickProfileImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Profile Photo * (Mandatory)',
              style: TextStyle(color: primaryOrange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),

          _buildStyledTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 16),

          _buildStyledTextField(
            controller: _fullNameController,
            label: 'Full Name *',
            icon: Icons.person_outline,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your full name' : null,
          ),
          const SizedBox(height: 16),

          _buildStyledTextField(
            controller: _phoneController,
            label: 'Phone Number *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your phone number' : null,
          ),
          const SizedBox(height: 16),

          _buildStyledTextField(
            controller: _organizationNameController,
            label: 'Organization Name (Optional)',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 16),

          _buildStyledTextField(
            controller: _addressController,
            label: 'Address *',
            icon: Icons.location_on_outlined,
            maxLines: 3,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your address' : null,
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: darkBorderColor),
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _newProfileXFile = null;
                      _profileImageBytes = null;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: (_isSaving || _isUploadingPhoto) ? null : _saveProfile,
                  child: (_isSaving || _isUploadingPhoto)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8C959E)),
        prefixIcon: Icon(icon, color: primaryOrange),
        alignLabelWithHint: maxLines > 1,
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
      ),
      validator: validator,
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8C959E)),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not Provided' : value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
