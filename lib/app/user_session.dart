import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _userIdKey = 'current_user_id';
  static const _expiresAtKey = 'current_user_expires_at';
  static const _savedPhoneKey = 'saved_login_phone';
  static const rememberDuration = Duration(days: 7);

  static String? _runtimeUserId;

  static Future<void> saveLogin({
    required String userId,
    required String phone,
    required bool remember,
  }) async {
    _runtimeUserId = userId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedPhoneKey, phone);

    if (!remember) {
      await prefs.remove(_userIdKey);
      await prefs.remove(_expiresAtKey);
      return;
    }

    final expiresAt = DateTime.now().add(rememberDuration);
    await prefs.setString(_userIdKey, userId);
    await prefs.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
  }

  static Future<void> saveUserId(String userId) async {
    _runtimeUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_expiresAtKey);
  }

  static Future<String?> getUserId() async {
    if (_runtimeUserId != null && _runtimeUserId!.isNotEmpty) {
      return _runtimeUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final expiresAtMs = prefs.getInt(_expiresAtKey);

    if (userId == null || userId.isEmpty || expiresAtMs == null) {
      return null;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    if (DateTime.now().isAfter(expiresAt)) {
      await prefs.remove(_userIdKey);
      await prefs.remove(_expiresAtKey);
      return null;
    }

    return userId;
  }

  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_savedPhoneKey)?.trim();
    return phone == null || phone.isEmpty ? null : phone;
  }

  static Future<void> clear({String? rememberPhone}) async {
    _runtimeUserId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_expiresAtKey);

    final phone = rememberPhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_savedPhoneKey, phone);
    }
  }
}
