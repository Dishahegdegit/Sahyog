class NgoModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String address;
  final String phone;
  final String email;
  final String profileImageUrl;
  final List<String> workingAreas;
  final String verificationStatus; // 'Approved', 'Pending'
  final double? latitude;
  final double? longitude;

  NgoModel({
    required this.id,
    this.name = '',
    this.registrationNumber = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.profileImageUrl = '',
    this.workingAreas = const [],
    this.verificationStatus = 'Pending',
    this.latitude,
    this.longitude,
  });

  factory NgoModel.fromMap(Map<String, dynamic> map, String docId) {
    List<String> areas = [];
    if (map['workingAreas'] is List) {
      areas = List<String>.from(map['workingAreas'] as List);
    } else if (map['workingAreas'] is String &&
        (map['workingAreas'] as String).isNotEmpty) {
      areas = (map['workingAreas'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return NgoModel(
      id: docId,
      name: map['name'] as String? ?? map['organizationName'] as String? ?? '',
      registrationNumber: map['registrationNumber'] as String? ?? '',
      address: map['address'] as String? ?? map['officialAddress'] as String? ?? '',
      phone: map['phone'] as String? ?? map['contactPhone'] as String? ?? '',
      email: map['email'] as String? ?? map['contactEmail'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      workingAreas: areas,
      verificationStatus:
          map['verificationStatus'] as String? ?? map['status'] as String? ?? 'Pending',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'registrationNumber': registrationNumber,
      'address': address,
      'phone': phone,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'workingAreas': workingAreas,
      'verificationStatus': verificationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  NgoModel copyWith({
    String? name,
    String? registrationNumber,
    String? address,
    String? phone,
    String? email,
    String? profileImageUrl,
    List<String>? workingAreas,
    String? verificationStatus,
    double? latitude,
    double? longitude,
  }) {
    return NgoModel(
      id: id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      workingAreas: workingAreas ?? this.workingAreas,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
