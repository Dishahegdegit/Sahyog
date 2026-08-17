import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import 'ngo_approval_screen.dart';

class AdminNotificationsSheet extends StatefulWidget {
  const AdminNotificationsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminNotificationsSheet(),
    );
  }

  @override
  State<AdminNotificationsSheet> createState() => _AdminNotificationsSheetState();
}

class _AdminNotificationsSheetState extends State<AdminNotificationsSheet> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: GoogleFonts.publicSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Platform alerts & updates',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ('all', 'All'),
                ('donations', 'Donations'),
                ('approvals', 'NGO Approvals'),
                ('alerts', 'System Alerts'),
              ].map((f) {
                final isSelected = _selectedFilter == f.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : colors.outlineVariant,
                      ),
                    ),
                    child: Text(
                      f.$2,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.5)),

          // Notifications List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                
                // Combine Firestore notifications with live platform events if needed
                final items = _buildNotificationList(docs);
                final filtered = items.where((item) {
                  if (_selectedFilter == 'all') return true;
                  return item['category'] == _selectedFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: colors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications',
                          style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are all caught up!',
                          style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _NotificationTile(item: item, colors: colors);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildNotificationList(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> list = [];
    
    // Add Firestore notification documents
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final title = data['title'] ?? 'Notification';
      final body = data['body'] ?? '';
      final time = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      list.add({
        'title': title,
        'body': body,
        'time': time,
        'icon': Icons.info_outline_rounded,
        'color': AppColors.primary,
        'category': 'donations',
        'isRead': false,
      });
    }

    // Default sample system notifications if list is sparse
    if (list.length < 3) {
      list.addAll([
        {
          'title': 'New NGO Registration Pending',
          'body': 'Helping Hands Foundation has submitted verification documents.',
          'time': DateTime.now().subtract(const Duration(minutes: 25)),
          'icon': Icons.shield_outlined,
          'color': AppColors.primary,
          'category': 'approvals',
          'isRead': false,
          'actionLabel': 'Review NGO',
        },
        {
          'title': 'Food Donation Submitted',
          'body': 'Fresh cooked rice & curry (50 servings) available in Andheri East.',
          'time': DateTime.now().subtract(const Duration(hours: 2)),
          'icon': Icons.restaurant_rounded,
          'color': AppColors.secondary,
          'category': 'donations',
          'isRead': true,
        },
        {
          'title': 'Low Stock Warning',
          'body': '3 partner NGOs reported low inventory levels.',
          'time': DateTime.now().subtract(const Duration(hours: 5)),
          'icon': Icons.warning_amber_rounded,
          'color': AppColors.tertiary,
          'category': 'alerts',
          'isRead': true,
        },
      ]);
    }

    return list;
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final AppColorSet colors;

  const _NotificationTile({required this.item, required this.colors});

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon = item['icon'] ?? Icons.notifications;
    final Color tint = item['color'] ?? AppColors.primary;
    final bool isRead = item['isRead'] ?? false;
    final String? actionLabel = item['actionLabel'];
    final DateTime time = item['time'] as DateTime;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? colors.surfaceContainerLow : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? colors.outlineVariant.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? '',
                        style: GoogleFonts.publicSans(
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(time),
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['body'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NgoApprovalScreen()),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.primary),
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
}
