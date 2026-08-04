import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerModel {
  final String id;
  final String ngoId;
  final String name;
  final String phone;
  final String email;
  final String status; // 'Available', 'On Delivery'
  final String? assignedDonationId;
  final String workingArea;
  final DateTime? createdAt;

  VolunteerModel({
    required this.id,
    required this.ngoId,
    required this.name,
    required this.phone,
    this.email = '',
    this.status = 'Available',
    this.assignedDonationId,
    this.workingArea = '',
    this.createdAt,
  });

  factory VolunteerModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return VolunteerModel(
      id: docId,
      ngoId: map['ngoId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      status: map['status'] as String? ?? 'Available',
      assignedDonationId: map['assignedDonationId'] as String?,
      workingArea: map['workingArea'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ngoId': ngoId,
      'name': name,
      'phone': phone,
      'email': email,
      'status': status,
      'assignedDonationId': assignedDonationId,
      'workingArea': workingArea,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  VolunteerModel copyWith({
    String? status,
    String? assignedDonationId,
    String? workingArea,
  }) {
    return VolunteerModel(
      id: id,
      ngoId: ngoId,
      name: name,
      phone: phone,
      email: email,
      status: status ?? this.status,
      assignedDonationId: assignedDonationId ?? this.assignedDonationId,
      workingArea: workingArea ?? this.workingArea,
      createdAt: createdAt,
    );
  }
}
