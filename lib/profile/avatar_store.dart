import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu/đọc ảnh đại diện người dùng.
///
/// Chiến lược "local trước, Firestore sau":
/// - Ảnh được nén nhỏ (~512px) rồi mã hoá base64 thành một data URI
///   (`data:image/jpeg;base64,...`). Không cần cấu hình cloud storage.
/// - Lưu ngay vào [SharedPreferences] theo `userId` → hiện tức thì, chạy được
///   cả khi offline, và không mất khi app đóng.
/// - Việc mirror lên Firestore để đồng bộ nhiều thiết bị do
///   `UserRepository.updateAvatar` đảm nhiệm (best-effort, gọi ở tầng trên).
class AvatarStore {
  static const _prefsPrefix = 'profile_avatar_data_uri_v1';

  /// Ngưỡng an toàn cho một document Firestore (giới hạn cứng 1MB). Ảnh vượt
  /// mức này chỉ giữ ở máy, không đẩy lên Firestore để tránh ghi lỗi.
  static const maxFirestoreDataUriLength = 700 * 1024;

  static final ImagePicker _picker = ImagePicker();

  static String _keyFor(String userId) => '$_prefsPrefix:$userId';

  /// Mở nguồn ảnh ([ImageSource.gallery] hoặc [ImageSource.camera]), nén và
  /// trả về data URI. `null` nếu người dùng huỷ chọn.
  static Future<String?> pickAsDataUri(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 78,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    final mime = _mimeFromPath(file.path);
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static Future<String?> loadLocal(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_keyFor(userId));
      return (value == null || value.isEmpty) ? null : value;
    } catch (error) {
      debugPrint('[Avatar] đọc local lỗi: $error');
      return null;
    }
  }

  static Future<void> saveLocal(String userId, String dataUri) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFor(userId), dataUri);
    } catch (error) {
      debugPrint('[Avatar] lưu local lỗi: $error');
    }
  }

  /// Giải mã một data URI base64 thành bytes để dựng `Image.memory`. Trả về
  /// `null` nếu chuỗi không phải data URI ảnh hợp lệ (VD là URL http).
  static Uint8List? bytesFromDataUri(String? value) {
    if (value == null || !value.startsWith('data:image')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (error) {
      debugPrint('[Avatar] giải mã data URI lỗi: $error');
      return null;
    }
  }

  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
