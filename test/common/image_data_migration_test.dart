import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeefood/common/image_data_migration.dart';
import 'package:shopeefood/orders/order_state.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    DishImages.debugSetAvailableAssets(const <String>{});
  });

  test('chuyển giỏ hàng cũ sang khoá mới và loại ảnh cũ khi đọc lên', () async {
    final legacyCart = jsonEncode([
      {
        'id': 'entry-1',
        'status': 'cart',
        'order': {
          'restaurant': {
            'id': 'store-1',
            'name': 'Quán cũ',
            'address': '12 Nguyễn Trãi',
          },
          'items': [
            {
              'id': 'com-tam',
              'name': 'Cơm tấm sườn bì chả',
              'description': 'Món cũ',
              'imageUrl': 'https://loremflickr.com/640/480/food?lock=1',
              'unitPrice': 45000,
              'quantity': 1,
              'toppings': <String>[],
              'note': '',
            },
          ],
          'address': '12 Nguyễn Trãi',
          'receiverName': 'Khách',
          'receiverPhone': '0900000000',
        },
      },
    ]);

    SharedPreferences.setMockInitialValues({
      'shopeefood_order_state_entries_v1': legacyCart,
      'favorite_restaurant_snapshots_v1': '[]',
      'restaurant_cache_v2:10.780:106.690': '{"fetchedAt":0,"items":[]}',
      'restaurant_cache_v3:10.780:106.690': '{"fetchedAt":0,"items":[]}',
      'restaurant_cache_v4:10.780:106.690': '{"fetchedAt":0,"items":[]}',
    });

    await ImageDataMigration.run();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shopeefood_order_state_entries_v1'), isNull);
    expect(prefs.getString('shopeefood_order_state_entries_v2'), legacyCart);
    expect(prefs.getString('favorite_restaurant_snapshots_v1'), isNull);
    expect(prefs.getString('restaurant_cache_v2:10.780:106.690'), isNull);
    expect(prefs.getString('restaurant_cache_v3:10.780:106.690'), isNull);
    expect(prefs.getString('restaurant_cache_v4:10.780:106.690'), isNull);
    expect(
      prefs.getInt('shopeefood_image_data_version'),
      ImageDataMigration.currentVersion,
    );

    OrderState.entries.value = const [];
    await OrderState.hydrate();

    expect(OrderState.entries.value, hasLength(1));
    // Ảnh loremflickr cũ đã bị loại khi đọc lên.
    expect(
      OrderState.entries.value.single.order.items.single.imageUrl,
      isEmpty,
    );

    await OrderState.clearPersisted();
  });

  test('chạy lần hai không ghi đè dữ liệu mới', () async {
    SharedPreferences.setMockInitialValues({
      'shopeefood_image_data_version': ImageDataMigration.currentVersion,
      'shopeefood_order_state_entries_v1': '[]',
    });

    await ImageDataMigration.run();

    final prefs = await SharedPreferences.getInstance();
    // Đã ở phiên bản hiện tại nên migration không đụng vào gì nữa.
    expect(prefs.getString('shopeefood_order_state_entries_v1'), '[]');
  });
}
