class NgoModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String address;
  final double? latitude;
  final double? longitude;
  final String phone;
  final String email;
  final String profileImageUrl;
  final List<String> workingAreas;
  final String verificationStatus; // 'Approved', 'Pending'

  NgoModel({
    required this.id,
    this.name = '',
    this.registrationNumber = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.phone = '',
    this.email = '',
    this.profileImageUrl = '',
    this.workingAreas = const [],
    this.verificationStatus = 'Pending',
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

    double? parseCoord(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return NgoModel(
      id: docId,
      // No dummy fallbacks — use only what is stored in Firestore
      name: map['name'] as String? ?? map['organizationName'] as String? ?? '',
      registrationNumber: map['registrationNumber'] as String? ?? '',
      address: map['address'] as String? ?? map['officialAddress'] as String? ?? '',
      latitude: parseCoord(map['latitude']),
      longitude: parseCoord(map['longitude']),
      phone: map['phone'] as String? ?? map['contactPhone'] as String? ?? '',
      email: map['email'] as String? ?? map['contactEmail'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      workingAreas: areas,
      verificationStatus:
          map['verificationStatus'] as String? ?? map['status'] as String? ?? 'Pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'registrationNumber': registrationNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'workingAreas': workingAreas,
      'verificationStatus': verificationStatus,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  NgoModel copyWith({
    String? name,
    String? registrationNumber,
    String? address,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    String? phone,
    String? email,
    String? profileImageUrl,
    List<String>? workingAreas,
    String? verificationStatus,
  }) {
    return NgoModel(
      id: id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      workingAreas: workingAreas ?? this.workingAreas,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}
