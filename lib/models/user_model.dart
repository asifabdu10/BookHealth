class UserModel {
  final String uid;
  final String email;
  final String role; // 'patient' (Mobile App only)

  UserModel({required this.uid, required this.email, required this.role});

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'role': role};
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'patient',
    );
  }
}
