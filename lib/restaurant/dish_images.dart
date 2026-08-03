import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../common/dish_slug.dart';

/// Nhóm món ăn — dùng để phân loại dữ liệu và style thẻ.
enum DishCategory {
  noodleSoup,
  rice,
  grill,
  friedChicken,
  seafood,
  milkTea,
  coffee,
  juice,
  dessert,
  snack,
  bread,
  hotpot,
  vegetarian,
  western,
  korean,
  japanese,
  mart,
  generic,
}

/// Chọn ảnh cho từng món ăn.
///
/// Cơ chế 3 tầng, xếp theo độ tin cậy giảm dần:
/// 1. **Ảnh thật của món** — `assets/images/dishes/<slug>.jpg`, trong đó slug
///    sinh tự động từ tên món ("Bún bò Huế" -> `bun-bo-hue`). Chỉ cần thả file
///    đúng tên vào thư mục đó là app tự dùng, KHÔNG phải sửa code.
/// 2. **Alias hiển thị đã duyệt** — tên quán/deal trên UI trỏ tới ảnh món thật
///    phù hợp, không dùng đoán fuzzy.
/// 3. **Ảnh thật trên CDN** — URL http(s) do seeder ghi vào Firestore. Chỉ dùng
///    khi bundle chưa có ảnh local phù hợp và document có
///    `imageVersion >= approvedImageVersion`.
/// 4. **Placeholder trung tính** — [resolve] trả về chuỗi rỗng để lỗi lộ rõ.
///
/// App KHÔNG còn phụ thuộc dịch vụ ảnh ngẫu nhiên (loremflickr) hay asset dùng
/// chung `food_01..12`.
class DishImages {
  static const dishDirectory = 'assets/images/dishes/';

  /// Ảnh cũ dùng chung cho nhiều món — nguyên nhân chính gây cảm giác trùng
  /// lặp. Gặp URL/asset thuộc nhóm này thì bỏ để tránh ảnh sai món.
  static final RegExp _bannedPattern = RegExp(
    r'loremflickr\.com|picsum\.photos|placeholder\.com|placehold\.co'
    r'|assets/images/restaurants/food_(0[1-9]|1[0-2])\.(jpg|png)',
    caseSensitive: false,
  );

  /// Phiên bản dữ liệu ảnh. Chỉ ảnh remote được seed lại từ v2 mới được tin.
  static const int approvedImageVersion = 2;

  static Set<String> _availableAssets = const <String>{};
  static bool _warmedUp = false;

  /// Số ảnh thật của món đang có trong bundle (dùng để kiểm tra nhanh).
  static int get availableDishImageCount => _availableAssets.length;

  @visibleForTesting
  static void debugSetAvailableAssets(Set<String> assets) {
    _availableAssets = assets;
    _warmedUp = true;
  }

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
          .where(
            (asset) =>
                asset.startsWith(dishDirectory) &&
                (asset.endsWith('.jpg') ||
                    asset.endsWith('.jpeg') ||
                    asset.endsWith('.png') ||
                    asset.endsWith('.webp')),
          )
          .toSet();
      debugPrint(
        '[DishImages] có ${_availableAssets.length} ảnh món thật trong bundle',
      );
    } catch (error) {
      _availableAssets = const <String>{};
      debugPrint('[DishImages] không đọc được AssetManifest: $error');
    }
  }

  /// Đường dẫn ảnh nên dùng cho [dishName].
  ///
  /// Trả về `''` khi chưa có ảnh thật đúng slug — lúc đó `FoodImage` hiện
  /// placeholder. Một số nhãn UI không phải tên món (tên quán/deal) được map
  /// qua [_curatedAliasSlugs].
  /// [salt] chỉ còn giữ cho tương thích chữ ký cũ: ảnh bây giờ phụ
  /// thuộc DUY NHẤT vào tên món, nên hai màn hình khác nhau luôn hiện cùng
  /// một hình cho cùng một món.
  static String resolve(String dishName, {String salt = ''}) {
    final slug = slugFor(dishName);
    if (slug.isEmpty) {
      return '';
    }
    final exact = _assetForSlug(slug);
    if (exact.isNotEmpty) {
      return exact;
    }
    return _assetForSlug(_curatedAliasSlugs[slug] ?? '');
  }

  static String _assetForSlug(String slug) {
    if (slug.isEmpty) {
      return '';
    }
    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp']) {
      final candidate = '$dishDirectory$slug$ext';
      if (_availableAssets.contains(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  /// Chuẩn hoá ảnh đọc từ Firestore / SharedPreferences.
  ///
  /// - Luôn ưu tiên ảnh asset thật suy ra từ [label]. Điều này chặn dữ liệu
  ///   Firestore/SharedPreferences cũ đè lên ảnh món đúng bằng URL sai.
  /// - Giữ ảnh asset thật được truyền vào nếu label chưa có ảnh local.
  /// - Giữ URL http(s) khi dữ liệu đã được seed lại ([imageVersion] đủ mới) và
  ///   không có ảnh local phù hợp.
  /// - Mọi thứ còn lại (ảnh dùng chung cũ, loremflickr, URL hỏng, chuỗi rỗng)
  ///   đều quy về `''` để widget hiện placeholder.
  static String normalize({
    required String label,
    String? imageUrl,
    int imageVersion = 0,
  }) {
    final value = imageUrl?.trim() ?? '';
    final local = resolve(label);
    if (local.isNotEmpty) {
      return local;
    }
    if (isLocalDishAsset(value)) {
      return value;
    }
    if (imageVersion >= approvedImageVersion && isApprovedRemote(value)) {
      return value;
    }
    return '';
  }

  /// Khoá "hình nhìn thấy được" của một món.
  ///
  /// Dùng để kiểm tra trùng ảnh THEO NỘI DUNG chứ không theo chuỗi URL.
  static String visualKey({required String label, String? imageUrl}) {
    final normalized = normalize(label: label, imageUrl: imageUrl);
    return normalized.isEmpty ? 'missing:${slugFor(label)}' : normalized;
  }

  static bool isLocalDishAsset(String value) {
    return value.startsWith(dishDirectory) &&
        !isBanned(value) &&
        _availableAssets.contains(value);
  }

  /// URL remote được phép dùng: http(s) thật, không thuộc danh sách cấm.
  static bool isApprovedRemote(String value) {
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return false;
    }
    return !isBanned(value);
  }

  /// Ảnh thuộc kho dùng chung cũ hoặc dịch vụ ảnh ngẫu nhiên.
  static bool isBanned(String value) => _bannedPattern.hasMatch(value);

  /// Bỏ dấu tiếng Việt: "Bún bò Huế" -> "bun bo hue".
  static String asciiOf(String value) => DishSlug.ascii(value);

  /// "Bún bò Huế" -> "bun-bo-hue". Bỏ dấu để tên file dễ gõ và an toàn.
  ///
  /// Dùng chung hàm với script kiểm tra ảnh (`tools/audit_images.dart`).
  static String slugFor(String dishName) => DishSlug.of(dishName);

  /// Số ổn định cho một tên món — còn giữ cho API cũ.
  static int seedFor(String value) => DishSlug.seedOf(value);

  static const _curatedAliasSlugs = <String, String>{
    'banh-mi-chao-co-ba': 'banh-mi-chao-dac-biet',
    'banh-mi-chao-co-ba-cn-23': 'banh-mi-chao-dac-biet',
    'mi-them': 'mi-tuoi-nhung-lau',
    'uu-dai-chi-co-hom-nay': 'deal-no-bung-50k',
  };

  /// Đoán nhóm món từ tên để phân loại giao diện và dữ liệu.
  static DishCategory categoryFor(String dishName) {
    final name = _removeDiacritics(dishName.toLowerCase().replaceAll('-', ' '))
        // "phô mai" sau khi bỏ dấu thành "pho mai" nên trùng với từ khoá
        // "pho " của nhóm bún/phở — dính lại để "Burger bò phô mai" không bị
        // xếp nhầm thành món nước.
        .replaceAll('pho mai', 'phomai');
    for (final rule in _categoryRules) {
      if (rule.$1.any(name.contains)) {
        return rule.$2;
      }
    }
    return DishCategory.generic;
  }

  /// Bảng phân loại theo từ khoá. Xếp từ cụ thể đến chung — dòng đầu tiên
  /// khớp sẽ thắng.
  static const _categoryRules = <(List<String>, DishCategory)>[
    (
      [
        'bun bo',
        'bun rieu',
        'bun cha',
        'bun mam',
        'bun thai',
        'bun oc',
        'bun moc',
        'bun dau',
        'bun thit',
        'pho bo',
        'pho ga',
        'pho chay',
        'pho ',
        'hu tieu',
        'banh canh',
        'mi quang',
        'mien ',
        'bun ',
      ],
      DishCategory.noodleSoup,
    ),
    (
      [
        'kimbap',
        'tokbokki',
        'tteokbokki',
        'bibimbap',
        'kimchi',
        'japchae',
        'jajangmyeon',
        'bulgogi',
        'mandu',
        'han quoc',
        'mi cay',
        'k-food',
        'bibim',
      ],
      DishCategory.korean,
    ),
    (
      [
        'sushi',
        'ramen',
        'udon',
        'bento',
        'teriyaki',
        'sashimi',
        'nhat ban',
        'takoyaki',
        'gyoza',
      ],
      DishCategory.japanese,
    ),
    (
      [
        'ga ran',
        'ga gion',
        'fried chicken',
        'canh ga',
        'ga khong xuong',
        'ga vien',
        'ga sot',
        'ga xoi mo',
        'ga popeyes',
      ],
      DishCategory.friedChicken,
    ),
    (
      [
        'com tam',
        'com suon',
        'com bi',
        'com ga',
        'com chien',
        'com bo',
        'com nieu',
        'com van phong',
        'com hop',
        'com cuon',
        'com bento',
        'com tron',
        'com chay',
        'com ',
      ],
      DishCategory.rice,
    ),
    (
      [
        'nuong',
        'grill',
        'xien',
        'bo la lot',
        'ba chi',
        'suon nuong',
        'hong lo',
        'ho lo',
      ],
      DishCategory.grill,
    ),
    // Món Âu đứng TRƯỚC hải sản: "Pizza hải sản", "Mì Ý sốt hải sản" phải ra
    // nhóm Âu chứ không phải nhóm hải sản.
    (
      [
        'burger',
        'pizza',
        'hotdog',
        'hot dog',
        'mi y',
        'spaghetti',
        'pasta',
        'steak',
        'bo luc lac',
        'my ',
      ],
      DishCategory.western,
    ),
    (
      [
        'oc ',
        'ngheu',
        'so huyet',
        'tom ',
        'muc ',
        'cua ',
        'ghe ',
        'hau ',
        'bach tuoc',
        'ca hoi',
        'hai san',
        'ca vien',
        'chao tom',
        'chả cá',
        'cha ca',
      ],
      DishCategory.seafood,
    ),
    (
      [
        'tra sua',
        'milk tea',
        'tran chau',
        'oolong',
        'hong tra',
        'tra dao',
        'tra vai',
        'tra tac',
        'tra chanh',
        'tra xanh',
        'matcha',
        'tra lai',
        'tra dau',
        'tra sen',
        'tra ',
      ],
      DishCategory.milkTea,
    ),
    (
      [
        'ca phe',
        'cafe',
        'coffee',
        'bac xiu',
        'latte',
        'cappuccino',
        'americano',
        'espresso',
        'cold brew',
        'cacao',
        'macchiato',
      ],
      DishCategory.coffee,
    ),
    (
      [
        'sinh to',
        'nuoc ep',
        'nuoc mia',
        'juice',
        'soda',
        'yakult',
        'nuoc cam',
        'nuoc suoi',
        'nuoc tang luc',
        'da xay',
        'nuoc dua',
      ],
      DishCategory.juice,
    ),
    (
      [
        'che ',
        'kem ',
        'flan',
        'waffle',
        'pudding',
        'thach',
        'sua chua',
        'panna',
        'tiramisu',
        'donut',
        'banh ngot',
        'trai cay',
        'oc que',
        'banh quy',
        'sua tuoi',
      ],
      DishCategory.dessert,
    ),
    (
      [
        'banh trang',
        'khoai tay',
        'fries',
        'nem chua ran',
        'bap xao',
        'trung cut',
        'xuc xich',
        'goi cuon',
        'cha gio',
        'snack',
        'phomai',
        'chan ga',
        'kho ga',
        'an vat',
        'bap rang',
        'rong bien',
      ],
      DishCategory.snack,
    ),
    (
      [
        'banh mi',
        'sandwich',
        'banh bao',
        'banh cuon',
        'xoi',
        'chao ',
        'banh uot',
        'banh xeo',
        'banh khot',
      ],
      DishCategory.bread,
    ),
    (['lau', 'hotpot', 'hot pot', 'tomyum'], DishCategory.hotpot),
    (
      ['chay', 'dau hu', 'nam xao', 'salad', 'rau cu', 'healthy', 'an nhien'],
      DishCategory.vegetarian,
    ),
    (
      [
        'mart',
        'combo nuoc',
        'mi ly',
        'lon ',
        'loc 4',
        'hop lon',
        'mini stop',
        'circle k',
      ],
      DishCategory.mart,
    ),
  ];

  static String _removeDiacritics(String value) =>
      DishSlug.removeDiacritics(value);
}
