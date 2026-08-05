import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String? id;
  final String donorId;
  final String foodType; // 'Veg' | 'Non-Veg'
  final String foodQuantity;
  final int servings;
  final String pickupAddress;
  final double? latitude;
  final double? longitude;
  final String pickupTime;
  final String expiryTime;
  final String notes;
  final String imageUrl;
  final String status; // 'pending' | 'accepted' | 'completed' | 'cancelled'
  final DateTime? createdAt;

  DonationModel({
    this.id,
    required this.donorId,
    required this.foodType,
    required this.foodQuantity,
    required this.servings,
    required this.pickupAddress,
    this.latitude,
    this.longitude,
    required this.pickupTime,
    required this.expiryTime,
    this.notes = '',
    this.imageUrl = '',
    this.status = 'pending',
    this.createdAt,
  });

  factory DonationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? created;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        created = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        created = DateTime.tryParse(map['createdAt']);
      }
    }

    return DonationModel(
      id: docId,
      donorId: map['donorId'] ?? '',
      foodType: map['foodType'] ?? 'Veg',
      foodQuantity: map['foodQuantity'] ?? '',
      servings: map['servings'] is int
          ? map['servings']
          : int.tryParse(map['servings']?.toString() ?? '0') ?? 0,
      pickupAddress: map['pickupAddress'] ?? '',
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : double.tryParse(map['longitude']?.toString() ?? ''),
      pickupTime: map['pickupTime'] ?? '',
      expiryTime: map['expiryTime'] ?? '',
      notes: map['notes'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'donorId': donorId,
      'foodType': foodType,
      'foodQuantity': foodQuantity,
      'servings': servings,
      'pickupAddress': pickupAddress,
      'latitude': latitude,
      'longitude': longitude,
      'pickupTime': pickupTime,
      'expiryTime': expiryTime,
      'notes': notes,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
