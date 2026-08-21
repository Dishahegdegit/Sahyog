import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotifications {
  AppNotifications._();

  static Future<void> send({
    required String userId,
    required String title,
    required String body,
    String? donationId,
    String? status,
    String category = 'donation',
  }) async {
    if (userId.isEmpty) return;
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'recipientId': userId,
      'title': title,
      'body': body,
      if (donationId != null && donationId.isNotEmpty) 'donationId': donationId,
      if (status != null) 'status': status,
      'category': category,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
