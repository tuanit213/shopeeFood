import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/restaurant/restaurant_detail_page.dart';

void main() {
  test('restaurant menus expand to at least 22 themed dishes', () {
    final samples = <RestaurantDetailInput>[
      _restaurant(category: 'coffee', name: 'Katinat Coffee & Tea'),
      _restaurant(category: 'snack', name: 'Xien que nuong'),
      _restaurant(category: 'fast_food', name: 'Ga ran Seoul'),
      _restaurant(category: 'rice', name: 'Com tam suon bi cha'),
    ];

    for (final restaurant in samples) {
      final sections = MenuFactory.sectionsFor(restaurant);
      final items = sections.expand((section) => section.items).toList();
      expect(items.length, greaterThanOrEqualTo(22));
      expect(items.map((item) => item.id).toSet(), hasLength(items.length));
      expect(
        items.every(
          (item) =>
              item.imageUrl.startsWith('assets/images/dishes/') ||
              item.imageUrl.startsWith('https://loremflickr.com/'),
        ),
        isTrue,
      );
    }
  });

  test('restaurant menus do not reuse food images inside one menu', () {
    final samples = <RestaurantDetailInput>[
      _restaurant(category: 'coffee', name: 'Katinat Coffee & Tea'),
      _restaurant(category: 'snack', name: 'Xien que nuong'),
      _restaurant(category: 'fast_food', name: 'Ga ran Seoul'),
      _restaurant(category: 'rice', name: 'Com tam suon bi cha'),
      _restaurant(category: 'noodle', name: 'Bun bo Hue O Thuong'),
      _restaurant(category: 'restaurant', name: 'Quan an gan ban'),
    ];

    for (final restaurant in samples) {
      final items = MenuFactory.sectionsFor(restaurant)
          .expand((section) => section.items)
          .toList();
      final imageUrls = items.map((item) => item.imageUrl).toList();

      expect(
        imageUrls.toSet(),
        hasLength(imageUrls.length),
        reason: '${restaurant.category} has duplicate dish images',
      );
    }
  });
}

RestaurantDetailInput _restaurant({
  required String category,
  required String name,
}) {
  return RestaurantDetailInput(
    id: 'test-$category',
    name: name,
    address: '12 Nguyen Trai, Quan 1, TP.HCM',
    seed: category,
    category: category,
    rating: 4.6,
    distance: 1.2,
    time: 20,
    sold: 100,
    imageUrl: 'assets/images/restaurants/food_01.jpg',
    openNow: true,
  );
}
