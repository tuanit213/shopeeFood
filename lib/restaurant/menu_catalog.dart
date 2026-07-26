/// Bộ menu riêng cho từng loại quán.
///
/// Trước đây menu được sinh từ 4 bộ theme chung, nên quán bún bò lại bán cơm
/// gà và lẩu tomyum. File này định nghĩa món ăn theo đúng `category` của quán,
/// cộng thêm các nhóm "món thêm" / "nước uống" dùng chung — vừa thực tế vừa
/// không phải viết tay 550 món.
class DishSpec {
  final String name;
  final String description;
  final int price;

  const DishSpec(this.name, this.description, this.price);
}

class MenuBlueprint {
  final String title;
  final List<DishSpec> dishes;

  const MenuBlueprint(this.title, this.dishes);
}

class MenuCatalog {
  /// Trả về `null` khi category không có bộ menu riêng (ví dụ quán lấy từ
  /// Geoapify với category chung `restaurant`) — lúc đó caller dùng bộ theme cũ.
  static List<MenuBlueprint>? blueprintFor({
    required String category,
    required String name,
  }) {
    final key = _normalizeCategory(category);
    final mains = _mainsByCategory[key];
    if (mains == null) {
      return null;
    }

    final ordered = _prioritise(mains, name);
    return <MenuBlueprint>[
      MenuBlueprint(_mainTitleByCategory[key] ?? 'Món chính', ordered),
      ..._extrasFor(key),
    ];
  }

  static String _normalizeCategory(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'cafe' => 'coffee',
      'bakery' => 'breakfast',
      'milktea' || 'milk-tea' => 'milk_tea',
      'fastfood' || 'fast-food' => 'fast_food',
      _ => value,
    };
  }

  /// Đưa "món tủ" trùng với tên quán lên đầu danh sách.
  /// Ví dụ "Bún bò Huế O Thương" -> món "Bún bò Huế" đứng đầu.
  static List<DishSpec> _prioritise(List<DishSpec> dishes, String name) {
    final tokens = _tokens(name);
    final indexed = <(int, int, DishSpec)>[];
    for (var i = 0; i < dishes.length; i++) {
      indexed.add((_score(dishes[i].name, tokens), i, dishes[i]));
    }
    // Sắp xếp: điểm cao trước; cùng điểm thì giữ thứ tự gốc (sort của Dart
    // không đảm bảo stable nên phải so sánh thêm index).
    indexed.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return indexed.map((entry) => entry.$3).toList();
  }

  static Set<String> _tokens(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^0-9a-zà-ỹ]+', unicode: true))
        .where((token) => token.length > 1)
        .toSet();
  }

  static int _score(String dishName, Set<String> tokens) {
    if (tokens.isEmpty) {
      return 0;
    }

    final dishTokens = _tokens(dishName);
    var score = dishTokens.where(tokens.contains).length;

    // Cộng điểm khi TỪ ĐẦU của món trùng tên quán. Nhờ vậy quán "Burger bò
    // phô mai" ưu tiên "Burger bò đúp" thay vì "Pizza phô mai kéo sợi" —
    // hai món này cùng khớp 2 từ nên cần tiêu chí phân định rõ hơn.
    final firstWord = dishName
        .toLowerCase()
        .split(RegExp(r'[^0-9a-zà-ỹ]+', unicode: true))
        .firstWhere((token) => token.isNotEmpty, orElse: () => '');
    if (firstWord.isNotEmpty && tokens.contains(firstWord)) {
      score += 2;
    }

    return score;
  }

  static List<MenuBlueprint> _extrasFor(String key) {
    const drinkShops = {'milk_tea', 'coffee'};
    if (drinkShops.contains(key)) {
      return const [
        MenuBlueprint('Topping thêm', _toppings),
        MenuBlueprint('Ăn kèm', _lightSnacks),
      ];
    }
    if (key == 'dessert') {
      return const [
        MenuBlueprint('Topping thêm', _toppings),
        MenuBlueprint('Nước uống', _drinks),
      ];
    }
    return const [
      MenuBlueprint('Món thêm', _sides),
      MenuBlueprint('Nước uống', _drinks),
    ];
  }

  static const _mainTitleByCategory = <String, String>{
    'rice': 'Cơm phần',
    'noodle': 'Bún - Phở - Hủ tiếu',
    'milk_tea': 'Trà sữa - Trà trái cây',
    'coffee': 'Cà phê - Thức uống',
    'fast_food': 'Gà - Burger',
    'korean': 'Món Hàn',
    'snack': 'Ăn vặt',
    'hotpot': 'Lẩu',
    'western': 'Pizza - Mì Ý',
    'breakfast': 'Món sáng',
    'dessert': 'Chè - Kem',
    'vegetarian': 'Món chay',
    'japanese': 'Món Nhật',
    'seafood': 'Ốc - Hải sản',
    'healthy': 'Món thanh nhẹ',
    'vietnamese': 'Món Việt',
  };

  static const _sides = <DishSpec>[
    DishSpec('Chả giò', 'Chiên giòn, ăn kèm rau sống', 25000),
    DishSpec('Trứng ốp la', 'Lòng đào, thêm vào phần chính', 10000),
    DishSpec('Kim chi cải thảo', 'Chua cay, muối theo ngày', 15000),
    DishSpec('Đậu hũ chiên giòn', 'Nóng giòn, chấm nước tương', 15000),
    DishSpec('Thêm thịt bò', 'Phần bò thêm cho món chính', 25000),
    DishSpec('Bánh mì không', 'Ổ mới nướng, chấm nước sốt', 3000),
  ];

  static const _drinks = <DishSpec>[
    DishSpec('Trà tắc', 'Ly lớn, ít ngọt', 15000),
    DishSpec('Trà đá', 'Trà mát lạnh miễn phí đá', 5000),
    DishSpec('Nước ngọt lon', 'Pepsi / Coca / Sprite', 18000),
    DishSpec('Nước suối', 'Chai 500ml', 10000),
    DishSpec('Sữa đậu nành', 'Nhà làm, ấm hoặc lạnh', 12000),
    DishSpec('Nước mía', 'Ép tươi, thêm tắc', 15000),
  ];

  static const _toppings = <DishSpec>[
    DishSpec('Trân châu đen', 'Dai mềm, nấu mỗi 4 tiếng', 8000),
    DishSpec('Pudding trứng', 'Mềm mịn, vị trứng sữa', 10000),
    DishSpec('Thạch dừa', 'Giòn nhẹ, thơm dừa', 8000),
    DishSpec('Kem cheese', 'Mặn nhẹ, phủ mặt ly', 12000),
    DishSpec('Trân châu trắng', 'Giòn dai, ngọt thanh', 8000),
    DishSpec('Thạch nhài', 'Thơm hoa nhài', 8000),
  ];

  static const _lightSnacks = <DishSpec>[
    DishSpec('Khoai tây lắc phô mai', 'Khoai giòn, bột phô mai phủ đều', 29000),
    DishSpec('Xúc xích quay', 'Ăn kèm tương cay', 22500),
    DishSpec('Gà lắc phô mai', 'Gà viên chiên, bột phô mai', 45000),
    DishSpec('Bánh tráng nướng', 'Trứng cút, khô bò, mỡ hành', 25000),
    DishSpec('Bánh flan caramel', 'Flan mềm, caramel đắng nhẹ', 22000),
    DishSpec('Phô mai que', 'Phô mai kéo sợi, vỏ xù', 35000),
  ];

  static const _mainsByCategory = <String, List<DishSpec>>{
    'rice': [
      DishSpec('Cơm tấm sườn bì chả', 'Sườn nướng than, bì, chả trứng', 59000),
      DishSpec('Cơm gà xối mỡ', 'Gà giòn da, cơm chiên tỏi', 62000),
      DishSpec('Cơm gà nướng mật ong', 'Gà nướng mềm, sốt mật ong', 65000),
      DishSpec('Cơm sườn trứng ốp la', 'Sườn ướp đậm, trứng lòng đào', 55000),
      DishSpec('Cơm chiên Dương Châu', 'Tôm, lạp xưởng, đậu hà lan', 52000),
      DishSpec('Cơm bò lúc lắc', 'Bò xào, khoai tây chiên', 79000),
      DishSpec('Cơm cá kho tộ', 'Cá basa kho tiêu, canh chua', 62000),
      DishSpec('Cơm thịt kho trứng', 'Thịt kho nước dừa, dưa cải', 55000),
      DishSpec('Cơm gà Hải Nam', 'Gà luộc da vàng, cơm nấu mỡ gà', 68000),
      DishSpec('Cơm sườn cây', 'Sườn cây nướng, mỡ hành', 72000),
    ],
    'noodle': [
      DishSpec('Bún bò Huế', 'Nước dùng đậm, bò bắp, giò heo', 65000),
      DishSpec('Phở bò tái nạm', 'Phở nóng, thịt bò mềm', 59000),
      DishSpec('Phở gà ta', 'Gà xé, nước dùng trong', 55000),
      DishSpec('Hủ tiếu Nam Vang', 'Tôm, thịt, gan, trứng cút', 62000),
      DishSpec('Hủ tiếu khô', 'Sốt riêng, nước dùng để riêng', 62000),
      DishSpec('Bún thịt nướng', 'Thịt nướng than, nước mắm chua ngọt', 48000),
      DishSpec('Bún chả cá', 'Chả cá chiên, thì là', 52000),
      DishSpec('Mì trộn xá xíu', 'Mì dai, xá xíu, trứng lòng đào', 55000),
      DishSpec('Bánh canh cua', 'Cua, chả cá, nấm rơm', 69000),
      DishSpec('Bún riêu cua', 'Riêu cua, đậu hũ, cà chua', 52000),
    ],
    'milk_tea': [
      DishSpec('Trà sữa truyền thống', 'Trân châu đen, thạch nhà làm', 34500),
      DishSpec('Trà sữa trân châu đường đen', 'Sữa tươi, caramel nâu', 43000),
      DishSpec('Trà sữa khoai môn', 'Khoai môn béo, trân châu', 43000),
      DishSpec('Hồng trà macchiato', 'Kem cheese mặn nhẹ', 41000),
      DishSpec('Trà đào cam sả', 'Đào miếng, cam vàng, sả thơm', 39000),
      DishSpec('Trà vải hoa hồng', 'Vải tươi, hương hoa hồng', 39000),
      DishSpec('Sữa tươi trân châu', 'Sữa tươi Đà Lạt, trân châu trắng', 40000),
      DishSpec('Matcha latte đậu đỏ', 'Matcha Nhật, đậu đỏ mềm', 45000),
      DishSpec('Oolong sữa', 'Trà oolong đậm vị', 38000),
      DishSpec('Sữa chua việt quất', 'Việt quất, sữa chua mịn', 42000),
    ],
    'coffee': [
      DishSpec('Cà phê sữa đá', 'Pha phin, sữa đặc Ông Thọ', 29000),
      DishSpec('Cà phê đen đá', 'Đậm, ít ngọt', 25000),
      DishSpec('Bạc xỉu', 'Nhiều sữa, ít cà phê', 32000),
      DishSpec('Cà phê cốt dừa', 'Cốt dừa béo, cà phê đậm', 45000),
      DishSpec('Cold brew cam vàng', 'Ủ lạnh 18 tiếng, cam tươi', 49000),
      DishSpec('Americano', 'Espresso pha loãng, chua nhẹ', 35000),
      DishSpec('Latte', 'Sữa nóng đánh mịn', 42000),
      DishSpec('Cappuccino', 'Bọt sữa dày, quế thơm', 42000),
      DishSpec('Cacao nóng', 'Cacao nguyên chất, sữa tươi', 38000),
      DishSpec('Trà tắc mật ong', 'Tắc tươi, mật ong rừng', 28000),
    ],
    'fast_food': [
      DishSpec('Gà giòn cay 1 miếng', 'Gà chiên giòn, vị cay', 39000),
      DishSpec('Combo 2 miếng gà', 'Gà, khoai tây và nước ngọt', 79000),
      DishSpec('Burger gà cay', 'Gà giòn, sốt cay, rau tươi', 65000),
      DishSpec('Burger bò phô mai', 'Bò nướng, phô mai lát', 69000),
      DishSpec('Khoai tây chiên', 'Giòn nóng, sốt tự chọn', 35000),
      DishSpec('Gà popcorn', 'Gà viên giòn cay nhẹ', 45000),
      DishSpec('Cánh gà BBQ', 'Phủ sốt BBQ, nướng than', 59000),
      DishSpec('Hotdog phô mai', 'Xúc xích, phô mai, ketchup', 42000),
      DishSpec('Mì Ý sốt bò bằm', 'Sốt cà chua, bò bằm', 79000),
      DishSpec('Salad bắp cải', 'Mát nhẹ, cân vị món chiên', 25000),
    ],
    'korean': [
      DishSpec('Gà sốt Hàn Quốc', 'Sốt gochujang cay ngọt', 69000),
      DishSpec('Gà sốt phô mai', 'Phô mai kéo sợi, cay nhẹ', 75000),
      DishSpec('Mì cay hải sản', '7 cấp độ cay, tôm mực', 75000),
      DishSpec('Mì cay bò Mỹ', 'Bò Mỹ, xúc xích, nấm', 79000),
      DishSpec('Tokbokki phô mai', 'Bánh gạo dai, sốt cay', 55000),
      DishSpec('Kimbap bò', 'Cơm cuộn rong biển, bò xào', 45000),
      DishSpec('Cơm trộn Bibimbap', 'Rau củ, trứng, sốt cay', 65000),
      DishSpec('Canh kimchi thịt heo', 'Chua cay, đậu hũ non', 59000),
      DishSpec('Miến trộn Japchae', 'Miến khoai, rau củ xào', 62000),
      DishSpec('Cơm cuộn thanh cua', 'Thanh cua, trứng, dưa leo', 48000),
    ],
    'snack': [
      DishSpec('Bánh tráng trộn', 'Khô bò, trứng cút, xoài xanh', 35000),
      DishSpec('Bánh tráng cuốn sốt bơ', 'Sốt bơ trứng muối béo nhẹ', 42000),
      DishSpec('Xiên que thập cẩm', 'Cá viên, bò viên, tôm viên', 49000),
      DishSpec('Phô mai que chiên', 'Phô mai kéo sợi, vỏ xù', 35000),
      DishSpec('Nem chua rán', 'Chiên nóng, chấm tương cay', 39000),
      DishSpec('Khoai lang kén', 'Vỏ giòn, nhân khoai mềm', 29000),
      DishSpec('Bắp xào tôm khô', 'Bắp Mỹ, bơ, tôm khô', 32000),
      DishSpec('Gỏi khô bò', 'Đu đủ, khô bò, đậu phộng', 39000),
      DishSpec('Cá viên chiên', 'Phần lớn, kèm rau răm', 39000),
      DishSpec('Trứng cút sốt me', 'Sốt me chua ngọt', 35000),
    ],
    'hotpot': [
      DishSpec('Lẩu Thái tomyum', 'Chua cay, sả ớt, hải sản', 199000),
      DishSpec('Lẩu cá kèo lá giang', 'Cá kèo tươi, chua dịu', 189000),
      DishSpec('Lẩu gà lá é', 'Gà ta, lá é Phú Yên', 199000),
      DishSpec('Lẩu hải sản chua cay', 'Tôm, mực, nghêu', 229000),
      DishSpec('Lẩu nấm chay', 'Sáu loại nấm, nước dùng rau củ', 159000),
      DishSpec('Combo lẩu 2 người', 'Lẩu, rau, mì và nước', 259000),
      DishSpec('Rau nhúng lẩu', 'Đĩa rau theo mùa', 35000),
      DishSpec('Hải sản nhúng thêm', 'Tôm, mực, cá viên', 89000),
      DishSpec('Đậu hũ non nhúng lẩu', 'Mềm, thấm nước lẩu', 25000),
      DishSpec('Mì tươi nhúng lẩu', 'Mì trứng dai', 20000),
    ],
    'western': [
      DishSpec('Pizza phô mai kéo sợi', 'Bốn loại phô mai', 149000),
      DishSpec('Pizza hải sản', 'Tôm, mực, thanh cua', 169000),
      DishSpec('Pizza bò BBQ', 'Bò nướng, hành tây, sốt BBQ', 165000),
      DishSpec('Mì Ý sốt kem nấm', 'Kem tươi, nấm mỡ', 89000),
      DishSpec('Burger bò đúp', 'Hai lớp bò, phô mai cheddar', 99000),
      DishSpec('Khoai tây chiên phô mai', 'Phủ sốt phô mai nóng', 45000),
      DishSpec('Gà nướng nguyên phần', 'Nửa con, ướp thảo mộc', 159000),
      DishSpec('Salad Caesar', 'Xà lách romaine, sốt Caesar', 65000),
      DishSpec('Súp bí đỏ', 'Kem tươi, hạt bí rang', 45000),
      DishSpec('Bánh mì bơ tỏi', 'Nướng giòn, bơ tỏi thơm', 35000),
    ],
    'breakfast': [
      DishSpec('Bánh cuốn nhân thịt', 'Tráng mỏng, chả lụa, hành phi', 40000),
      DishSpec('Bánh cuốn chả lụa', 'Chả lụa nhà làm, nước mắm pha', 42000),
      DishSpec('Bánh ướt thịt nướng', 'Thịt nướng than, rau thơm', 45000),
      DishSpec('Xôi gà xé', 'Xôi mềm, gà xé, mỡ hành', 38000),
      DishSpec('Xôi mặn đầy đủ', 'Lạp xưởng, chả, trứng cút', 40000),
      DishSpec('Cháo sườn non', 'Cháo mềm, sườn non, quẩy', 42000),
      DishSpec('Cháo gà lá chanh', 'Cháo nhuyễn, gà xé', 40000),
      DishSpec('Bánh mì trứng ốp la', 'Hai trứng, pate, rau', 30000),
      DishSpec('Bánh mì thịt nướng', 'Thịt nướng, dưa chua', 32000),
      DishSpec('Bún riêu sáng', 'Riêu cua, huyết, đậu hũ', 45000),
    ],
    'dessert': [
      DishSpec('Chè Thái sầu riêng', 'Sầu riêng, nước cốt dừa', 45000),
      DishSpec('Chè khúc bạch', 'Phô mai béo, nhãn, hạnh nhân', 40000),
      DishSpec('Chè bưởi', 'Cùi bưởi giòn, đậu xanh', 35000),
      DishSpec('Kem ốc quế chocolate', 'Ốc quế giòn, kem đậm', 25000),
      DishSpec('Kem dừa Thái', 'Trái dừa tươi, đậu phộng', 55000),
      DishSpec('Bánh flan caramel dừa', 'Flan mềm, cốt dừa', 25000),
      DishSpec('Sữa chua nếp cẩm', 'Nếp cẩm dẻo, sữa chua nhà làm', 32000),
      DishSpec('Rau câu dừa', 'Nhiều lớp, thơm dừa', 28000),
      DishSpec('Waffle kem tươi', 'Nướng nóng, kem vani', 49000),
      DishSpec('Trái cây dĩa', 'Bốn loại theo mùa', 42000),
    ],
    'vegetarian': [
      DishSpec('Cơm chay thập cẩm', 'Bốn món chay, canh rong biển', 55000),
      DishSpec('Bún riêu chay', 'Riêu đậu hũ, cà chua', 48000),
      DishSpec('Phở chay nấm hương', 'Nước dùng rau củ, nấm hương', 50000),
      DishSpec('Đậu hũ sốt cà chua', 'Đậu hũ non, sốt cà đậm', 42000),
      DishSpec('Nấm xào rau củ', 'Ba loại nấm, dầu hào chay', 52000),
      DishSpec('Chả chay chiên giòn', 'Chả nhà làm, chấm tương', 39000),
      DishSpec('Gỏi cuốn chay', 'Đậu hũ, rau thơm, sốt me', 35000),
      DishSpec('Canh chua chay', 'Bạc hà, thơm, đậu bắp', 40000),
      DishSpec('Mì xào chay giòn', 'Mì chiên giòn, rau củ', 48000),
      DishSpec('Rau luộc chấm chao', 'Rau theo mùa, chao đỏ', 32000),
    ],
    'japanese': [
      DishSpec('Sushi cá hồi', 'Sáu miếng, cá hồi Na Uy', 89000),
      DishSpec('Sushi tổng hợp', 'Mười miếng, năm loại nhân', 129000),
      DishSpec('Cơm bento gà teriyaki', 'Gà sốt teriyaki, salad, canh', 95000),
      DishSpec('Cơm cá hồi áp chảo', 'Cá hồi áp chảo, sốt teriyaki', 119000),
      DishSpec('Mì udon bò', 'Sợi udon dai, bò mềm', 85000),
      DishSpec('Mì ramen tonkotsu', 'Nước hầm xương, trứng lòng đào', 99000),
      DishSpec('Takoyaki bạch tuộc', 'Sáu viên, cá bào và mayo', 45000),
      DishSpec('Gyoza chiên', 'Sáu chiếc, nhân thịt rau', 55000),
      DishSpec('Salad rong biển', 'Rong biển tươi, mè rang', 42000),
      DishSpec('Cơm cà ri Nhật', 'Cà ri sánh, thịt gà chiên xù', 89000),
    ],
    'seafood': [
      DishSpec('Ốc hương xào tỏi', 'Tỏi phi, bơ thơm', 89000),
      DishSpec('Ốc móng tay xào me', 'Sốt me chua ngọt', 79000),
      DishSpec('Nghêu hấp sả', 'Sả ớt, nước mắm gừng', 65000),
      DishSpec('Sò huyết nướng mỡ hành', 'Nướng than, mỡ hành', 95000),
      DishSpec('Tôm hấp bia', 'Tôm sú, hấp bia sả', 129000),
      DishSpec('Mực nướng sa tế', 'Mực tươi, sa tế cay', 119000),
      DishSpec('Cua rang me', 'Cua thịt, sốt me đậm', 259000),
      DishSpec('Bạch tuộc nướng', 'Nướng than, muối ớt xanh', 139000),
      DishSpec('Hàu nướng phô mai', 'Sáu con, phô mai béo', 99000),
      DishSpec('Ghẹ hấp bia', 'Ghẹ chắc thịt, chấm muối tiêu', 189000),
    ],
    'healthy': [
      DishSpec('Gỏi cuốn tôm thịt', 'Rau tươi, sốt đậu phộng', 39000),
      DishSpec('Gỏi cuốn cá hồi', 'Cá hồi, bơ, rau mầm', 59000),
      DishSpec('Salad ức gà', 'Ức gà nướng, sốt mè rang', 62000),
      DishSpec('Salad cá ngừ', 'Cá ngừ, trứng luộc, sốt mè', 65000),
      DishSpec('Salad bơ trứng', 'Bơ sáp, trứng, hạt chia', 59000),
      DishSpec('Cơm gạo lứt ức gà', 'Gạo lứt, ức gà, bông cải', 72000),
      DishSpec('Súp bí đỏ hạt sen', 'Ít kem, vị ngọt tự nhiên', 45000),
      DishSpec('Nước ép cần tây táo', 'Ép tươi, không thêm đường', 45000),
      DishSpec('Sinh tố bơ chuối', 'Bơ sáp, chuối, sữa hạt', 49000),
      DishSpec('Yaourt trái cây', 'Sữa chua Hy Lạp, granola', 42000),
    ],
    'vietnamese': [
      DishSpec('Bún đậu mắm tôm đầy đủ', 'Đậu giòn, chả cốm, thịt luộc', 79000),
      DishSpec('Bún đậu chả cốm', 'Chả cốm Hà Nội, đậu chiên', 69000),
      DishSpec('Đậu hũ chiên phồng', 'Chiên nóng từng mẻ', 35000),
      DishSpec('Chả cốm thêm', 'Cốm tươi, thịt xay', 45000),
      DishSpec('Nem chua Thanh Hoá', 'Chua dịu, tỏi ớt', 39000),
      DishSpec('Thịt luộc mắm tôm', 'Ba rọi luộc, riềng sả', 55000),
      DishSpec('Bún riêu cua đồng', 'Riêu cua đồng, cà chua', 52000),
      DishSpec('Bún ốc chuối đậu', 'Ốc nhồi, chuối xanh, đậu', 62000),
      DishSpec('Nộm hoa chuối', 'Hoa chuối, lạc rang', 42000),
      DishSpec('Canh cua rau đay', 'Cua đồng giã tay', 45000),
    ],
  };
}
