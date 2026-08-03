import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/home/nearby_restaurant_service.dart';
import 'package:shopeefood/home/promo_results_page.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    DishImages.debugSetAvailableAssets(const <String>{});
  });

  test('khoảng cách hiển thị phải khớp với toạ độ ghim trên bản đồ', () {
    // Người dùng ở một vị trí BẤT KỲ (không phải toạ độ mặc định), để bắt luôn
    // trường hợp quán bị ghim quanh một điểm cố định thay vì quanh người dùng.
    const userLat = 10.8231;
    const userLng = 106.6297;

    for (final id in promoConfigIdsForTesting()) {
      final items = promoDistanceCheckForTesting(
        id,
        userLatitude: userLat,
        userLongitude: userLng,
      );

      expect(items, isNotEmpty);
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final actualKm = NearbyRestaurantService.distanceInKm(
          fromLat: userLat,
          fromLng: userLng,
          toLat: item.latitude,
          toLng: item.longitude,
        );

        expect(
          item.distanceKm,
          closeTo(actualKm, 0.001),
          reason:
              'nhóm "$id" món $index hiện ${item.distanceKm}km nhưng điểm ghim '
              'chỉ cách $actualKm km -> số km và vị trí trên bản đồ không khớp',
        );

        // Quán phải nằm quanh NGƯỜI DÙNG, không phải quanh một toạ độ cố định.
        expect(
          actualKm,
          lessThan(2.0),
          reason:
              'nhóm "$id" món $index ghim cách người dùng $actualKm km — quá xa, '
              'nhiều khả năng vẫn đang lệch quanh toạ độ mặc định',
        );
      }
    }
  });

  test('mỗi nhóm khuyến mãi có ít nhất 24 món khác nhau', () {
    for (final id in promoConfigIdsForTesting()) {
      final dishes = promoDishesForTesting(id);

      expect(
        dishes.length,
        greaterThanOrEqualTo(24),
        reason: 'nhóm "$id" chỉ có ${dishes.length} món nên bị lặp trong trang',
      );
      expect(
        dishes.map((name) => DishImages.slugFor(name)).toSet(),
        hasLength(dishes.length),
        reason: 'nhóm "$id" có hai món trùng tên -> trùng ảnh',
      );
    }
  });

  test('một trang khuyến mãi không lặp lại hình nào', () {
    const samples = <(String, String, String)>[
      ('Deal Đỉnh', 'Món hot giảm sâu', 'deal'),
      ('Món Hàn', 'Gà rán, tokbokki', 'korean'),
      ('Mart', 'Nhu yếu phẩm giao nhanh', 'mart'),
      ('Xiên que', 'Ăn vặt buổi tối', 'skewer'),
      ('Katinat', 'Trà sữa và cà phê', 'katinat'),
      ('Freeship', 'Miễn phí giao hàng', 'freeship'),
    ];

    for (final sample in samples) {
      final keys = promoVisualKeysForTesting(
        title: sample.$1,
        subtitle: sample.$2,
        seed: sample.$3,
      );

      expect(keys, hasLength(24));
      expect(
        keys.toSet(),
        hasLength(keys.length),
        reason: 'trang "${sample.$1}" đang lặp ảnh',
      );
      expect(
        keys.every((key) => !key.contains('loremflickr')),
        isTrue,
        reason: 'trang "${sample.$1}" còn dùng ảnh ngẫu nhiên',
      );
    }
  });

  test('preview khuyến mãi luôn dùng tên món thật và ảnh asset thật', () {
    DishImages.debugSetAvailableAssets(_allDishAssets());

    const genericNames = {
      'Combo thêm nước tiết kiệm',
      'Món bán chạy trong ngày',
      'Set no bụng giá tốt',
      'Ưu đãi chỉ có hôm nay',
      'Phần ăn kèm freeship',
    };

    for (final id in promoConfigIdsForTesting()) {
      final names = promoPreviewNamesByIdForTesting(id);
      final sources = promoPreviewImageSourcesByIdForTesting(id);

      expect(names.where(genericNames.contains), isEmpty);
      expect(
        sources.every((source) => source.startsWith('assets/images/dishes/')),
        isTrue,
        reason: 'nhóm "$id" còn preview không có ảnh thật',
      );
    }
  });

  test('ảnh chính của trang khuyến mãi luôn dùng asset thật', () {
    DishImages.debugSetAvailableAssets(_allDishAssets());

    for (final id in promoConfigIdsForTesting()) {
      final sources = promoItemImageSourcesByIdForTesting(id);

      expect(sources, hasLength(24));
      expect(
        sources.every((source) => source.startsWith('assets/images/dishes/')),
        isTrue,
        reason: 'nhóm "$id" còn món chính không có ảnh asset thật',
      );
      expect(
        sources.toSet(),
        hasLength(sources.length),
        reason: 'nhóm "$id" còn món chính bị trùng ảnh',
      );
    }
  });

  test('deal page regression uses exact real photos for screenshot items', () {
    DishImages.debugSetAvailableAssets(_allDishAssets());

    final dishes = promoDishesForTesting('deal');
    final sources = promoItemImageSourcesByIdForTesting('deal');
    final boLucLacIndex = dishes.indexOf('Bò Lúc Lắc Khoai Tây');
    final banhMiChaoIndex = dishes.indexOf('Bánh Mì Chảo Đặc Biệt');

    expect(boLucLacIndex, isNonNegative);
    expect(banhMiChaoIndex, isNonNegative);
    expect(
      sources[boLucLacIndex],
      'assets/images/dishes/bo-luc-lac-khoai-tay.jpg',
    );
    expect(
      sources[banhMiChaoIndex],
      'assets/images/dishes/banh-mi-chao-dac-biet.jpg',
    );
    expect(
      promoPreviewNamesByIdForTesting('deal'),
      isNot(contains('Ưu đãi chỉ có hôm nay')),
    );
  });

  testWidgets('visible promo cards do not render image placeholders', (
    tester,
  ) async {
    DishImages.debugSetAvailableAssets(_allDishAssets());

    await tester.pumpWidget(
      const MaterialApp(
        home: PromoResultsPage(title: 'Deal', subtitle: '', seed: 'deal'),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}

Set<String> _allDishAssets() {
  return Directory('assets/images/dishes')
      .listSync()
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .where((path) => RegExp(r'\.(jpg|jpeg|png|webp)$').hasMatch(path))
      .toSet();
}
