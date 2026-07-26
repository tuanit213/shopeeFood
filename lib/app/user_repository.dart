import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class AppUserProfile {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final int orderCount;
  final int shopeeXu;
  final int ratingCount;
  final double? ratingAverage;

  const AppUserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.orderCount,
    required this.shopeeXu,
    required this.ratingCount,
    required this.ratingAverage,
  });

  factory AppUserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AppUserProfile.fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  factory AppUserProfile.fromMap(String id, Map<String, dynamic> data) {
    final stats = data['stats'] as Map<String, dynamic>? ?? const {};
    final rating =
        stats['avgRating'] ?? stats['ratingAverage'] ?? data['ratingAverage'];
    return AppUserProfile(
      id: id,
      fullName:
          _readString(data['displayName']) ??
          _readString(data['fullName']) ??
          'Người dùng',
      phone: _readString(data['phone']) ?? '',
      email: _readString(data['email']) ?? '',
      orderCount:
          _readInt(stats['totalOrders']) ??
          _readInt(data['orderCount']) ??
          0,
      shopeeXu:
          _readInt(stats['shopeeXu']) ?? _readInt(data['shopeeXu']) ?? 0,
      ratingCount:
          _readInt(stats['ratingCount']) ?? _readInt(data['ratingCount']) ?? 0,
      ratingAverage: rating is num ? rating.toDouble() : null,
    );
  }

  String get ratingLabel {
    if (ratingCount <= 0 || ratingAverage == null) {
      return 'Chưa đánh giá';
    }
    return '${ratingAverage!.toStringAsFixed(1)} sao';
  }

  static String? _readString(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static int? _readInt(Object? value) => value is num ? value.toInt() : null;
}

class UserRepository {
  static final _users = FirebaseFirestore.instance.collection('users');

  static String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84') && digits.length >= 11) {
      return '0${digits.substring(2)}';
    }
    return digits;
  }

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> findByPhone(
    String phone,
  ) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return null;
    final users = await _users
        .where('phone', isEqualTo: normalized)
        .limit(1)
        .get();
    return users.docs.isEmpty ? null : users.docs.first;
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> findByEmail(
    String email,
  ) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) return null;
    final users = await _users
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    return users.docs.isEmpty ? null : users.docs.first;
  }

  static Future<DocumentReference<Map<String, dynamic>>> createUser({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final normalizedPhone = normalizePhone(phone);
    final normalizedEmail = normalizeEmail(email);

    final existingPhone = await findByPhone(normalizedPhone);
    if (existingPhone != null) {
      throw const UserRepositoryException('Số điện thoại đã được đăng ký');
    }

    final existingEmail = await findByEmail(normalizedEmail);
    if (existingEmail != null) {
      throw const UserRepositoryException('Email đã được đăng ký');
    }

    final userRef = _users.doc();
    await userRef.set({
      'uid': userRef.id,
      'fullName': fullName.trim(),
      'displayName': fullName.trim(),
      'phone': normalizedPhone,
      'email': normalizedEmail,
      'passwordHash': hashPassword(password),
      'avatarUrl': null,
      'acceptedTerms': true,
      'provider': 'email_password_form',
      'stats': {
        'totalOrders': 0,
        'totalSpent': 0,
        'shopeeXu': 0,
        'ratingCount': 0,
        'avgRating': null,
      },
      'savedAddresses': const [],
      'rememberMe': false,
      'sessionExpiry': null,
      'orderCount': 0,
      'shopeeXu': 0,
      'ratingCount': 0,
      'ratingAverage': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return userRef;
  }

  static Future<void> recordLogin({
    required String userId,
    required bool rememberMe,
    DateTime? sessionExpiry,
  }) async {
    await _users.doc(userId).set({
      'rememberMe': rememberMe,
      'sessionExpiry': sessionExpiry == null
          ? null
          : Timestamp.fromDate(sessionExpiry),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> syncStatsFromOrders({
    required String userId,
    required int totalOrders,
    required int totalSpent,
    required int shopeeXu,
    required int ratingCount,
    required double? avgRating,
  }) async {
    await _users.doc(userId).set({
      'stats': {
        'totalOrders': totalOrders,
        'totalSpent': totalSpent,
        'shopeeXu': shopeeXu,
        'ratingCount': ratingCount,
        'avgRating': avgRating,
      },
      'orderCount': totalOrders,
      'shopeeXu': shopeeXu,
      'ratingCount': ratingCount,
      'ratingAverage': avgRating,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> syncSavedAddresses({
    required String userId,
    required List<Map<String, dynamic>> addresses,
  }) async {
    await _users.doc(userId).set({
      'savedAddresses': addresses,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class UserRepositoryException implements Exception {
  final String? message;

  const UserRepositoryException(this.message);

  String get code => message ?? 'user_repository_error';

  @override
  String toString() => code;
}
