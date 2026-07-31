class UserModel {
  final String uid;
  final String email;
  final String role; // 'donor' | 'ngo' | 'admin'

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'donor',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}