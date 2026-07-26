import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../restaurant/dish_images.dart';

/// Tìm ảnh thật cho từng món qua Pexels API.
///
/// Chỉ dùng lúc nạp dữ liệu (`CatalogSeeder`): URL ảnh được ghi thẳng vào
/// Firestore, nên khi demo app KHÔNG cần API key và không gọi Pexels nữa.
///
/// Key truyền qua dart-define giống Geoapify/Google Maps:
/// `--dart-define=PEXELS_API_KEY=...` (xem `tools/run_app_with_maps_key.ps1`).
class DishImageService {
  static const _apiKey = String.fromEnvironment('PEXELS_API_KEY');
  static const _perPage = 15;
  static const _timeout = Duration(seconds: 8);

  /// Kết quả tìm được của mỗi từ khoá, dùng lại để tiết kiệm lượt gọi API.
  static final Map<String, List<String>> _resultsByQuery = {};

  /// Con trỏ xoay vòng: hai món cùng từ khoá sẽ lấy hai ảnh KHÁC nhau
  /// trong danh sách kết quả -> không bị trùng ảnh.
  static final Map<String, int> _cursorByQuery = {};

  /// Ảnh đã dùng trong quán đang xử lý.
  ///
  /// Pexels hay trả CÙNG một ảnh phổ biến cho nhiều từ khoá khác nhau
  /// (ví dụ "glass of iced tea" và "kumquat lime iced tea"), nên chỉ xoay
  /// vòng theo từng từ khoá là chưa đủ để tránh trùng.
  static final Set<String> _usedInRestaurant = {};

  static bool get hasApiKey => _apiKey.trim().isNotEmpty;

  static void resetCache() {
    _resultsByQuery.clear();
    _cursorByQuery.clear();
    _usedInRestaurant.clear();
  }

  /// Gọi trước khi xử lý mỗi quán để bắt đầu đếm lại ảnh đã dùng.
  static void beginRestaurant() {
    _usedInRestaurant.clear();
  }

  /// `null` = không lấy được ảnh -> caller giữ ảnh asset hiện tại.
  static Future<String?> imageUrlFor(String dishName) async {
    if (!hasApiKey) {
      return null;
    }

    final query = queryFor(dishName);
    var urls = _resultsByQuery[query];
    if (urls == null) {
      urls = await _search(query);
      _resultsByQuery[query] = urls;
      _cursorByQuery[query] = 0;
    }
    if (urls.isEmpty) {
      return null;
    }

    final cursor = _cursorByQuery[query] ?? 0;

    // Ưu tiên ảnh chưa xuất hiện trong quán này.
    for (var offset = 0; offset < urls.length; offset++) {
      final candidate = urls[(cursor + offset) % urls.length];
      if (_usedInRestaurant.add(candidate)) {
        _cursorByQuery[query] = cursor + offset + 1;
        return candidate;
      }
    }

    // Hiếm khi xảy ra: mọi ảnh của từ khoá này đều đã dùng trong quán.
    _cursorByQuery[query] = cursor + 1;
    return urls[cursor % urls.length];
  }

  static Future<List<String>> _search(String query) async {
    try {
      final uri = Uri.https('api.pexels.com', '/v1/search', <String, String>{
        'query': query,
        'per_page': '$_perPage',
        'orientation': 'square',
      });
      final response = await http
          .get(uri, headers: <String, String>{'Authorization': _apiKey})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[DishImageService] "$query" lỗi HTTP ${response.statusCode}',
        );
        return const <String>[];
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final photos = payload['photos'] as List<dynamic>? ?? const [];
      final urls = <String>[];
      for (final photo in photos) {
        if (photo is! Map<String, dynamic>) continue;
        final src = photo['src'] as Map<String, dynamic>?;
        final url = (src?['medium'] ?? src?['large']) as String?;
        if (url != null && url.isNotEmpty) {
          urls.add(url);
        }
      }
      debugPrint('[DishImageService] "$query" -> ${urls.length} ảnh');
      return urls;
    } catch (error) {
      debugPrint('[DishImageService] "$query" lỗi: $error');
      return const <String>[];
    }
  }

  /// Đổi tên món tiếng Việt thành từ khoá tìm ảnh bằng tiếng Anh.
  /// Xét theo thứ tự: quy tắc cụ thể trước, tổng quát sau.
  static String queryFor(String dishName) {
    final name = DishImages.asciiOf(dishName);
    for (final rule in _queryRules) {
      if (rule.$1.any(name.contains)) {
        return rule.$2;
      }
    }
    return 'vietnamese food dish';
  }

  static const _queryRules = <(List<String>, String)>[
    // --- Cơm ---
    (['com tam'], 'vietnamese broken rice grilled pork chop'),
    (['com ga hai nam'], 'hainanese chicken rice'),
    (['com ga'], 'vietnamese chicken rice'),
    (['com chien'], 'fried rice shrimp'),
    (['com bo'], 'beef steak with rice'),
    (['com ca kho'], 'braised fish clay pot rice'),
    (['com thit kho'], 'braised pork belly egg rice'),
    (['com suon'], 'grilled pork chop rice plate'),
    (['com chay'], 'vegetarian rice plate'),
    (['com cuon'], 'korean kimbap rice roll'),
    (['com bento', 'bento'], 'japanese bento box'),
    (['cari', 'ca ri'], 'japanese curry rice katsu'),
    (['gao lut'], 'brown rice chicken bowl'),
    // --- Bún / phở / mì ---
    (['bun bo'], 'vietnamese beef noodle soup'),
    (['pho bo', 'pho ga', 'pho chay', 'pho '], 'vietnamese pho noodle soup'),
    (['hu tieu'], 'vietnamese pork noodle soup'),
    (['bun thit nuong'], 'vietnamese grilled pork noodle bowl'),
    (['bun cha ca'], 'fish cake noodle soup'),
    (['bun rieu'], 'vietnamese crab noodle soup'),
    (['bun oc'], 'snail noodle soup'),
    (['bun dau'], 'vietnamese tofu noodle shrimp paste'),
    (['banh canh'], 'thick noodle crab soup'),
    (['mi cay'], 'korean spicy ramen noodles'),
    (['mi tron'], 'dry mixed noodles pork'),
    (['mi xao'], 'stir fried noodles seafood'),
    (['mi y', 'spaghetti'], 'spaghetti pasta tomato'),
    (['mi tuoi'], 'fresh egg noodles'),
    (['udon'], 'udon noodle soup beef'),
    (['ramen'], 'tonkotsu ramen bowl'),
    (['japchae', 'mien tron'], 'korean japchae glass noodles'),
    // --- Đồ uống ---
    (['tra sua'], 'boba milk tea'),
    (['tra dao'], 'peach iced tea'),
    (['tra vai'], 'lychee iced tea'),
    (['tra xanh'], 'green tea latte'),
    (['tra tac', 'tra chanh'], 'kumquat lime iced tea'),
    (['tra da'], 'glass of iced tea'),
    (['hong tra'], 'milk tea cheese foam'),
    (['oolong'], 'oolong milk tea'),
    (['matcha'], 'matcha latte'),
    (['sua tuoi'], 'fresh milk tapioca pearls'),
    (['sua chua'], 'blueberry yogurt drink'),
    (['ca phe sua'], 'vietnamese iced coffee condensed milk'),
    (['ca phe den'], 'black iced coffee glass'),
    (['ca phe cot dua'], 'coconut coffee'),
    (['bac xiu'], 'iced milk coffee'),
    (['cold brew'], 'cold brew coffee orange'),
    (['americano'], 'americano coffee cup'),
    (['latte'], 'cafe latte art'),
    (['cappuccino'], 'cappuccino cup'),
    (['cacao'], 'hot chocolate cacao cup'),
    (['sinh to'], 'avocado banana smoothie'),
    (['nuoc ep'], 'celery apple juice glass'),
    (['nuoc mia'], 'sugarcane juice glass'),
    (['sua dau nanh'], 'glass of soy milk'),
    (['nuoc ngot'], 'soda can drink'),
    (['nuoc suoi'], 'bottle of water'),
    (['tran chau'], 'tapioca pearls boba'),
    (['pudding'], 'egg pudding dessert'),
    (['kem cheese'], 'cheese foam drink'),
    (['thach'], 'jelly dessert topping'),
    // --- Gà / burger / pizza ---
    (['ga sot han'], 'korean fried chicken sauce'),
    (['ga sot'], 'fried chicken with sauce'),
    (['ga ran', 'ga gion'], 'crispy fried chicken'),
    (['ga nuong'], 'grilled whole chicken'),
    (['ga lac'], 'cheese powder fried chicken'),
    (['canh ga'], 'bbq chicken wings'),
    (['popcorn'], 'popcorn chicken'),
    (['combo'], 'fried chicken combo meal'),
    (['burger'], 'cheese burger'),
    (['hotdog'], 'hot dog cheese'),
    (['pizza'], 'pizza cheese slice'),
    (['banh mi bo toi'], 'garlic bread'),
    // --- Ăn vặt ---
    (['khoai tay chien', 'khoai pho mai'], 'french fries cheese'),
    (['khoai lang ken'], 'sweet potato fritters'),
    (['banh trang tron'], 'vietnamese rice paper salad'),
    (['banh trang cuon'], 'rice paper roll snack'),
    (['banh trang nuong'], 'vietnamese grilled rice paper'),
    (['xien que'], 'grilled skewers street food'),
    (['pho mai que'], 'mozzarella cheese sticks'),
    (['nem chua ran'], 'fried fermented pork roll'),
    (['nem chua'], 'vietnamese fermented pork'),
    (['bap xao'], 'stir fried corn butter'),
    (['ca vien'], 'fried fish balls skewer'),
    (['trung cut'], 'quail eggs tamarind sauce'),
    (['trung op la'], 'fried egg sunny side up'),
    (['xuc xich'], 'grilled sausage skewer'),
    (['takoyaki'], 'takoyaki octopus balls'),
    (['gyoza'], 'gyoza dumplings'),
    (['goi kho bo'], 'green papaya beef jerky salad'),
    (['cha gio'], 'vietnamese fried spring rolls'),
    (['goi cuon'], 'vietnamese fresh spring rolls'),
    // --- Hàn ---
    (['kimbap'], 'korean kimbap roll'),
    (['tokbokki'], 'tteokbokki rice cake'),
    (['bibimbap'], 'korean bibimbap'),
    (['canh kimchi'], 'kimchi stew tofu'),
    (['kim chi'], 'kimchi cabbage'),
    // --- Lẩu ---
    (['lau'], 'vietnamese hot pot'),
    (['rau nhung'], 'fresh vegetables plate'),
    (['hai san nhung'], 'raw seafood platter'),
    // --- Hải sản ---
    (['oc huong', 'oc mong tay', 'oc '], 'stir fried snails garlic'),
    (['ngheu'], 'steamed clams lemongrass'),
    (['so huyet'], 'grilled cockles'),
    (['tom hap'], 'steamed shrimp'),
    (['muc nuong'], 'grilled squid'),
    (['cua rang'], 'tamarind crab'),
    (['bach tuoc'], 'grilled octopus'),
    (['hau nuong'], 'grilled oysters cheese'),
    (['ghe hap'], 'steamed crab'),
    (['ca hoi'], 'grilled salmon fillet'),
    (['sushi'], 'salmon sushi plate'),
    (['salad rong bien'], 'seaweed salad'),
    // --- Món sáng / bánh ---
    (['banh cuon'], 'vietnamese steamed rice rolls'),
    (['banh uot'], 'vietnamese wet rice cake pork'),
    (['xoi'], 'vietnamese sticky rice chicken'),
    (['chao'], 'rice porridge congee'),
    (['banh mi'], 'vietnamese banh mi sandwich'),
    // --- Tráng miệng ---
    (['che '], 'vietnamese sweet dessert soup'),
    (['kem oc que'], 'ice cream cone chocolate'),
    (['kem dua'], 'coconut ice cream'),
    (['kem '], 'ice cream dessert'),
    (['flan'], 'caramel flan dessert'),
    (['nep cam'], 'black sticky rice yogurt'),
    (['rau cau'], 'coconut jelly dessert'),
    (['waffle'], 'waffle with ice cream'),
    (['trai cay'], 'fresh fruit plate'),
    (['yaourt'], 'greek yogurt granola'),
    // --- Chay / canh / khác ---
    (['dau hu'], 'fried tofu dish'),
    (['nam xao'], 'stir fried mushrooms'),
    (['cha chay'], 'vegetarian patty'),
    (['rau luoc'], 'boiled green vegetables'),
    (['canh chua'], 'vietnamese sour soup'),
    (['canh cua'], 'crab soup with vegetables'),
    (['sup '], 'pumpkin cream soup'),
    (['bo kho'], 'beef stew with bread'),
    (['thit luoc'], 'sliced boiled pork'),
    (['thit bo'], 'sliced raw beef plate'),
    (['cha com'], 'vietnamese green rice pork patty'),
    (['nom '], 'banana flower salad'),
    (['salad'], 'fresh salad bowl'),
  ];
}
