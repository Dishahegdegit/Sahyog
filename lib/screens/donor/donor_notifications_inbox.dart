import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import 'donation_detail_screen.dart';

class DonorNotificationsInbox {
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DonorNotificationsSheet(),
    );
  }
}

class _DonorNotificationsSheet extends StatelessWidget {
  const _DonorNotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        'Donation accepted, pickup and delivery updates',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: c.textSecondary, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
          Expanded(
            child: uid == null
                ? Center(
                    child: Text('Please log in to view notifications.', style: TextStyle(color: c.textPrimary)),
                  )
                : _DonorNotificationList(uid: uid),
          ),
        ],
      ),
    );
  }
}

class _DonorNotificationList extends StatelessWidget {
  const _DonorNotificationList({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: uid).limit(40).snapshots(),
      builder: (context, userIdSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('notifications').where('recipientId', isEqualTo: uid).limit(40).snapshots(),
          builder: (context, recipientSnap) {
            if (userIdSnap.hasError && recipientSnap.hasError) {
              return Center(
                child: Text('Could not load notifications.', style: TextStyle(color: c.error)),
              );
            }

            if (userIdSnap.connectionState == ConnectionState.waiting &&
                recipientSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged = {};
            for (final doc in userIdSnap.data?.docs ?? []) {
              merged[doc.id] = doc;
            }
            for (final doc in recipientSnap.data?.docs ?? []) {
              merged[doc.id] = doc;
            }

            final docs = merged.values.toList()
              ..sort((a, b) {
                final aTime = a.data()['createdAt'];
                final bTime = b.data()['createdAt'];
                if (aTime is Timestamp && bTime is Timestamp) {
                  return bTime.compareTo(aTime);
                }
                if (aTime is Timestamp) return -1;
                if (bTime is Timestamp) return 1;
                return 0;
              });

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 48, color: c.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You will see updates when an NGO accepts, assigns a volunteer, picks up, or delivers your donation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _DonorNotificationTile(doc: docs[index]);
              },
            );
          },
        );
      },
    );
  }
}

class _DonorNotificationTile extends StatelessWidget {
  const _DonorNotificationTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  bool _isRead(Map<String, dynamic> data) {
    return data['isRead'] == true || data['read'] == true;
  }

  IconData _iconFor(String title, String status) {
    final text = '$title $status'.toLowerCase();
    if (text.contains('accepted')) return Icons.check_circle_outline;
    if (text.contains('volunteer')) return Icons.badge_outlined;
    if (text.contains('picked')) return Icons.delivery_dining_outlined;
    if (text.contains('deliver')) return Icons.volunteer_activism_outlined;
    return Icons.notifications_outlined;
  }

  Color _colorFor(String title, String status) {
    final text = '$title $status'.toLowerCase();
    if (text.contains('accepted')) return AppColors.statusAccepted;
    if (text.contains('volunteer')) return AppColors.statusTransit;
    if (text.contains('picked')) return AppColors.statusTransit;
    if (text.contains('deliver')) return AppColors.statusDelivered;
    return AppColors.primary;
  }

  String _formatTime(dynamic createdAt) {
    DateTime? date;
    if (createdAt is Timestamp) {
      date = createdAt.toDate();
    } else if (createdAt is DateTime) {
      date = createdAt;
    }
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, hh:mm a').format(date);
  }

  Future<void> _open(BuildContext context) async {
    final data = doc.data();
    if (!_isRead(data)) {
      await doc.reference.set({'isRead': true}, SetOptions(merge: true));
    }

    final donationId = (data['donationId'] ?? '').toString();
    if (!context.mounted) return;
    Navigator.pop(context);
    if (donationId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DonationDetailScreen(donationId: donationId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = doc.data();
    final title = (data['title'] ?? 'Sahyog update').toString();
    final body = (data['body'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final isRead = _isRead(data);
    final tint = _colorFor(title, status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? c.surfaceContainerLow : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? c.outlineVariant.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.3),
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
                child: Icon(_iconFor(title, status), color: tint, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(data['createdAt']),
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
