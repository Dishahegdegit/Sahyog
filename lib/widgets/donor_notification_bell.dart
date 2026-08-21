import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/donor/donor_notifications_inbox.dart';

class DonorNotificationBell extends StatelessWidget {
  const DonorNotificationBell({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  bool _isUnread(Map<String, dynamic> data) {
    return data['isRead'] != true && data['read'] != true;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Widget bell({int unread = 0}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => DonorNotificationsInbox.show(context),
          child: SizedBox(
            width: size + 10,
            height: size + 10,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, color: color, size: size),
                if (unread > 0)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (uid == null) return bell();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: uid).snapshots(),
      builder: (context, userIdSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('notifications').where('recipientId', isEqualTo: uid).snapshots(),
          builder: (context, recipientSnap) {
            final ids = <String>{};
            var unread = 0;
            for (final doc in [...?userIdSnap.data?.docs, ...?recipientSnap.data?.docs]) {
              if (ids.add(doc.id) && _isUnread(doc.data())) {
                unread++;
              }
            }
            return bell(unread: unread);
          },
        );
      },
    );
  }
}
