import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/donor/donor_profile.dart';
import '../../providers/theme_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/donor_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../auth/login_screen.dart';

import '../legal/terms_screen.dart';
import '../legal/food_safety_screen.dart';
import '../legal/privacy_screen.dart';
import '../legal/tax_receipts_screen.dart';
import '../legal/impact_screen.dart';
import '../legal/support_screen.dart';

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

  final _nameController = TextEditingController();
  final _orgController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String _entityType = 'Individual Donor';

  String _defaultFoodType = 'Veg';
  bool _notifyOnPickup = true;
  bool _notifyOnDelivery = true;

  XFile? _selectedXFile;
  Uint8List? _selectedImageBytes;

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source) async {
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
          _isUploadingPhoto = true;
        });

        if (_selectedXFile != null) {
          // Photo selected successfully
        }

        final photoUrl = await _cloudinaryService.uploadImage(image);
        if (photoUrl != null && photoUrl.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _profileService.updateProfileImage(user.uid, photoUrl);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile picture updated successfully!'),
                  backgroundColor: AppColors.statusDelivered,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showPhotoSourceDialog() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text('Take Photo from Camera', style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Choose from Gallery', style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfilePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(String uid, String email, String? currentPhotoUrl) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final updatedProfile = DonorProfile(
        uid: uid,
        fullName: _nameController.text.trim(),
        organizationName: _orgController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: email,
        address: _addressController.text.trim(),
        profileImageUrl: currentPhotoUrl ?? '',
      );

      await _profileService.saveProfile(updatedProfile);
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.statusDelivered),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final c = context.colors;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Confirm Logout',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of your Sahyog Donor Account?',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Open Legal & Support Modal with Full Page Routes
  void _showLegalAndSupportMenu(BuildContext context) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.folder_special_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Legal & Support Resources', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                ],
              ),
            ),
            Divider(color: c.borderLight, height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.primary),
              title: Text('Terms & Conditions', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined, color: AppColors.primary),
              title: Text('Food Safety Standards', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FoodSafetyScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.security_outlined, color: AppColors.primary),
              title: Text('Privacy Policy', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              title: Text('80G Tax Exemption Receipts', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TaxReceiptsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
              title: Text('Impact & Achievements', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ImpactAchievementsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
              title: Text('Support & Help Center', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportFaqScreen()));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final c = context.colors;

    if (user == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: Text('Please log in to view your profile.', style: TextStyle(color: c.textPrimary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Donor Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          // Grouped 3-Dot (⋮) Menu under "Legal & Support"
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'legal_support') {
                _showLegalAndSupportMenu(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'legal_support',
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Legal & Support', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DonorProfile?>(
        stream: _profileService.getProfileStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final profile = snapshot.data;
          final currentPhotoUrl = profile?.profileImageUrl ?? user.photoURL ?? '';

          if (!_isEditing && profile != null) {
            _nameController.text = profile.fullName;
            _orgController.text = profile.organizationName;
            _phoneController.text = profile.phoneNumber;
            _addressController.text = profile.address;
          } else if (!_isEditing && profile == null) {
            _nameController.text = user.displayName ?? '';
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.of(context).pagePadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.of(context).isCompact ? double.infinity : 700,
                ),
                child: Column(
                  children: [
                    _buildImprovedProfileHeader(user, currentPhotoUrl, profile),
                    SizedBox(height: Responsive.of(context).sectionGap),

                    _buildPersonalDetailsCard(user, currentPhotoUrl),
                    const SizedBox(height: 20),

                    _buildPreferencesCard(),
                    const SizedBox(height: 20),

                    _buildAppearanceCard(),
                    const SizedBox(height: 20),

                    _buildSavedLocationsCard(),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: const Icon(Icons.logout, color: AppColors.error),
                        label: const Text('Logout of Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImprovedProfileHeader(User user, String photoUrl, DonorProfile? profile) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.primaryTint,
                  backgroundImage: _selectedImageBytes != null
                      ? MemoryImage(_selectedImageBytes!)
                      : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null) as ImageProvider?,
                  child: photoUrl.isEmpty && _selectedImageBytes == null
                      ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                      : null,
                ),
              ),
              if (_isUploadingPhoto)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _showPhotoSourceDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : (profile?.fullName ?? user.displayName ?? 'Sahyog Donor'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email ?? '',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _entityType == 'Corporate Entity' ? Icons.business : Icons.person,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _entityType,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsCard(User user, String photoUrl) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.primary),
                  onPressed: () {
                    setState(() => _isEditing = !_isEditing);
                  },
                ),
              ],
            ),
            Divider(color: c.outlineVariant, height: 20),

            TextFormField(
              controller: _nameController,
              enabled: _isEditing,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _orgController,
              enabled: _isEditing,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Organization / Restaurant Name (Optional)',
                prefixIcon: Icon(Icons.business_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressController,
              enabled: _isEditing,
              maxLines: 2,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Default Pickup Address',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),

            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : () => _saveProfile(user.uid, user.email ?? '', photoUrl),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Donor Preferences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            Divider(color: c.outlineVariant, height: 20),

            ListTile(
              title: Text('Default Food Category', style: TextStyle(color: c.textPrimary)),
              trailing: DropdownButton<String>(
                value: _defaultFoodType,
                dropdownColor: c.surface,
                items: ['Veg', 'Non-Veg'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _defaultFoodType = v!),
              ),
            ),
            SwitchListTile(
              activeTrackColor: AppColors.primaryTint,
              activeThumbColor: AppColors.primary,
              title: Text('Notify on Volunteer Pickup', style: TextStyle(color: c.textPrimary)),
              value: _notifyOnPickup,
              onChanged: (v) => setState(() => _notifyOnPickup = v),
            ),
            SwitchListTile(
              activeTrackColor: AppColors.primaryTint,
              activeThumbColor: AppColors.primary,
              title: Text('Notify on Delivery Completion', style: TextStyle(color: c.textPrimary)),
              value: _notifyOnDelivery,
              onChanged: (v) => setState(() => _notifyOnDelivery = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceCard() {
    final c = context.colors;
    return Consumer(
      builder: (context, ref, _) {
        final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              Divider(color: c.outlineVariant, height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primaryTint,
                activeThumbColor: AppColors.primary,
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  isDark ? 'Dark theme' : 'Light theme',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
                subtitle: Text(
                  isDark ? 'Using dark mode' : 'Using light mode',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                value: isDark,
                onChanged: (enabled) {
                  ref.read(themeModeProvider.notifier).setDark(enabled);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedLocationsCard() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Pickup Locations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address management feature ready!')),
                    );
                  },
                ),
              ],
            ),
            Divider(color: c.outlineVariant, height: 20),
            ListTile(
              leading: const Icon(Icons.home, color: AppColors.primary),
              title: Text('Primary Address', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
              subtitle: Text(
                _addressController.text.isNotEmpty ? _addressController.text : 'No address saved yet',
                style: TextStyle(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
