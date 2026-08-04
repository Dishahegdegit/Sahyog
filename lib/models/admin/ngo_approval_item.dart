import 'dart:math' as math;

class NgoApprovalItem {
  final String id;
  final String name;
  final String email;
  final String registrationId;
  final String address;
  final String phone;
  final String status;
  final DateTime? createdAt;

  NgoApprovalItem({
    required this.id,
    required this.name,
    required this.email,
    required this.registrationId,
    required this.address,
    required this.phone,
    required this.status,
    this.createdAt,
  });

  factory NgoApprovalItem.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? created;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is String) {
        created = DateTime.tryParse(map['createdAt']);
      } else {
        try {
          created = map['createdAt'].toDate() as DateTime?;
        } catch (_) {}
      }
    }

    final rawRegId = map['registrationId'] ?? map['regId'];
    final computedRegId = (rawRegId != null && rawRegId.toString().isNotEmpty)
        ? rawRegId.toString()
        : 'NGO-REG-${DateTime.now().year}-${docId.substring(0, math.min(3, docId.length)).toUpperCase()}';

    return NgoApprovalItem(
      id: docId,
      name: map['name'] ?? map['email'] ?? 'Unknown NGO',
      email: map['email'] ?? '',
      registrationId: computedRegId,
      address: map['address'] ?? map['location'] ?? 'Location not provided',
      phone: map['phone'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: created,
    );
  }

  String get initials {
    final cleanName = name.trim();
    final parts = cleanName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return cleanName.substring(0, math.min(2, cleanName.length)).toUpperCase();
  }
}
