import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeefood/app/user_session.dart';

void main() {
  const userId = 'user-1';
  const phone = '0901234567';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSession.clearAll();
  });

  test('saveSession rememberMe true makes persistent session valid', () async {
    await UserSession.saveSession(
      userId: userId,
      phone: phone,
      rememberMe: true,
    );

    expect(await UserSession.isSessionValid(), isTrue);
  });

  test('saveSession rememberMe false does not persist session', () async {
    await UserSession.saveSession(
      userId: userId,
      phone: phone,
      rememberMe: false,
    );

    expect(await UserSession.isSessionValid(), isFalse);
  });

  test('expired session is invalid', () async {
    await UserSession.saveSession(
      userId: userId,
      phone: phone,
      rememberMe: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'current_user_expires_at',
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    );

    expect(await UserSession.isSessionValid(), isFalse);
  });

  test('missing session is invalid', () async {
    expect(await UserSession.isSessionValid(), isFalse);
  });

  test('clearAll removes session but keeps saved phone', () async {
    await UserSession.saveSession(
      userId: userId,
      phone: phone,
      rememberMe: true,
    );

    await UserSession.clearAll();
    final prefs = await SharedPreferences.getInstance();

    expect(await UserSession.isSessionValid(), isFalse);
    expect(prefs.getString('saved_phone'), phone);
  });

  test('refreshSession updates expiry to future', () async {
    await UserSession.saveSession(
      userId: userId,
      phone: phone,
      rememberMe: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'current_user_expires_at',
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    );

    await UserSession.refreshSession();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      prefs.getInt('current_user_expires_at')!,
    );

    expect(expiresAt.isAfter(DateTime.now()), isTrue);
  });
}
