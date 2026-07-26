import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/shopee_food_app.dart';
import 'firebase_options.dart';
import 'orders/order_state.dart';
import 'restaurant/dish_images.dart';
import 'tools/dish_image_service.dart';

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

  await OrderState.hydrate();
  // Biết trước ảnh món nào có trong bundle để không bao giờ gọi asset không tồn tại.
  await DishImages.warmUp();

  // Kiểm tra key Pexels đã được nhúng lúc build chưa (chỉ in có/không,
  // không in giá trị key). Key là hằng số compile-time nên phải build lại
  // mới có, hot reload không đủ.
  debugPrint(
    '[Config] PEXELS_API_KEY: '
    '${DishImageService.hasApiKey ? "ĐÃ CÓ - seeder sẽ lấy ảnh thật" : "CHƯA CÓ - seeder dùng ảnh asset"}',
  );

  runApp(const ShopeeFoodApp());
}
