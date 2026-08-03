import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/home/nearby_restaurant_service.dart';
import 'package:shopeefood/home/restaurant_repository.dart';
import 'package:shopeefood/location/location_service.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    DishImages.debugSetAvailableAssets(const <String>{});
  });

  test(
    'địa chỉ quán mẫu phải khớp với khu vực của toạ độ, không bịa quận khác',
    () {
      // Người dùng ở Vĩnh Lộc A, Bình Chánh.
      const location = AppLocation(
        latitude: 10.7843,
        longitude: 106.5682,
        address: 'Vĩnh Lộc A, Bình Chánh, TP.HCM',
        isFallback: true,
      );

      final seeded = RestaurantRepository.localSeedFor(location);
      expect(seeded, isNotEmpty);

      for (final item in seeded) {
        final km = NearbyRestaurantService.distanceInKm(
          fromLat: location.latitude,
          fromLng: location.longitude,
          toLat: item.latitude,
          toLng: item.longitude,
        );

        // Quán mẫu được đặt ngay quanh người dùng...
        expect(
          km,
          lessThan(1.0),
          reason: '"${item.name}" ghim cách người dùng ${km}km',
        );

        // ...nên địa chỉ BẮT BUỘC phải nói về khu vực đó. Trước đây địa chỉ được
        // bịa từ danh sách đường trung tâm ("Lê Văn Sỹ, Quận 3"), khiến thẻ quán
        // hiện 0.3km nhưng địa chỉ lại cách nhà người dùng hơn chục km.
        expect(
          item.address,
          contains('Bình Chánh'),
          reason:
              '"${item.name}" ghim cách người dùng ${km}km nhưng địa chỉ ghi '
              '"${item.address}" — không thuộc khu vực của toạ độ đó',
        );
      }
    },
  );

  test(
    'fallback location returns rich seeded restaurants around user',
    () async {
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
      expect(
        result.restaurants.every((item) => item.latitude != 10.78),
        isTrue,
      );
      expect(
        result.restaurants.every(
          (item) => item.address.contains('TP. Ho Chi Minh'),
        ),
        isTrue,
      );

      // Mỗi quán phải ra một hình khác nhau. Quán chưa có ảnh thật thì
      // `photoUrl` rỗng và app dùng ảnh asset/placeholder thay vì ảnh sai.
      final visuals = result.restaurants
          .map(
            (item) =>
                DishImages.visualKey(label: item.name, imageUrl: item.photoUrl),
          )
          .toList();
      expect(visuals.toSet(), hasLength(visuals.length));
      expect(
        result.restaurants.every(
          (item) =>
              (item.photoUrl ?? '').isEmpty ||
              DishImages.isLocalDishAsset(item.photoUrl!),
        ),
        isTrue,
      );
    },
  );

  test('cached or firestore restaurant image is normalized', () {
    final listing = RestaurantListing.fromJson(const {
      'id': 'old-firestore-restaurant',
      'name': 'Com tam suon bi cha',
      'address': '12 Nguyen Trai, Quan 1, TP.HCM',
      'latitude': 10.78,
      'longitude': 106.69,
      'category': 'rice',
      'photoUrl': 'https://images.pexels.com/photos/reused-food.jpg',
    });

    // Ảnh cũ trong Firestore chưa có `imageVersion` nên bị loại: quán sẽ
    // dùng asset/placeholder thay vì ảnh dùng chung với quán khác.
    expect(listing.photoUrl, isEmpty);
  });
}
