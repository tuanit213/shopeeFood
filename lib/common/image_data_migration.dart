import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dọn dữ liệu ảnh cũ còn nằm trong SharedPreferences.
///
/// Đổi code thôi là chưa đủ: giỏ hàng, đơn hàng, quán đã lưu và cache danh
/// sách quán đều được ghi xuống máy từ các phiên trước, và chúng vẫn giữ URL
/// ảnh cũ (URL dịch vụ ảnh ngẫu nhiên, ảnh dùng chung trong kho
/// `assets/images/restaurants/`). Lớp migration này chạy khi version ảnh tăng:
///
/// * xoá hẳn cache danh sách quán phiên bản cũ,
/// * chuyển giỏ hàng/đơn hàng và danh sách quán đã lưu sang khoá mới — dữ
///   liệu được đọc lại qua `fromJson`, nơi ảnh cũ bị loại và thay bằng ảnh
///   thật trong `assets/images/dishes/` nếu có.
///
/// Gọi trong `main()` TRƯỚC `OrderState.hydrate()`.
class ImageDataMigration {
  static const _versionKey = 'shopeefood_image_data_version';
  static const currentVersion = 6;

  /// Khoá cũ -> khoá mới. Nội dung giữ nguyên, việc chuẩn hoá ảnh do
  /// `fromJson` của từng model đảm nhiệm khi đọc lên.
  static const _renamedKeys = <String, String>{
    'shopeefood_order_state_entries_v1': 'shopeefood_order_state_entries_v2',
    'favorite_restaurant_snapshots_v1': 'favorite_restaurant_snapshots_v2',
  };

  /// Tiền tố cache bị xoá thẳng (dữ liệu sẽ tự tải lại từ Firestore/Geoapify).
  static const _droppedPrefixes = <String>[
    'restaurant_cache_v1',
    'restaurant_cache_v2',
    'restaurant_cache_v3',
    'restaurant_cache_v4',
    'restaurant_cache_v5',
  ];

  static Future<void> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getInt(_versionKey) ?? 0) >= currentVersion) {
        return;
      }

      var moved = 0;
      for (final entry in _renamedKeys.entries) {
        final legacy = prefs.getString(entry.key);
        if (legacy != null && legacy.isNotEmpty) {
          // Không ghi đè dữ liệu mới hơn nếu người dùng đã dùng bản mới.
          if ((prefs.getString(entry.value) ?? '').isEmpty) {
            await prefs.setString(entry.value, legacy);
            moved++;
          }
        }
        await prefs.remove(entry.key);
      }

      var dropped = 0;
      for (final key in prefs.getKeys().toList()) {
        if (_droppedPrefixes.any(key.startsWith)) {
          await prefs.remove(key);
          dropped++;
        }
      }

      await prefs.setInt(_versionKey, currentVersion);
      debugPrint(
        '[ImageDataMigration] v$currentVersion: chuyển $moved khoá, '
        'xoá $dropped cache quán cũ',
      );
    } catch (error) {
      debugPrint('[ImageDataMigration] lỗi: $error');
    }
  }
}
