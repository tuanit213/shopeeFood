import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/shopee_food_app.dart';
import 'firebase_options.dart';
import 'orders/order_state.dart';

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

  runApp(const ShopeeFoodApp());
}
