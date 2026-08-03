import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/checkout/checkout_models.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    DishImages.debugSetAvailableAssets(const <String>{});
  });

  test('cart item from old saved data migrates duplicated remote image', () {
    final item = CartItem.fromJson(const {
      'id': 'old-cart-com-tam',
      'name': 'Com tam suon bi cha',
      'description': 'Old persisted item',
      'imageUrl': 'https://images.pexels.com/photos/duplicated-food.jpg',
      'unitPrice': 44000,
      'quantity': 1,
      'toppings': <String>[],
      'note': '',
    });

    // Ảnh remote cũ (chưa seed lại) bị loại -> dùng ảnh asset/placeholder.
    expect(item.imageUrl, isEmpty);
    expect(
      DishImages.visualKey(label: 'Com tam suon bi cha', imageUrl: ''),
      'missing:com-tam-suon-bi-cha',
    );
  });
}
