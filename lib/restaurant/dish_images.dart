import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Chọn ảnh cho từng món ăn.
///
/// Cơ chế 2 tầng:
/// 1. **Ảnh riêng của món** — `assets/images/dishes/<slug>.jpg`, trong đó slug
///    sinh tự động từ tên món ("Bún bò Huế" -> `bun-bo-hue`). Chỉ cần thả file
///    đúng tên vào thư mục đó là app tự dùng, KHÔNG phải sửa code.
/// 2. **Ảnh dự phòng theo loại món** — nếu chưa có ảnh riêng thì dùng ảnh gần
///    đúng nhất trong kho `assets/images/restaurants/`.
///
/// [warmUp] đọc danh sách asset thật có trong bundle, nên món chưa có ảnh sẽ
/// không bao giờ gây lỗi "asset not found".
class DishImages {
  static const _dishDirectory = 'assets/images/dishes/';

  static Set<String> _availableAssets = const <String>{};
  static bool _warmedUp = false;

  /// Số ảnh riêng của món đang có trong bundle (dùng để kiểm tra nhanh).
  static int get availableDishImageCount => _availableAssets.length;

  /// Đọc AssetManifest để biết ảnh nào thực sự tồn tại.
  /// Gọi một lần trong `main()` trước `runApp`.
  static Future<void> warmUp() async {
    if (_warmedUp) {
      return;
    }
    _warmedUp = true;

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _availableAssets = manifest
          .listAssets()
          .where((asset) => asset.startsWith(_dishDirectory))
          .toSet();
      debugPrint(
        '[DishImages] có ${_availableAssets.length} ảnh món riêng trong bundle',
      );
    } catch (error) {
      _availableAssets = const <String>{};
      debugPrint('[DishImages] không đọc được AssetManifest: $error');
    }
  }

  /// Đường dẫn ảnh nên dùng cho [dishName].
  static String resolve(String dishName, {String salt = ''}) {
    final slug = slugFor(dishName);
    final preferred = '$_dishDirectory$slug.jpg';
    if (_availableAssets.contains(preferred)) {
      return preferred;
    }

    final preferredPng = '$_dishDirectory$slug.png';
    if (_availableAssets.contains(preferredPng)) {
      return preferredPng;
    }

    return _fallbackFor(dishName, salt: salt);
  }

  /// Real food photo URL ổn định. `lock` khác nhau giúp mỗi món có ảnh riêng,
  /// kể cả khi nhiều món cùng nhóm query như "fried chicken".
  static String remoteUrlFor(String dishName, {String salt = ''}) {
    return _remoteFoodImageFor(dishName, salt: salt);
  }

  /// Bỏ dấu tiếng Việt: "Bún bò Huế" -> "bun bo hue".
  static String asciiOf(String value) => _removeDiacritics(value.toLowerCase());

  /// "Bún bò Huế" -> "bun-bo-hue". Bỏ dấu để tên file dễ gõ và an toàn.
  static String slugFor(String dishName) {
    final normalized = _removeDiacritics(dishName.toLowerCase());
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Ảnh gần đúng nhất trong kho cũ, chọn theo từ khoá trong tên món.
  ///
  /// Lưu ý: `food_09` (ảnh chụp màn hình app) và `food_12` (trùng `food_10`)
  /// bị loại khỏi danh sách này.
  static String _fallbackFor(String dishName, {required String salt}) {
    final name = _removeDiacritics(dishName.toLowerCase());

    for (final rule in _fallbackRules) {
      if (rule.$1.any(name.contains)) {
        return _remoteFoodImageFor('$dishName ${rule.$2}', salt: salt);
      }
    }
    return _remoteFoodImageFor(dishName, salt: salt);
  }

  static String _remoteFoodImageFor(String dishName, {required String salt}) {
    final tags = _photoTagsFor(dishName);
    final lock = _stableLock('$salt|$dishName|$tags');
    return 'https://loremflickr.com/640/480/$tags?lock=$lock';
  }

  static String _photoTagsFor(String dishName) {
    final name = _removeDiacritics(
      dishName.toLowerCase().replaceAll('-', ' '),
    );

    for (final rule in _photoTagRules) {
      if (rule.$1.any(name.contains)) {
        return rule.$2;
      }
    }
    return 'vietnamese-food,dish';
  }

  static int _stableLock(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 1000 + hash % 900000;
  }

  /// (từ khoá không dấu, tên file) — xét theo thứ tự, cụ thể trước tổng quát.
  static const _fallbackRules = <(List<String>, String)>[
    (['com tam', 'com suon', 'suon bi cha', 'suon cay'], 'food_06.jpg'),
    ([
      'pho ',
      'pho bo',
      'pho ga',
      'pho chay',
      'bun bo',
      'bun rieu',
      'bun oc',
      'bun cha ca',
      'bun thit nuong',
      'hu tieu',
      'banh canh',
      'canh cua',
    ], 'food_02.jpg'),
    ([
      'mi xao',
      'mi tron',
      'japchae',
      'mien tron',
      'mi cay',
      'udon',
      'ramen',
      'mi tuoi',
    ], 'food_03.jpg'),
    (['mi y', 'spaghetti', 'pasta', 'pizza'], 'food_04.jpg'),
    ([
      'tra sua',
      'tra dao',
      'tra vai',
      'tra xanh',
      'tra tac',
      'tra da',
      'tra chanh',
      'hong tra',
      'oolong',
      'matcha',
      'sua tuoi',
      'sua chua',
      'ca phe',
      'bac xiu',
      'latte',
      'americano',
      'cappuccino',
      'cold brew',
      'cacao',
      'sinh to',
      'nuoc ep',
      'nuoc mia',
      'sua dau nanh',
      'nuoc ngot',
      'nuoc suoi',
      'tran chau',
      'pudding',
      'thach',
      'kem cheese',
    ], 'food_05.jpg'),
    ([
      'ga ',
      'ga sot',
      'ga ran',
      'ga nuong',
      'ga lac',
      'canh ga',
      'popcorn',
      'burger',
      'hotdog',
      'xuc xich',
      'combo',
      'mieng ga',
    ], 'food_07.jpg'),
    ([
      'bo kho',
      'bo luc lac',
      'thit kho',
      'thit luoc',
      'thit bo',
      'ca kho',
      'lau',
      'pha lau',
      'canh kimchi',
      'canh chua',
      'sup ',
      'chao ',
    ], 'food_08.jpg'),
    (['banh mi', 'banh cuon', 'banh uot', 'xoi '], 'food_10.jpg'),
    ([
      'bun dau',
      'mam tom',
      'cha com',
      'nem chua',
      'dau hu',
      'nom ',
      'goi ',
      'rau ',
      'kim chi',
      'salad',
      'com chay',
      'nam xao',
      'cha chay',
      'trai cay',
      'yaourt',
      'gao lut',
    ], 'food_11.jpg'),
    ([
      'banh trang',
      'xien que',
      'pho mai que',
      'khoai',
      'bap xao',
      'ca vien',
      'trung cut',
      'takoyaki',
      'gyoza',
      'cha gio',
      'trung op la',
    ], 'food_03.jpg'),
    ([
      'oc ',
      'ngheu',
      'so huyet',
      'tom ',
      'muc ',
      'cua ',
      'bach tuoc',
      'hau ',
      'ghe ',
      'ca hoi',
      'hai san',
      'sushi',
      'kimbap',
      'com cuon',
      'bento',
      'cari',
    ], 'food_03.jpg'),
    ([
      'che ',
      'kem ',
      'flan',
      'nep cam',
      'rau cau',
      'waffle',
      'tokbokki',
      'bibimbap',
    ], 'food_05.jpg'),
    (['com '], 'food_01.jpg'),
  ];

  static const _photoTagRules = <(List<String>, String)>[
    (['com tam', 'com suon'], 'vietnamese-broken-rice,grilled-pork'),
    (['com ga hai nam'], 'hainanese-chicken-rice'),
    (['com ga'], 'chicken-rice,vietnamese-food'),
    (['com chien'], 'fried-rice'),
    (['com bo', 'bo luc lac'], 'beef-rice,dish'),
    (['ca kho'], 'braised-fish,rice'),
    (['thit kho'], 'braised-pork,rice'),
    (['bun bo'], 'vietnamese-beef-noodle-soup'),
    (['pho bo', 'pho ga', 'pho chay', 'pho '], 'vietnamese-pho'),
    (['hu tieu'], 'vietnamese-noodle-soup'),
    (['bun thit nuong'], 'vietnamese-grilled-pork-noodles'),
    (['bun rieu'], 'vietnamese-crab-noodle-soup'),
    (['bun dau'], 'vietnamese-tofu,noodles'),
    (['banh canh'], 'vietnamese-thick-noodle-soup'),
    (['mi cay', 'ramen'], 'spicy-ramen'),
    (['mi tron'], 'dry-noodles,pork'),
    (['mi xao'], 'stir-fried-noodles'),
    (['mi y', 'spaghetti'], 'spaghetti,pasta'),
    (['udon'], 'udon-noodles'),
    (['japchae', 'mien tron'], 'korean-japchae'),
    (['tra sua', 'milk tea'], 'boba-milk-tea'),
    (['tra dao'], 'peach-iced-tea'),
    (['tra vai'], 'lychee-iced-tea'),
    (['tra xanh', 'matcha'], 'matcha-latte'),
    (['tra tac', 'tra chanh'], 'iced-tea,lime'),
    (['oolong'], 'oolong-tea'),
    (['sua chua'], 'yogurt-drink,blueberry'),
    (['ca phe sua'], 'vietnamese-iced-coffee'),
    (['ca phe den', 'americano'], 'black-coffee'),
    (['ca phe cot dua'], 'coconut-coffee'),
    (['bac xiu', 'latte', 'cappuccino'], 'latte-coffee'),
    (['cacao'], 'hot-chocolate'),
    (['sinh to'], 'smoothie,avocado'),
    (['nuoc ep'], 'fresh-juice'),
    (['nuoc mia'], 'sugarcane-juice'),
    (['tran chau', 'pudding', 'thach'], 'dessert,topping'),
    (['ga sot han'], 'korean-fried-chicken'),
    (['ga ran', 'ga gion', 'fried chicken'], 'fried-chicken'),
    (['ga nuong'], 'grilled-chicken'),
    (['canh ga'], 'chicken-wings'),
    (['burger'], 'cheeseburger'),
    (['hotdog'], 'hot-dog'),
    (['pizza'], 'pizza'),
    (['khoai tay', 'fries'], 'french-fries'),
    (['banh trang tron'], 'vietnamese-rice-paper-salad'),
    (['banh trang cuon'], 'rice-paper-rolls'),
    (['banh trang nuong'], 'vietnamese-grilled-rice-paper'),
    (['xien que'], 'grilled-skewers,street-food'),
    (['pho mai que'], 'mozzarella-sticks'),
    (['nem chua ran'], 'fried-pork-rolls'),
    (['bap xao'], 'stir-fried-corn'),
    (['ca vien'], 'fried-fish-balls'),
    (['trung cut'], 'quail-eggs'),
    (['xuc xich'], 'grilled-sausage'),
    (['takoyaki'], 'takoyaki'),
    (['gyoza'], 'gyoza'),
    (['goi cuon'], 'vietnamese-spring-rolls'),
    (['cha gio'], 'vietnamese-fried-spring-rolls'),
    (['kimbap'], 'kimbap'),
    (['tokbokki'], 'tteokbokki'),
    (['bibimbap'], 'bibimbap'),
    (['kimchi'], 'kimchi-stew'),
    (['lau'], 'hot-pot'),
    (['oc ', 'ngheu', 'so huyet'], 'seafood,shellfish'),
    (['tom '], 'shrimp-dish'),
    (['muc '], 'grilled-squid'),
    (['cua ', 'ghe '], 'crab-seafood'),
    (['bach tuoc'], 'grilled-octopus'),
    (['hau '], 'grilled-oysters'),
    (['sushi'], 'sushi'),
    (['banh cuon'], 'vietnamese-steamed-rice-rolls'),
    (['xoi'], 'vietnamese-sticky-rice'),
    (['chao'], 'congee'),
    (['banh mi'], 'vietnamese-banh-mi'),
    (['che '], 'vietnamese-dessert'),
    (['kem '], 'ice-cream-dessert'),
    (['flan'], 'caramel-flan'),
    (['waffle'], 'waffle-ice-cream'),
    (['trai cay'], 'fresh-fruit-plate'),
    (['dau hu'], 'fried-tofu'),
    (['nam xao'], 'stir-fried-mushrooms'),
    (['salad'], 'fresh-salad'),
    (['bo kho'], 'beef-stew'),
  ];

  /// Nhóm ký tự có dấu theo từng chữ cái không dấu.
  ///
  /// Cố tình KHÔNG dùng cách ánh xạ hai chuỗi song song theo chỉ số: kiểu đó
  /// chỉ cần lệch một ký tự là sai toàn bộ (đã từng làm "bún" thành "bon").
  static const _diacriticGroups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static String _removeDiacritics(String value) {
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      var replaced = char;
      for (final entry in _diacriticGroups.entries) {
        if (entry.value.contains(char)) {
          replaced = entry.key;
          break;
        }
      }
      buffer.write(replaced);
    }
    return buffer.toString();
  }
}
