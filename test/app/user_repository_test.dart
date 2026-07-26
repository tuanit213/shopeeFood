import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/app/user_repository.dart';

void main() {
  test('normalizePhone keeps Vietnamese phone format consistent', () {
    expect(UserRepository.normalizePhone('0901 234 567'), '0901234567');
    expect(UserRepository.normalizePhone('+84 901 234 567'), '0901234567');
  });

  test('AppUserProfile reads new stats schema and legacy fields', () {
    final profile = AppUserProfile.fromMap('user-1', {
      'displayName': ' Nguyen Van A ',
      'fullName': 'Legacy Name',
      'phone': '0901234567',
      'email': 'a@example.com',
      'stats': {
        'totalOrders': 7,
        'shopeeXu': 320,
        'ratingCount': 2,
        'avgRating': 4.75,
      },
      'orderCount': 1,
    });

    expect(profile.fullName, 'Nguyen Van A');
    expect(profile.orderCount, 7);
    expect(profile.shopeeXu, 320);
    expect(profile.ratingCount, 2);
    expect(profile.ratingAverage, 4.75);
    expect(profile.ratingLabel, '4.8 sao');
  });
}
