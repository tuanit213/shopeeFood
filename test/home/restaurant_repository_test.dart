import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/home/restaurant_repository.dart';
import 'package:shopeefood/location/location_service.dart';

void main() {
  test('fallback location returns rich seeded restaurants around user', () async {
    final result = await RestaurantRepository.loadNearby(
      const AppLocation(
        latitude: 10.78,
        longitude: 106.69,
        address: 'Phuong Ben Nghe, Quan 1, TP. Ho Chi Minh',
        isFallback: true,
      ),
    );

    expect(result.fromCache, isFalse);
    expect(result.restaurants, hasLength(25));
    expect(
      result.restaurants.map((item) => item.category).toSet().length,
      greaterThanOrEqualTo(10),
    );
    expect(result.restaurants.every((item) => item.latitude != 10.78), isTrue);
    expect(
      result.restaurants.every(
        (item) => item.address.contains('TP. Ho Chi Minh'),
      ),
      isTrue,
    );
  });
}
