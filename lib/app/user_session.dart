import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const int sessionDays = 7;

  static const _userIdKey = 'current_user_id';
  static const _expiresAtKey = 'current_user_expires_at';
  static const _savedPhoneKey = 'saved_phone';
  static const _legacySavedPhoneKey = 'saved_login_phone';
  static const rememberDuration = Duration(days: sessionDays);

  static String? _runtimeUserId;

  static void _log(String message) {
    debugPrint('[UserSession] $message');
  }

  static Future<void> saveLogin({
    required String userId,
    required String phone,
    required bool remember,
  }) async {
    await saveSession(userId: userId, phone: phone, rememberMe: remember);
  }

  static Future<void> saveSession({
    required String userId,
    required String phone,
    required bool rememberMe,
  }) async {
    _runtimeUserId = userId;

    final prefs = await SharedPreferences.getInstance();
    await _savePhone(prefs, phone);

    if (!rememberMe) {
      await prefs.remove(_userIdKey);
      await prefs.remove(_expiresAtKey);
      _log('saved runtime session only');
      return;
    }

    final expiresAt = DateTime.now().add(rememberDuration);
    await prefs.setString(_userIdKey, userId);
    await prefs.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
    _log('saved persistent session until ${expiresAt.toIso8601String()}');
  }

  static Future<void> saveUserId(String userId) async {
    _runtimeUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_expiresAtKey);
    _log('saved runtime user id');
  }

  static Future<String?> getUserId() async {
    if (_runtimeUserId != null && _runtimeUserId!.isNotEmpty) {
      return _runtimeUserId;
    }

    return _getPersistentUserId();
  }

  static Future<bool> isSessionValid() async {
    final userId = await _getPersistentUserId();
    final isValid = userId != null;
    _log('isSessionValid: $isValid');
    return isValid;
  }

  static Future<void> refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId == null || userId.isEmpty) {
      _log('refreshSession skipped: no persistent user');
      return;
    }

    final expiresAt = DateTime.now().add(rememberDuration);
    await prefs.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
    _log('refreshed session until ${expiresAt.toIso8601String()}');
  }

  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone =
        prefs.getString(_savedPhoneKey)?.trim() ??
        prefs.getString(_legacySavedPhoneKey)?.trim();
    return phone == null || phone.isEmpty ? null : phone;
  }

  static Future<void> clear({String? rememberPhone}) async {
    await clearAll(rememberPhone: rememberPhone);
  }

  static Future<void> clearAll({String? rememberPhone}) async {
    _runtimeUserId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_expiresAtKey);

    final phone = rememberPhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      await _savePhone(prefs, phone);
    }
    _log('cleared session');
  }

  static Future<void> _savePhone(SharedPreferences prefs, String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      return;
    }

    await prefs.setString(_savedPhoneKey, normalized);
    await prefs.setString(_legacySavedPhoneKey, normalized);
  }

  static Future<String?> _getPersistentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final expiresAt = _readExpiresAt(prefs);

    if (userId == null || userId.isEmpty || expiresAt == null) {
      return null;
    }

    if (DateTime.now().isAfter(expiresAt)) {
      await prefs.remove(_userIdKey);
      await prefs.remove(_expiresAtKey);
      _log('persistent session expired');
      return null;
    }

    return userId;
  }

  static DateTime? _readExpiresAt(SharedPreferences prefs) {
    final value = prefs.get(_expiresAtKey);
    try {
      final milliseconds = switch (value) {
        int raw => raw,
        String raw => int.parse(raw),
        _ => null,
      };
      if (milliseconds == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    } catch (error) {
      _log('invalid expiry timestamp: $error');
      return null;
    }
  }
}
