import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/shopee_food_app.dart';
import 'common/image_data_migration.dart';
import 'firebase_options.dart';
import 'orders/order_state.dart';
import 'restaurant/dish_images.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 80;
  imageCache.maximumSizeBytes = 50 << 20;

  // Không để Firebase init fail (network, config sai, chặn cookie...)
  // làm app trắng xóa trên web. Log lỗi và vẫn chạy app.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed: $e');
    debugPrint('$st');
  }

  // Biết trước ảnh món nào có trong bundle để không bao giờ gọi asset không
  // tồn tại. Phải chạy TRƯỚC khi đọc giỏ hàng vì lúc đọc đã chuẩn hoá ảnh.
  await DishImages.warmUp();

  // Dọn ảnh cũ còn nằm trong SharedPreferences (giỏ hàng, quán đã lưu, cache).
  await ImageDataMigration.run();
  imageCache.clear();
  imageCache.clearLiveImages();

  await OrderState.hydrate();

  runApp(const ShopeeFoodApp());
}
