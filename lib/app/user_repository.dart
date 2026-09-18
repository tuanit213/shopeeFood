import 'package:cloud_firestore/cloud_firestore.dart';

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
          _readInt(stats['totalOrders']) ?? _readInt(data['orderCount']) ?? 0,
      shopeeXu: _readInt(stats['shopeeXu']) ?? _readInt(data['shopeeXu']) ?? 0,
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

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(
    String userId,
  ) => _users.doc(userId).snapshots();

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
    // Aggregate stats become server-owned in Phase 2. The legacy UI still
    // computes them locally, but Phase 1 intentionally does not persist them.
  }

  /// Cập nhật ảnh đại diện. [avatarUrl] có thể là một data URI base64
  /// (`data:image/...`) hoặc một URL http. Chỉ nên gọi khi chuỗi đủ nhỏ so với
  /// giới hạn 1MB/document của Firestore (kiểm tra ở tầng gọi).
  static Future<void> updateAvatar({
    required String userId,
    required String avatarUrl,
  }) async {
    await _users.doc(userId).set({
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> syncSavedAddresses({
    required String userId,
    required List<Map<String, dynamic>> addresses,
  }) async {
    // Legacy addresses remain in SharedPreferences. New writes will use the
    // owner-only users/{uid}/addresses subcollection through AddressRepositoryV2.
  }
}
