import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TicketService {
  TicketService._();

  static Future<void> createTicket({
    required String subject,
    required String description,
    String? donationId,
    String creatorRole = 'donor',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be logged in to report an issue.');

    String name = user.displayName ?? '';
    String role = creatorRole;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      if (name.isEmpty) name = (data['name'] ?? user.email ?? 'User').toString();
      role = (data['role'] ?? creatorRole).toString();
    } catch (_) {}

    await FirebaseFirestore.instance.collection('tickets').add({
      'createdBy': user.uid,
      'creatorName': name,
      'creatorRole': role,
      if (donationId != null && donationId.isNotEmpty) 'donationId': donationId,
      'subject': subject.trim(),
      'description': description.trim(),
      'status': 'open',
      'adminReply': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
