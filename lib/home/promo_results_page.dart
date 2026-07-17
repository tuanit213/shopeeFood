import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_pages.dart';
import '../orders/order_state.dart';

class PromoResultsPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String seed;

  const PromoResultsPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final config = _CategoryPromoConfig.resolve(title, subtitle, seed);
    final items = _PromoItem.itemsFor(config);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leadingWidth: 42,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          config.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _PromoHeader(config: config)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => _PromoCard(
                    item: items[index],
                    accent: config.accent,
                    onTap: () => _showPromoItemSheet(
                      context,
                      items[index],
                      config.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoHeader extends StatelessWidget {
  final _CategoryPromoConfig config;

  const _PromoHeader({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      height: 114,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: config.accent.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -32,
            child: _GlowCircle(size: 104, color: Colors.white),
          ),
          Positioned(
            left: -34,
            bottom: -44,
            child: _GlowCircle(size: 118, color: Colors.yellowAccent),
          ),
          Positioned(
            right: 84,
            top: -18,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                width: 46,
                height: 160,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: -34,
            child: _GlowCircle(size: 96, color: Colors.white),
          ),
          Positioned(
            right: 14,
            top: 18,
            child: Text(
              config.emoji,
              style: TextStyle(
                fontSize: config.emoji.length > 2 ? 40 : 48,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.92),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Bấm săn ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 108, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  config.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _HeaderPill(label: config.badge, strong: true),
                    const SizedBox(width: 6),
                    const _HeaderPill(label: '24 món hot', strong: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.13),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final bool strong;

  const _HeaderPill({required this.label, required this.strong});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? Colors.white : Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? AppColors.primary : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final _PromoItem item;
  final Color accent;
  final VoidCallback onTap;

  const _PromoCard({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FoodImage(path: item.image, size: 86),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.restaurant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _DiscountBadge(discount: item.discount, color: accent),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.distanceKm.toStringAsFixed(1)}km · ${item.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatPrice(item.price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatPrice(item.originalPrice),
                        style: const TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _SmallChip(label: item.tagA),
                      _SmallChip(label: item.tagB),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _addPromoItemToCart(context, item),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: EdgeInsets.zero,
                            foregroundColor: accent,
                            side: BorderSide(color: accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text(
                            'Thêm giỏ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _orderPromoItemNow(context, item),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text(
                            'Đặt ngay',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _addPromoItemToCart(BuildContext context, _PromoItem item) {
  OrderState.mergeCartItem(_checkoutOrderForPromoItem(item));
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${item.name} vào giỏ hàng'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
}

void _orderPromoItemNow(BuildContext context, _PromoItem item) {
  final order = OrderState.mergeCartItem(_checkoutOrderForPromoItem(item));
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CheckoutPage(order: order)),
  );
}

CheckoutOrder _checkoutOrderForPromoItem(_PromoItem item) {
  return CheckoutOrder(
    restaurant: CheckoutRestaurantInfo(
      id: 'promo-${_stableId(item.restaurant)}',
      name: item.restaurant,
      address: item.address,
      deliveryMinutes: 12 + (item.distanceKm * 6).round(),
      distanceKm: item.distanceKm,
      latitude: item.latitude,
      longitude: item.longitude,
    ),
    items: [
      CartItem(
        id: item.id,
        name: item.name,
        description: '${item.tagA} · ${item.tagB}',
        imageUrl: item.image,
        unitPrice: item.price,
        quantity: 1,
        toppings: const [],
        note: '',
      ),
    ],
    address: 'Vị trí hiện tại của bạn',
    receiverName: 'Khách hàng',
    receiverPhone: '0961687964',
    deliveryLatitude: _mockUserLatitude,
    deliveryLongitude: _mockUserLongitude,
  );
}

String _stableId(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

class _FoodImage extends StatelessWidget {
  final String path;
  final double size;

  const _FoodImage({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    final image = path.startsWith('assets/')
        ? Image.asset(path, width: size, height: size, fit: BoxFit.cover)
        : Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/images/restaurants/food_01.jpg',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(7), child: image);
  }
}

class _DiscountBadge extends StatelessWidget {
  final int discount;
  final Color color;

  const _DiscountBadge({required this.discount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '-$discount%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;

  const _SmallChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE7FAF7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBDEFE7)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.success,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CategoryPromoConfig {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String emoji;
  final Color accent;
  final List<Color> gradient;
  final List<String> restaurants;
  final List<String> dishes;
  final List<String> images;
  final List<String> tags;

  const _CategoryPromoConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.emoji,
    required this.accent,
    required this.gradient,
    required this.restaurants,
    required this.dishes,
    required this.images,
    required this.tags,
  });

  static _CategoryPromoConfig resolve(
    String title,
    String subtitle,
    String seed,
  ) {
    final key = '$title $subtitle $seed'.toLowerCase();
    if (key.contains('hàn')) return _configs['korean']!;
    if (key.contains('mart')) return _configs['mart']!;
    if (key.contains('xiên') || key.contains('ăn vặt')) {
      return _configs['skewer']!;
    }
    if (key.contains('katinat') || key.contains('trà')) {
      return _configs['katinat']!;
    }
    if (key.contains('đặt trước') || key.contains('dat_truoc')) {
      return _configs['pickup']!;
    }
    if (key.contains('ví') || key.contains('vi_dung_dinh')) {
      return _configs['wallet']!;
    }
    if (key.contains('lễ hội') || key.contains('deal_le_hoi')) {
      return _configs['festival']!;
    }
    if (key.contains('freeship')) return _configs['freeship']!;
    if (key.contains('50k')) return _configs['discount50']!;
    return _configs['deal']!;
  }
}

class _PromoItem {
  final String id;
  final String restaurant;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final int price;
  final int originalPrice;
  final int discount;
  final String image;
  final String tagA;
  final String tagB;

  const _PromoItem({
    required this.id,
    required this.restaurant,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.image,
    required this.tagA,
    required this.tagB,
  });

  static List<_PromoItem> itemsFor(_CategoryPromoConfig config) {
    return List.generate(24, (index) {
      final basePrice = 24000 + (index % 8) * 7000 + (index ~/ 8) * 3000;
      final discount = 30 + (index * 7 + config.id.length) % 36;
      final original = (basePrice / (1 - discount / 100)).round();
      return _PromoItem(
        id: '${config.id}-$index',
        restaurant:
            '${config.restaurants[index % config.restaurants.length]} - CN ${index + 1}',
        name: config.dishes[index % config.dishes.length],
        address: _mockAddresses[index % _mockAddresses.length],
        latitude: _mockRestaurantLatitude(index),
        longitude: _mockRestaurantLongitude(index),
        distanceKm: _mockDistanceKm(index),
        price: basePrice,
        originalPrice: original,
        discount: discount,
        image: config.images[index % config.images.length],
        tagA: config.tags[index % config.tags.length],
        tagB: index.isEven ? 'Mã giảm ${(15 + index % 5 * 5)}K' : 'Freeship',
      );
    });
  }
}

const _localFoodImages = [
  'assets/images/restaurants/food_01.jpg',
  'assets/images/restaurants/food_02.jpg',
  'assets/images/restaurants/food_03.jpg',
  'assets/images/restaurants/food_04.jpg',
  'assets/images/restaurants/food_05.jpg',
  'assets/images/restaurants/food_06.jpg',
  'assets/images/restaurants/food_07.jpg',
  'assets/images/restaurants/food_08.jpg',
  'assets/images/restaurants/food_09.jpg',
  'assets/images/restaurants/food_10.jpg',
  'assets/images/restaurants/food_11.jpg',
  'assets/images/restaurants/food_12.jpg',
  'assets/images/restaurants/z8012876797367_7c4ee6d2ada9b260ac7f3418da89a96e.jpg',
  'assets/images/restaurants/z8013027119797_a35fb13ab19d8353cc20441d4af8c4fd.jpg',
  'assets/images/restaurants/z8013027779592_e15963787d0b4c48816e7ebe9586525e.jpg',
  'assets/images/restaurants/z8013029337805_68dde0e98d54fb09ae5e065a005fa5f1.jpg',
  'assets/images/restaurants/z8032227141313_d28baf514cd92c6c5f146822541a9dd5.jpg',
  'assets/images/restaurants/z8032351973378_ff29bcb18bd1bce983ead2d51dcc65eb.jpg',
  'assets/images/restaurants/z8032351979140_397a93ef0d7fc382b85d741adfd42bd0.jpg',
  'assets/images/restaurants/z8032351989401_0f7d5f62f8fa2e693e80414e106ca10b.jpg',
  'assets/images/restaurants/z8034384381261_f0077ad97e65a21956f0e851d76659bd.jpg',
  'assets/images/restaurants/z8034384386443_314029becb15dc68bb02306a0dff0774.jpg',
  'assets/images/restaurants/z8034384390987_73ddc3d2e989dcb08ce50561e8881cda.jpg',
  'assets/images/restaurants/z8034384391798_ea3bed014844da6bb8b02543737b59aa.jpg',
];

const _mockUserLatitude = 10.7843;
const _mockUserLongitude = 106.5682;

const _mockAddresses = [
  '23 Đường Số 6, Vĩnh Lộc A, Bình Chánh, TP.HCM',
  '41 Nguyễn Thị Tú, Bình Hưng Hòa B, Bình Tân, TP.HCM',
  '12A Đường Công Nghệ Mới, Vĩnh Lộc B, Bình Chánh, TP.HCM',
  '88 Liên Ấp 2-6, Vĩnh Lộc A, Bình Chánh, TP.HCM',
  '19 Hẻm 5 Tây Lân, Bình Trị Đông A, Bình Tân, TP.HCM',
  '56 Đường Số 4, KCN Vĩnh Lộc, Bình Tân, TP.HCM',
  '102 Quách Điêu, Vĩnh Lộc A, Bình Chánh, TP.HCM',
  '7A Đường 1A, An Lạc, Bình Tân, TP.HCM',
];

double _mockRestaurantLatitude(int index) {
  const offsets = [0.0042, -0.0035, 0.0061, -0.0054, 0.0026, -0.0068];
  return _mockUserLatitude + offsets[index % offsets.length];
}

double _mockRestaurantLongitude(int index) {
  const offsets = [0.0034, 0.0062, -0.0048, -0.0029, 0.0071, -0.0064];
  return _mockUserLongitude + offsets[index % offsets.length];
}

double _mockDistanceKm(int index) {
  return 0.7 + (index % 9) * 0.25;
}

final Map<String, _CategoryPromoConfig> _configs = {
  'deal': _CategoryPromoConfig(
    id: 'deal',
    title: 'Deal Đỉnh',
    subtitle: 'Món hot giảm sâu, canh giờ là có giá đẹp',
    badge: 'Giảm tới 65%',
    emoji: '7.7',
    accent: AppColors.primary,
    gradient: const [Color(0xFFFF6B35), Color(0xFFEE4D2D)],
    restaurants: const [
      'Gà Rán Popeyes',
      'Cơm Tấm Đêm',
      'Bún Đậu 1975',
      'Mì Cay Seoul',
    ],
    dishes: const [
      'Combo Gà Giòn + Khoai Tây',
      'Cơm Sườn Nướng Mỡ Hành',
      'Bún Đậu Nem Chua Chả Cốm',
      'Mì Cay Hải Sản Cấp Độ 2',
      'Burger Bò Phô Mai + Pepsi',
      'Bánh Mì Chảo Đặc Biệt',
    ],
    images: _localFoodImages,
    tags: const ['Flash Sale', 'Deal sốc', 'Freeship Xtra'],
  ),
  'korean': _CategoryPromoConfig(
    id: 'korean',
    title: 'Món Hàn',
    subtitle: 'Gà rán, tokbokki, kimbap chuẩn vị Hàn',
    badge: 'Gà Rán -50%',
    emoji: '🍗',
    accent: Color(0xFFE53935),
    gradient: const [Color(0xFFFF7043), Color(0xFFE53935)],
    restaurants: const [
      'Gà Rán K-Food',
      'Chicken Seoul',
      'Kimbap & Tokbokki',
      'Oppa Kitchen',
    ],
    dishes: const [
      'Combo Gà Rán Sốt Hàn + Khoai',
      'Cánh Gà Sốt Cay Hàn Quốc',
      'Tokbokki Phô Mai Cay',
      'Kimbap Cá Ngừ Rong Biển',
      'Cơm Trộn Bulgogi Bibimbap',
      'Mì Tương Đen Jajangmyeon',
    ],
    images: _localFoodImages,
    tags: const ['Mã giảm 25K', 'Chuẩn vị Hàn', 'Freeship'],
  ),
  'mart': _CategoryPromoConfig(
    id: 'mart',
    title: 'Mart',
    subtitle: 'Nhu yếu phẩm, đồ uống, snack giao nhanh',
    badge: 'Giảm 177K',
    emoji: '🛒',
    accent: Color(0xFF00A884),
    gradient: const [Color(0xFF00BFA5), Color(0xFF00796B)],
    restaurants: const [
      'ShopeeFood Mart',
      'Mini Stop',
      'Family Mart',
      'Circle K',
    ],
    dishes: const [
      'Combo Nước Suối + Snack Khoai',
      'Sữa Tươi Ít Đường Lốc 4 Hộp',
      'Mì Ly Hải Sản + Xúc Xích',
      'Trái Cây Cắt Sẵn Hộp Lớn',
      'Bánh Sandwich + Cà Phê Lon',
      'Combo Kem Mát Lạnh',
    ],
    images: _localFoodImages,
    tags: const ['Giao 20 phút', 'Mart deal', 'Mã 177K'],
  ),
  'skewer': _CategoryPromoConfig(
    id: 'skewer',
    title: 'Xiên Que',
    subtitle: 'Ăn vặt đêm, xiên chiên, sốt cay cực cuốn',
    badge: 'Freeship 0Đ',
    emoji: '🍢',
    accent: Color(0xFFF39C12),
    gradient: const [Color(0xFFFFB300), Color(0xFFFF6F00)],
    restaurants: const [
      'Xiên Que Cô Ba',
      'Ăn Vặt Hẻm',
      'Tokbokki & Xiên',
      'Bếp Nướng Ống Tre',
    ],
    dishes: const [
      'Set Xiên Que Sốt Cay',
      'Xúc Xích Quay + Khoai Lắc',
      'Cá Viên Chiên Mắm Tỏi',
      'Nem Chua Rán Hà Nội',
      'Xiên Bò Lá Lốt Nướng',
      'Phô Mai Que Kéo Sợi',
    ],
    images: _localFoodImages,
    tags: const ['Ăn vặt hot', 'Freeship 0Đ', 'Mua 2 giảm'],
  ),
  'katinat': _CategoryPromoConfig(
    id: 'katinat',
    title: 'KATINAT',
    subtitle: 'Trà sữa, cà phê, matcha mát lạnh',
    badge: 'Giảm đến 100K',
    emoji: '🥤',
    accent: Color(0xFF1B8F6A),
    gradient: const [Color(0xFF0F766E), Color(0xFF16A34A)],
    restaurants: const ['KATINAT', 'Phúc Long', 'Mơ Coffee', 'Milk Tea House'],
    dishes: const [
      'Trà Sữa Oolong Nướng',
      'Trà Đào Cam Sả Size L',
      'Matcha Latte Kem Mặn',
      'Cà Phê Sữa Đá Đậm Vị',
      'Trà Lài Vải Tươi',
      'Sữa Tươi Trân Châu Đường Đen',
    ],
    images: _localFoodImages,
    tags: const ['Best seller', 'Giảm 100K', 'Mua 1 tặng 1'],
  ),
  'pickup': _CategoryPromoConfig(
    id: 'pickup',
    title: 'Đặt Trước',
    subtitle: 'Đặt trước, lấy tại quán, khỏi chờ lâu',
    badge: 'Lấy tại quán',
    emoji: '🏪',
    accent: Color(0xFFFF5722),
    gradient: const [Color(0xFFFF8A65), Color(0xFFFF3D00)],
    restaurants: const [
      'Bếp Nhà 5 Phút',
      'Cơm Văn Phòng',
      'Bánh Mì Mẹ Làm',
      'Healthy Box',
    ],
    dishes: const [
      'Cơm Gà Xối Mỡ Đặt Trước',
      'Bánh Mì Heo Quay Giòn Bì',
      'Salad Ức Gà Sốt Mè Rang',
      'Cơm Trưa Sườn Bì Chả',
      'Bún Thịt Nướng Nem',
      'Set Cơm Gia Đình Mini',
    ],
    images: _localFoodImages,
    tags: const ['Không cần chờ', 'Pickup deal', 'Giữ món'],
  ),
  'wallet': _CategoryPromoConfig(
    id: 'wallet',
    title: 'Ví Đúng Đỉnh',
    subtitle: 'Thanh toán ví, hoàn xu, giảm thêm mỗi đơn',
    badge: 'Hoàn xu x5',
    emoji: '💳',
    accent: Color(0xFF7C3AED),
    gradient: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
    restaurants: const [
      'Ví Deal Food',
      'Xu Xtra Kitchen',
      'Pay Day Meals',
      'Hoàn Xu Quán',
    ],
    dishes: const [
      'Combo Cơm Gà Hoàn Xu',
      'Pizza Mini Thanh Toán Ví',
      'Trà Sữa Deal Ví Đúng Đỉnh',
      'Burger Gà Giòn Tặng Xu',
      'Bún Bò Voucher Ví',
      'Mì Ý Sốt Bò Bằm',
    ],
    images: _localFoodImages,
    tags: const ['Hoàn xu', 'Ví giảm thêm', 'Deal ví'],
  ),
  'festival': _CategoryPromoConfig(
    id: 'festival',
    title: 'Deal Lễ Hội',
    subtitle: 'Món tiệc, combo nhóm, ưu đãi mùa lễ',
    badge: 'Giảm 40K',
    emoji: '🎉',
    accent: Color(0xFFEF4444),
    gradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
    restaurants: const [
      'Tiệc Nhà Vui',
      'Gà Nướng Cơm Lam',
      'Lẩu Mini Party',
      'BBQ Home',
    ],
    dishes: const [
      'Combo Gà Nướng Cơm Lam',
      'Lẩu Thái Hải Sản Mini',
      'Set BBQ Heo Bò Nướng',
      'Pizza Hải Sản Size L',
      'Mẹt Bún Đậu Đại Tiệc',
      'Combo Trà Sữa 4 Ly',
    ],
    images: _localFoodImages,
    tags: const ['Combo nhóm', 'Giảm 40K', 'Tiệc ngon'],
  ),
  'freeship': _CategoryPromoConfig(
    id: 'freeship',
    title: 'Freeship Xtra',
    subtitle: 'Quán gần bạn, phí ship nhẹ, chốt đơn nhanh',
    badge: 'Ship 0Đ',
    emoji: '🛵',
    accent: Color(0xFF00A884),
    gradient: const [Color(0xFF06B6D4), Color(0xFF10B981)],
    restaurants: const [
      'Freeship Kitchen',
      'Quán Gần Đây',
      'Ship 0Đ Food',
      'Xtra Deal',
    ],
    dishes: const [
      'Cơm Tấm Freeship Xtra',
      'Bún Bò Huế Gần Bạn',
      'Gà Rán Ship 0Đ',
      'Bánh Canh Cua Nóng',
      'Cháo Sườn Quẩy Giòn',
      'Hủ Tiếu Nam Vang',
    ],
    images: _localFoodImages,
    tags: const ['Freeship Xtra', 'Gần bạn', 'Ship 0Đ'],
  ),
  'discount50': _CategoryPromoConfig(
    id: 'discount50',
    title: 'Giảm 50K',
    subtitle: 'Voucher lớn cho món ngon mỗi ngày',
    badge: 'Voucher 50K',
    emoji: '🏷️',
    accent: Color(0xFFDC2626),
    gradient: const [Color(0xFFDC2626), Color(0xFFFF7A00)],
    restaurants: const [
      'Voucher Food',
      'Deal 50K Quán',
      'Món Ngon Giá Hời',
      'Bếp Ưu Đãi',
    ],
    dishes: const [
      'Combo Burger Bò Giảm 50K',
      'Cơm Gà Mắm Tỏi Voucher',
      'Bún Thái Hải Sản Chua Cay',
      'Mì Trộn Tóp Mỡ Trứng Lòng Đào',
      'Gỏi Cuốn Tôm Thịt',
      'Bánh Xèo Miền Tây',
    ],
    images: _localFoodImages,
    tags: const ['Voucher 50K', 'Giảm mạnh', 'Món hời'],
  ),
};

void _showPromoItemSheet(BuildContext context, _PromoItem item, Color accent) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FoodImage(path: item.image, size: 96),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.restaurant,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatPrice(item.price)}  ·  ${item.tagA}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.distanceKm.toStringAsFixed(1)}km · ${item.address}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _addPromoItemToCart(context, item);
                              Navigator.pop(sheetContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent),
                            ),
                            child: const Text('Thêm giỏ'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _orderPromoItemNow(context, item);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Đặt ngay'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatPrice(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[i]);
  }
  return '${buffer.toString()}đ';
}
