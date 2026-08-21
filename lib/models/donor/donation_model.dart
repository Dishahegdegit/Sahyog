import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String? id;
  final String donorId;
  final String foodName;
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
  final String? ngoId;
  final String? ngoName;
  final String? ngoAddress;
  final String? ngoPhone;
  final DateTime? createdAt;

  DonationModel({
    this.id,
    required this.donorId,
    this.foodName = '',
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
    this.ngoId,
    this.ngoName,
    this.ngoAddress,
    this.ngoPhone,
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
      foodName: map['foodName'] ?? map['foodTitle'] ?? '',
      foodType: map['foodType'] ?? 'Veg',
      foodQuantity: map['foodQuantity'] ?? '',
      servings: map['servings'] is int
          ? map['servings']
          : int.tryParse(map['servings']?.toString() ?? '0') ?? 0,
      pickupAddress: map['pickupAddress'] ?? '',
      latitude: (map['latitude'] is num)
          ? (map['latitude'] as num).toDouble()
          : double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: (map['longitude'] is num)
          ? (map['longitude'] as num).toDouble()
          : double.tryParse(map['longitude']?.toString() ?? ''),
      pickupTime: map['pickupTime'] ?? '',
      expiryTime: map['expiryTime'] ?? '',
      notes: map['notes'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      status: map['status'] ?? 'pending',
      ngoId: (map['ngoId'] ?? map['requestedNgoId']) as String?,
      ngoName: map['ngoName'] as String?,
      ngoAddress: map['ngoAddress'] as String?,
      ngoPhone: map['ngoPhone'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    final title = foodName.trim().isNotEmpty ? foodName.trim() : foodType;
    return {
      'donorId': donorId,
      'foodName': foodName,
      'foodType': foodType,
      'foodTitle': title,
      'foodQuantity': foodQuantity,
      'quantity': foodQuantity,
      'servings': servings,
      'servesCount': servings,
      'pickupAddress': pickupAddress,
      'pickupLocation': pickupAddress,
      'latitude': latitude,
      'longitude': longitude,
      'pickupTime': pickupTime,
      'expiryTime': expiryTime,
      'notes': notes,
      'imageUrl': imageUrl,
      'images': imageUrl.isNotEmpty ? [imageUrl] : <String>[],
      'status': status,
      if (ngoId != null && ngoId!.trim().isNotEmpty) 'ngoId': ngoId,
      if (ngoId != null && ngoId!.trim().isNotEmpty) 'requestedNgoId': ngoId,
      if (ngoName != null) 'ngoName': ngoName,
      if (ngoAddress != null) 'ngoAddress': ngoAddress,
      if (ngoPhone != null) 'ngoPhone': ngoPhone,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
