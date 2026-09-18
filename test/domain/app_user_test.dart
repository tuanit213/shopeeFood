import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/domain/user/app_user.dart';

void main() {
  test('customer registration profile cannot request a privileged role', () {
    final now = DateTime.utc(2026, 1, 1);
    final user = AppUser.customer(
      uid: 'uid-1',
      displayName: 'Customer',
      phone: '0901234567',
      email: 'Customer@Example.com',
      now: now,
    );

    expect(user.role, UserRole.customer);
    expect(user.status, UserStatus.active);
    expect(user.email, 'customer@example.com');
    expect(AppUser.fromJson(user.toJson()).toJson(), user.toJson());
    expect(user.toJson(), isNot(contains('passwordHash')));
  });
}
