import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String foodTitle;
  final String foodType; // 'Veg' or 'Non-Veg'
  final String quantity;
  final int servesCount;
  final String pickupLocation;
  final String distance;
  final DateTime? pickupTime;
  final DateTime? expiryTime;
  final String urgency; // 'High', 'Medium', 'Low'
  final String notes;
  final List<String> images;
  final String status; // 'Available', 'Accepted', 'Volunteer Assigned', 'Picked Up', 'Delivered'
  final String? acceptedByNgoId;
  final String? acceptedByNgoName;
  final DateTime? acceptedAt;
  final String? assignedVolunteerId;
  final String? assignedVolunteerName;
  final String? assignedVolunteerPhone;
  final DateTime? createdAt;
  final int? beneficiariesServed;
  final DateTime? deliveredAt;
  final String? deliveryLocation;
  final String? foodDelivered;

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    this.donorPhone = '',
    required this.foodTitle,
    required this.foodType,
    required this.quantity,
    required this.servesCount,
    required this.pickupLocation,
    this.distance = '',
    this.pickupTime,
    this.expiryTime,
    this.urgency = 'Medium',
    this.notes = '',
    this.images = const [],
    this.status = 'Available',
    this.acceptedByNgoId,
    this.acceptedByNgoName,
    this.acceptedAt,
    this.assignedVolunteerId,
    this.assignedVolunteerName,
    this.assignedVolunteerPhone,
    this.createdAt,
    this.beneficiariesServed,
    this.deliveredAt,
    this.deliveryLocation,
    this.foodDelivered,
  });

  factory DonationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return DonationModel(
      id: docId,
      donorId: map['donorId'] as String? ?? '',
      donorName: map['donorName'] as String? ?? '',
      donorPhone: map['donorPhone'] as String? ?? '',
      foodTitle: map['foodTitle'] as String? ?? map['foodName'] as String? ?? '',
      foodType: map['foodType'] as String? ?? 'Veg',
      quantity: map['quantity'] as String? ?? '',
      servesCount: map['servesCount'] is int
          ? map['servesCount'] as int
          : int.tryParse(map['servesCount']?.toString() ?? '0') ?? 0,
      pickupLocation: map['pickupLocation'] as String? ?? map['address'] as String? ?? '',
      distance: map['distance'] as String? ?? '',
      pickupTime: parseDate(map['pickupTime']),
      expiryTime: parseDate(map['expiryTime']),
      urgency: map['urgency'] as String? ?? 'Medium',
      notes: map['notes'] as String? ?? map['description'] as String? ?? '',
      images: map['images'] != null ? List<String>.from(map['images'] as List) : [],
      status: map['status'] as String? ?? 'Available',
      acceptedByNgoId: map['acceptedByNgoId'] as String?,
      acceptedByNgoName: map['acceptedByNgoName'] as String?,
      acceptedAt: parseDate(map['acceptedAt']),
      assignedVolunteerId: map['assignedVolunteerId'] as String?,
      assignedVolunteerName: map['assignedVolunteerName'] as String?,
      assignedVolunteerPhone: map['assignedVolunteerPhone'] as String?,
      createdAt: parseDate(map['createdAt']),
      beneficiariesServed: map['beneficiariesServed'] is int
          ? map['beneficiariesServed'] as int
          : int.tryParse(map['beneficiariesServed']?.toString() ?? ''),
      deliveredAt: parseDate(map['deliveredAt']),
      deliveryLocation: map['deliveryLocation'] as String?,
      foodDelivered: map['foodDelivered'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'donorId': donorId,
      'donorName': donorName,
      'donorPhone': donorPhone,
      'foodTitle': foodTitle,
      'foodType': foodType,
      'quantity': quantity,
      'servesCount': servesCount,
      'pickupLocation': pickupLocation,
      'distance': distance,
      'pickupTime': pickupTime?.toIso8601String(),
      'expiryTime': expiryTime?.toIso8601String(),
      'urgency': urgency,
      'notes': notes,
      'images': images,
      'status': status,
      'acceptedByNgoId': acceptedByNgoId,
      'acceptedByNgoName': acceptedByNgoName,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'assignedVolunteerId': assignedVolunteerId,
      'assignedVolunteerName': assignedVolunteerName,
      'assignedVolunteerPhone': assignedVolunteerPhone,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'beneficiariesServed': beneficiariesServed,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'deliveryLocation': deliveryLocation,
      'foodDelivered': foodDelivered,
    };
  }

  DonationModel copyWith({
    String? status,
    String? acceptedByNgoId,
    String? acceptedByNgoName,
    DateTime? acceptedAt,
    String? assignedVolunteerId,
    String? assignedVolunteerName,
    String? assignedVolunteerPhone,
    int? beneficiariesServed,
    DateTime? deliveredAt,
    String? deliveryLocation,
    String? foodDelivered,
  }) {
    return DonationModel(
      id: id,
      donorId: donorId,
      donorName: donorName,
      donorPhone: donorPhone,
      foodTitle: foodTitle,
      foodType: foodType,
      quantity: quantity,
      servesCount: servesCount,
      pickupLocation: pickupLocation,
      distance: distance,
      pickupTime: pickupTime,
      expiryTime: expiryTime,
      urgency: urgency,
      notes: notes,
      images: images,
      status: status ?? this.status,
      acceptedByNgoId: acceptedByNgoId ?? this.acceptedByNgoId,
      acceptedByNgoName: acceptedByNgoName ?? this.acceptedByNgoName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      assignedVolunteerId: assignedVolunteerId ?? this.assignedVolunteerId,
      assignedVolunteerName: assignedVolunteerName ?? this.assignedVolunteerName,
      assignedVolunteerPhone: assignedVolunteerPhone ?? this.assignedVolunteerPhone,
      createdAt: createdAt,
      beneficiariesServed: beneficiariesServed ?? this.beneficiariesServed,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      foodDelivered: foodDelivered ?? this.foodDelivered,
    );
  }
}
