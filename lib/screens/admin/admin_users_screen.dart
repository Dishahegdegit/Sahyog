import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_limits.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';
  int _pageLimit = PageLimits.pageSize;

  bool _isInactive(Map<String, dynamic> data) {
    final lastLogin = data['lastLoginAt'];
    DateTime? lastActive;
    if (lastLogin != null) {
      if (lastLogin is Timestamp) {
        lastActive = lastLogin.toDate();
      } else if (lastLogin is String) {
        lastActive = DateTime.tryParse(lastLogin);
      }
    }
    if (lastActive == null) return true;
    return DateTime.now().difference(lastActive).inDays >= 90;
  }

  Future<void> _removeUser(BuildContext context, String uid, String role, String name) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        title: Text(
          'Remove Account',
          style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        content: Text(
          'Permanently remove $name from the platform? This deletes their profile data.',
          style: GoogleFonts.publicSans(fontSize: 14, color: colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(uid).delete();
      if (role == 'donor') {
        await db.collection('donors').doc(uid).delete().catchError((_) {});
      } else if (role == 'ngo') {
        await db.collection('ngos').doc(uid).delete().catchError((_) {});
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove account. Try again.')),
        );
      }
    }
  }

  void _showAddNgoDialog(BuildContext context) {
    final colors = context.colors;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final regIdController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add & Verify NGO', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: colors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'NGO Name', hintText: 'Full Organization Name', labelStyle: TextStyle(color: colors.textSecondary)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regIdController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'Registration ID', hintText: 'Official Govt ID', labelStyle: TextStyle(color: colors.textSecondary)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'Official Email', hintText: 'contact@ngo.org', labelStyle: TextStyle(color: colors.textSecondary)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'Phone Number', hintText: '+91 00000 00000', labelStyle: TextStyle(color: colors.textSecondary)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'Official Address', hintText: 'Headquarters Location', labelStyle: TextStyle(color: colors.textSecondary)),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty || regIdController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
                return;
              }
              try {
                final db = FirebaseFirestore.instance;
                final docRef = db.collection('users').doc();
                
                // Add to central users collection as APPROVED
                await docRef.set({
                  'uid': docRef.id,
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': 'ngo',
                  'status': 'approved', // Admin added NGOs are pre-approved
                  'verified': true,
                  'registrationId': regIdController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'addedBy': FirebaseAuth.instance.currentUser?.uid,
                });

                // Add to role-specific ngos collection
                await db.collection('ngos').doc(docRef.id).set({
                  'id': docRef.id,
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'address': addressController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'registrationId': regIdController.text.trim(),
                  'status': 'approved',
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${nameController.text} added and verified'), backgroundColor: AppColors.secondary),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Verify & Add'),
          ),
        ],
      ),
    );
  }

  void _showEditNgoDialog(BuildContext context, String uid, Map<String, dynamic> data) {
    final colors = context.colors;
    final nameController = TextEditingController(text: data['name'] ?? '');
    final emailController = TextEditingController(text: data['email'] ?? '');
    final addressController = TextEditingController(text: data['address'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update NGO Details', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: colors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'NGO Name', labelStyle: TextStyle(color: colors.textSecondary)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'Email Address', labelStyle: TextStyle(color: colors.textSecondary)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(labelText: 'Address', labelStyle: TextStyle(color: colors.textSecondary)),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                });
                await FirebaseFirestore.instance.collection('ngos').doc(uid).set({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'address': addressController.text.trim(),
                }, SetOptions(merge: true));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Details updated')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').limit(_pageLimit).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final role = (data['role'] ?? 'donor').toString().toLowerCase();
          final matchesSearch =
              name.contains(_searchQuery.toLowerCase()) ||
                  email.contains(_searchQuery.toLowerCase());
          final matchesRole =
              _selectedRoleFilter == 'all' || role == _selectedRoleFilter;
          final matchesStatus = switch (_selectedStatusFilter) {
            'inactive' => _isInactive(data),
            'flagged' => data['flagged'] == true,
            'banned' => data['banned'] == true,
            'verified' => role == 'donor' && data['verified'] == true,
            'unverified' => role == 'donor' && data['verified'] != true,
            _ => true,
          };
          return matchesSearch && matchesRole && matchesStatus;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform Users',
                            style: GoogleFonts.publicSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${docs.length} total registered users',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showAddNgoDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add NGO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Search Bar ──
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colors.outlineVariant),
                    ),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: colors.textHint,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: colors.textSecondary, size: 18),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Role Filter Pills (Primary) ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ('all', 'All Users'),
                        ('donor', 'Donors'),
                        ('ngo', 'NGOs'),
                        ('admin', 'Admins'),
                      ].map((entry) {
                        final role = entry.$1;
                        final label = entry.$2;
                        final isActive = _selectedRoleFilter == role;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRoleFilter = role),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? AppColors.primary : colors.outlineVariant,
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : colors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Status Filter Pills (Secondary) ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ('banned', 'Banned'),
                        ('flagged', 'Flagged'),
                        ('inactive', 'Inactive'),
                      ].map((entry) {
                        final filter = entry.$1;
                        final label = entry.$2;
                        final isActive = _selectedStatusFilter == filter;
                        return GestureDetector(
                          onTap: () => setState(() {
                            // Toggle: if already active, set to 'all'
                            _selectedStatusFilter = isActive ? 'all' : filter;
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.secondary.withValues(alpha: 0.15)
                                  : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? AppColors.secondary : colors.outlineVariant,
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive ? AppColors.secondary : colors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── User List ──
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_off_outlined,
                              size: 52,
                              color: colors.textSecondary
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Users Found',
                              style: GoogleFonts.publicSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty ||
                                      _selectedRoleFilter != 'all'
                                  ? 'Try adjusting your search or filter.'
                                  : 'Registered users will appear here.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ...filtered.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final role = (data['role'] ?? 'donor').toString();

                          Color roleColor;
                          if (role == 'ngo') {
                            roleColor = AppColors.secondary;
                          } else if (role == 'volunteer') {
                            roleColor = AppColors.tertiary;
                          } else if (role == 'admin') {
                            roleColor = Colors.purpleAccent;
                          } else {
                            roleColor = AppColors.primary;
                          }

                          final isBanned = data['banned'] == true;
                          final isFlagged = data['flagged'] == true;
                          final isVerified = data['verified'] == true;

                          Color borderColor = colors.outlineVariant;
                          double borderWidth = 1.0;
                          if (isBanned) {
                            borderColor = AppColors.error.withValues(alpha: 0.5);
                            borderWidth = 1.5;
                          } else if (isFlagged) {
                            borderColor = Colors.orange.withValues(alpha: 0.5);
                            borderWidth = 1.5;
                          } else if (isVerified) {
                            borderColor = AppColors.secondary.withValues(alpha: 0.5);
                            borderWidth = 1.5;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: borderColor,
                                  width: borderWidth,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: roleColor.withValues(alpha: 0.15),
                                    child: Icon(
                                      role == 'ngo'
                                          ? Icons.shield_outlined
                                          : role == 'volunteer'
                                              ? Icons.group_outlined
                                              : Icons.person_outline,
                                      color: roleColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? data['email'] ?? 'User',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          data['email'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (data['banned'] == true || data['flagged'] == true || data['verified'] == true || _isInactive(data)) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              if (data['verified'] == true && role == 'donor')
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.secondary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text('VERIFIED', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                                                ),
                                              if (_isInactive(data))
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text('INACTIVE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                                                ),
                                              if (data['banned'] == true)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.error.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text('BANNED', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.error)),
                                                ),
                                              if (data['flagged'] == true)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text('FLAGGED', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.orange)),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          role.toUpperCase(),
                                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: colors.outlineVariant),
                                        ),
                                        color: colors.surface,
                                        onSelected: (value) async {
                                          final uid = doc.id;
                                          final name = data['name'] ?? data['email'] ?? 'User';
                                          if (value == 'flag') {
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update({'flagged': true});
                                            await FirebaseFirestore.instance.collection('notifications').add({'title': 'Account Flagged', 'body': 'Your account has been flagged for review due to suspicious activity.', 'recipientId': uid, 'createdAt': FieldValue.serverTimestamp(), 'category': 'system'});
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name flagged')));
                                          } else if (value == 'unflag') {
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update({'flagged': false});
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name unflagged')));
                                          } else if (value == 'ban') {
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update({'banned': true});
                                            await FirebaseFirestore.instance.collection('notifications').add({'title': 'Account Banned', 'body': 'Your account has been suspended for violating platform policies.', 'recipientId': uid, 'createdAt': FieldValue.serverTimestamp(), 'category': 'system'});
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name banned')));
                                          } else if (value == 'unban') {
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update({'banned': false});
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name unbanned')));
                                          } else if (value == 'verify') {
                                            final updateData = {'verified': true, 'status': 'approved'};
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);
                                            if (role == 'ngo') {
                                              await FirebaseFirestore.instance.collection('ngos').doc(uid).set(updateData, SetOptions(merge: true));
                                            }
                                            await FirebaseFirestore.instance.collection('notifications').add({'title': 'Account Verified', 'body': 'Your account has been successfully verified by the Sahyog admin.', 'recipientId': uid, 'createdAt': FieldValue.serverTimestamp(), 'category': 'system'});
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name verified'), backgroundColor: AppColors.secondary));
                                          } else if (value == 'unverify') {
                                            final updateData = {'verified': false, 'status': 'rejected'};
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);
                                            if (role == 'ngo') {
                                              await FirebaseFirestore.instance.collection('ngos').doc(uid).set(updateData, SetOptions(merge: true));
                                            }
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name verification removed')));
                                          } else if (value == 'remove') {
                                            if (context.mounted) await _removeUser(context, uid, role, name);
                                          } else if (value == 'edit') {
                                            if (context.mounted) _showEditNgoDialog(context, uid, data);
                                          }
                                        },
                                        itemBuilder: (context) {
                                          final isBanned = data['banned'] == true;
                                          final isFlagged = data['flagged'] == true;
                                          final isVerified = data['verified'] == true;
                                          return [
                                            if (role == 'ngo') ...[
                                              PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Row(children: [
                                                  const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                                  const SizedBox(width: 10),
                                                  Text('Edit Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                                ]),
                                              ),
                                              const PopupMenuDivider(height: 1),
                                            ],
                                            if (role == 'donor') ...[
                                              PopupMenuItem<String>(
                                                value: isVerified ? 'unverify' : 'verify',
                                                child: Row(children: [
                                                  Icon(isVerified ? Icons.verified_user : Icons.verified_user_outlined, color: AppColors.secondary, size: 18),
                                                  const SizedBox(width: 10),
                                                  Text(isVerified ? 'Remove Verification' : 'Verify Donor', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                                ]),
                                              ),
                                              const PopupMenuDivider(height: 1),
                                            ],
                                            PopupMenuItem<String>(
                                              value: isFlagged ? 'unflag' : 'flag',
                                              child: Row(children: [
                                                Icon(isFlagged ? Icons.outlined_flag : Icons.flag, color: Colors.orange, size: 18),
                                                const SizedBox(width: 10),
                                                Text(isFlagged ? 'Remove Flag' : 'Flag User', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                              ]),
                                            ),
                                            const PopupMenuDivider(height: 1),
                                            PopupMenuItem<String>(
                                              value: isBanned ? 'unban' : 'ban',
                                              child: Row(children: [
                                                Icon(isBanned ? Icons.check_circle_outline : Icons.block, color: isBanned ? AppColors.secondary : AppColors.error, size: 18),
                                                const SizedBox(width: 10),
                                                Text(isBanned ? 'Unban User' : 'Ban User', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isBanned ? AppColors.secondary : AppColors.error)),
                                              ]),
                                            ),
                                            const PopupMenuDivider(height: 1),
                                            PopupMenuItem<String>(
                                              value: 'remove',
                                              child: Row(children: [
                                                const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                                const SizedBox(width: 10),
                                                Text('Remove Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                                              ]),
                                            ),
                                          ];
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        LoadMoreBar(
                          visibleCount: docs.length,
                          limit: _pageLimit,
                          onLoadMore: () => setState(() => _pageLimit += PageLimits.pageSize),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
    }
  }
