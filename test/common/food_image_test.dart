import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/common/food_image.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    DishImages.debugSetAvailableAssets(const {
      'assets/images/dishes/bo-luc-lac-khoai-tay.jpg',
    });
  });

  testWidgets('FoodImage tự đổi source ảnh cũ sang asset thật theo tên món', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FoodImage(
            source: 'https://loremflickr.com/640/480/food?lock=123',
            label: 'Bò Lúc Lắc Khoai Tây',
            width: 80,
            height: 80,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/dishes/bo-luc-lac-khoai-tay.jpg',
    );
  });

  testWidgets('FoodImage khong tu tin URL remote khi khong co asset local', (
    tester,
  ) async {
    DishImages.debugSetAvailableAssets(const <String>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FoodImage(
            source: 'https://example.com/rendered-card.jpg',
            label: 'Mon chua co anh',
            width: 96,
            height: 96,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
