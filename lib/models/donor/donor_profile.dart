import 'package:cloud_firestore/cloud_firestore.dart';

class DonorProfile {
  final String uid;
  final String fullName;
  final String organizationName;
  final String phoneNumber;
  final String email;
  final String address;
  final String profileImageUrl;
  final DateTime? updatedAt;

  DonorProfile({
    required this.uid,
    required this.fullName,
    this.organizationName = '',
    required this.phoneNumber,
    required this.email,
    this.address = '',
    this.profileImageUrl = '',
    this.updatedAt,
  });

  factory DonorProfile.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parsedUpdatedAt;
    if (map['updatedAt'] != null) {
      if (map['updatedAt'] is Timestamp) {
        parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
      } else if (map['updatedAt'] is String) {
        parsedUpdatedAt = DateTime.tryParse(map['updatedAt']);
      }
    }

    return DonorProfile(
      uid: uid,
      fullName: map['fullName'] ?? '',
      organizationName: map['organizationName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'organizationName': organizationName,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DonorProfile copyWith({
    String? uid,
    String? fullName,
    String? organizationName,
    String? phoneNumber,
    String? email,
    String? address,
    String? profileImageUrl,
    DateTime? updatedAt,
  }) {
    return DonorProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      organizationName: organizationName ?? this.organizationName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
