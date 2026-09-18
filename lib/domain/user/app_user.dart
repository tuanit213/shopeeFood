import '../common/json_helpers.dart';

enum UserRole { customer, driver, merchant, admin }

enum UserStatus { active, disabled, pending }

class AppUser {
  final String uid;
  final String displayName;
  final String phone;
  final String email;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.customer({
    required String uid,
    required String displayName,
    required String phone,
    required String email,
    required DateTime now,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName.trim(),
      phone: phone.trim(),
      email: email.trim().toLowerCase(),
      role: UserRole.customer,
      status: UserStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: readString(json['uid']),
      displayName: readString(
        json['displayName'],
        fallback: readString(json['fullName']),
      ),
      phone: readString(json['phone']),
      email: readString(json['email']),
      role: readEnum(json['role'], UserRole.values, UserRole.customer),
      status: readEnum(json['status'], UserStatus.values, UserStatus.active),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'phone': phone,
    'email': email,
    'role': role.name,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  AppUser copyWith({
    String? displayName,
    String? phone,
    String? email,
    UserRole? role,
    UserStatus? status,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
