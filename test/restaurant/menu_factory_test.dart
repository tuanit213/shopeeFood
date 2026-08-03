import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/restaurant/dish_images.dart';
import 'package:shopeefood/restaurant/restaurant_detail_page.dart';

void main() {
  setUp(() {
    // Chưa có ảnh thật -> món thiếu ảnh rơi về placeholder.
    DishImages.debugSetAvailableAssets(const <String>{});
  });

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
              item.imageUrl.isEmpty ||
              item.imageUrl.startsWith('assets/images/dishes/'),
        ),
        isTrue,
        reason: 'menu còn dùng ảnh ngoài kho ảnh thật của món',
      );
    }
  });

  test('restaurant menus use real assets when bundle has dish photos', () {
    DishImages.debugSetAvailableAssets(_allDishAssets());
    final samples = <RestaurantDetailInput>[
      _restaurant(category: 'coffee', name: 'Katinat Coffee & Tea'),
      _restaurant(category: 'snack', name: 'Xien que nuong'),
      _restaurant(category: 'fast_food', name: 'Ga ran Seoul'),
      _restaurant(category: 'rice', name: 'Com tam suon bi cha'),
      _restaurant(category: 'noodle', name: 'Bun bo Hue O Thuong'),
      _restaurant(category: 'restaurant', name: 'Quan an gan ban'),
    ];

    for (final restaurant in samples) {
      final items = MenuFactory.sectionsFor(
        restaurant,
      ).expand((section) => section.items).toList();
      final missing = items
          .where((item) => !item.imageUrl.startsWith('assets/images/dishes/'))
          .map((item) => '${item.name} -> ${DishImages.slugFor(item.name)}')
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            '${restaurant.category} has items without real asset image: $missing',
      );
      expect(
        items.map((item) => item.imageUrl).toSet(),
        hasLength(items.length),
        reason: '${restaurant.category} has duplicate real asset images',
      );
    }
  });

  test('breakfast menu maps visible items to matching real photos', () {
    DishImages.debugSetAvailableAssets(_allDishAssets());
    final items = MenuFactory.sectionsFor(
      _restaurant(category: 'breakfast', name: 'Bánh mì thịt nướng'),
    ).expand((section) => section.items);

    final byName = {for (final item in items) item.name: item.imageUrl};
    expect(byName['Xôi gà xé'], 'assets/images/dishes/xoi-ga-xe.jpg');
    expect(byName['Xôi mặn đầy đủ'], 'assets/images/dishes/xoi-man-day-du.jpg');
    expect(byName['Cháo sườn non'], 'assets/images/dishes/chao-suon-non.jpg');
    expect(
      byName['Cháo gà lá chanh'],
      'assets/images/dishes/chao-ga-la-chanh.jpg',
    );
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
      final items = MenuFactory.sectionsFor(
        restaurant,
      ).expand((section) => section.items).toList();
      // So sánh theo HÌNH nhìn thấy được, không theo chuỗi URL.
      final visuals = items
          .map(
            (item) =>
                DishImages.visualKey(label: item.name, imageUrl: item.imageUrl),
          )
          .toList();

      expect(
        visuals.toSet(),
        hasLength(visuals.length),
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
    imageUrl: 'https://loremflickr.com/640/480/food?lock=991001',
    openNow: true,
  );
}

Set<String> _allDishAssets() {
  return Directory('assets/images/dishes')
      .listSync()
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .where((path) => RegExp(r'\.(jpg|jpeg|png|webp)$').hasMatch(path))
      .toSet();
}
