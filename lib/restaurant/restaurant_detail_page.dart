import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../address/geoapify_address_service.dart';
import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_pages.dart';
import '../common/food_image.dart';
import '../orders/order_state.dart';
import 'dish_images.dart';
import 'menu_catalog.dart';
import 'menu_repository.dart';

class RestaurantDetailInput {
  final String id;
  final String name;
  final String address;
  final String seed;
  final String category;
  final double? rating;
  final double distance;
  final int time;
  final int sold;
  final String? imageUrl;
  final bool openNow;
  final double latitude;
  final double longitude;
  final double customerLatitude;
  final double customerLongitude;

  const RestaurantDetailInput({
    required this.id,
    required this.name,
    required this.address,
    required this.seed,
    required this.category,
    required this.rating,
    required this.distance,
    required this.time,
    required this.sold,
    required this.imageUrl,
    required this.openNow,
    this.latitude = 10.7843,
    this.longitude = 106.5682,
    this.customerLatitude = 10.7843,
    this.customerLongitude = 106.5682,
  });
}

class RestaurantDetailPage extends StatefulWidget {
  final RestaurantDetailInput restaurant;

  const RestaurantDetailPage({super.key, required this.restaurant});

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  static const _favoritePrefsKey = 'favorite_restaurant_ids_v1';
  static const _favoriteSnapshotPrefsKey = 'favorite_restaurant_snapshots_v2';

  List<MenuSection> _sections = const [];
  List<MenuItemData> _popularItems = const [];
  final List<CartItem> _cartItems = [];
  String _searchQuery = '';
  bool _isFavorite = false;

  /// Địa chỉ ĐÚNG với toạ độ ghim trên bản đồ (`widget.restaurant.latitude`/
  /// `longitude`), lấy qua reverse geocoding thật. `null` khi chưa tải xong,
  /// không có API key, hoặc gọi mạng thất bại — khi đó dùng lại
  /// `widget.restaurant.address` (chuỗi gõ tay, có thể lệch khỏi toạ độ) qua
  /// getter [_displayAddress] nên màn hình không bao giờ trống địa chỉ.
  String? _resolvedShopAddress;
  static const _resolvedShopAddressPrefsKey = 'shop_address_resolved_v1';

  String get _displayAddress {
    final resolved = _resolvedShopAddress?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return widget.restaurant.address;
  }

  int get _cartCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  int get _cartTotal => _cartItems.fold(0, (sum, item) => sum + item.lineTotal);
  int get _cartDiscount => _cartTotal >= 100000 ? 20000 : 0;
  List<MenuSection> get _visibleSections {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _sections;
    return _sections
        .map((section) {
          final items = section.items
              .where(
                (item) =>
                    item.name.toLowerCase().contains(query) ||
                    item.description.toLowerCase().contains(query) ||
                    section.title.toLowerCase().contains(query),
              )
              .toList();
          return MenuSection(title: section.title, items: items);
        })
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Hiện menu offline ngay để không có màn hình chờ trống, sau đó nâng cấp
    // lên dữ liệu thật từ Firestore khi tải xong.
    _applySections(MenuFactory.sectionsFor(widget.restaurant));
    final existingCart = OrderState.cartForRestaurant(widget.restaurant.id);
    if (existingCart != null) {
      _cartItems.addAll(existingCart.order.items);
    }
    _loadFavoriteState();
    _loadMenuFromServer();
    _resolveAccurateShopAddress();
  }

  /// Đảm bảo địa chỉ hiển thị KHỚP với đúng điểm ghim trên bản đồ, thay vì
  /// một chuỗi địa chỉ dữ liệu mẫu gõ tay độc lập với toạ độ. Chạy nền, không
  /// chặn hiển thị trang; nếu không có key/mạng thì giữ nguyên hành vi cũ.
  Future<void> _resolveAccurateShopAddress() async {
    final restaurant = widget.restaurant;
    if (restaurant.latitude.abs() <= 0.001 &&
        restaurant.longitude.abs() <= 0.001) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    // Khoá cache gồm cả toạ độ (làm tròn 5 chữ số ~1.1m): nếu sau này toạ độ
    // quán đổi, cache cũ tự động không khớp nữa thay vì hiện địa chỉ cũ sai.
    final cacheKey =
        '$_resolvedShopAddressPrefsKey'
        '_${restaurant.id}'
        '_${restaurant.latitude.toStringAsFixed(5)}'
        '_${restaurant.longitude.toStringAsFixed(5)}';

    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      if (mounted) setState(() => _resolvedShopAddress = cached);
      return;
    }

    final resolved = await GeoapifyAddressService.reverseExact(
      restaurant.latitude,
      restaurant.longitude,
    );
    if (resolved == null || resolved.trim().isEmpty) return;

    await prefs.setString(cacheKey, resolved);
    if (!mounted) return;
    setState(() => _resolvedShopAddress = resolved);
  }

  void _applySections(List<MenuSection> sections) {
    _sections = sections;
    _popularItems = sections
        .expand((section) => section.items)
        .take(4)
        .toList();
  }

  Future<void> _loadMenuFromServer() async {
    final remoteSections = await MenuRepository.fetchSections(
      widget.restaurant.id,
    );
    if (!mounted || remoteSections == null || remoteSections.isEmpty) {
      return;
    }

    setState(() => _applySections(remoteSections));
  }

  Future<void> _loadFavoriteState() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritePrefsKey) ?? const [];
    if (!mounted) return;
    setState(() => _isFavorite = favorites.contains(widget.restaurant.id));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritePrefsKey)?.toSet() ?? {};
    final nextFavorite = !favorites.contains(widget.restaurant.id);
    if (nextFavorite) {
      favorites.add(widget.restaurant.id);
      await _saveFavoriteSnapshot(prefs);
    } else {
      favorites.remove(widget.restaurant.id);
      await _removeFavoriteSnapshot(prefs);
    }
    await prefs.setStringList(_favoritePrefsKey, favorites.toList()..sort());
    if (!mounted) return;
    setState(() => _isFavorite = nextFavorite);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(nextFavorite ? 'Đã lưu quán' : 'Đã bỏ lưu quán'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  Future<void> _saveFavoriteSnapshot(SharedPreferences prefs) async {
    final raw = prefs.getString(_favoriteSnapshotPrefsKey);
    final snapshots = _decodeFavoriteSnapshots(raw)
      ..removeWhere((item) => item['id'] == widget.restaurant.id)
      ..insert(0, {
        'id': widget.restaurant.id,
        'name': widget.restaurant.name,
        'address': _displayAddress,
        'category': widget.restaurant.category,
        'imageUrl': widget.restaurant.imageUrl,
        'rating': widget.restaurant.rating,
        'distance': widget.restaurant.distance,
        'time': widget.restaurant.time,
        'openNow': widget.restaurant.openNow,
        'latitude': widget.restaurant.latitude,
        'longitude': widget.restaurant.longitude,
        'customerLatitude': widget.restaurant.customerLatitude,
        'customerLongitude': widget.restaurant.customerLongitude,
      });
    await prefs.setString(_favoriteSnapshotPrefsKey, jsonEncode(snapshots));
  }

  Future<void> _removeFavoriteSnapshot(SharedPreferences prefs) async {
    final raw = prefs.getString(_favoriteSnapshotPrefsKey);
    final snapshots = _decodeFavoriteSnapshots(raw)
      ..removeWhere((item) => item['id'] == widget.restaurant.id);
    if (snapshots.isEmpty) {
      await prefs.remove(_favoriteSnapshotPrefsKey);
      return;
    }
    await prefs.setString(_favoriteSnapshotPrefsKey, jsonEncode(snapshots));
  }

  List<Map<String, dynamic>> _decodeFavoriteSnapshots(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .where((item) => (item['id'] as String?)?.isNotEmpty == true)
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _openMenuSearch() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _RestaurantMenuSearchDelegate(
        restaurantName: widget.restaurant.name,
        sections: _sections,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _searchQuery = result);
  }

  Future<void> _addItem(MenuItemData item) async {
    final configured = await showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.46,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, controller) =>
            ToppingBottomSheet(item: item, scrollController: controller),
      ),
    );

    if (configured == null || !mounted) return;
    setState(() => _mergeConfiguredItem(configured));
    OrderState.upsertCart(_currentCheckoutOrder());
  }

  void _mergeConfiguredItem(CartItem configured) {
    final index = _cartItems.indexWhere(
      (item) =>
          item.id == configured.id &&
          item.note == configured.note &&
          _sameStringList(item.toppings, configured.toppings),
    );
    if (index < 0) {
      _cartItems.add(configured);
      return;
    }

    final oldItem = _cartItems[index];
    _cartItems[index] = oldItem.copyWith(
      quantity: oldItem.quantity + configured.quantity,
    );
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  CheckoutOrder _currentCheckoutOrder() {
    final restaurant = widget.restaurant;
    return CheckoutOrder(
      restaurant: CheckoutRestaurantInfo(
        id: restaurant.id,
        name: restaurant.name,
        address: _displayAddress,
        deliveryMinutes: restaurant.time,
        distanceKm: restaurant.distance,
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
      ),
      items: List<CartItem>.unmodifiable(_cartItems),
      // LƯU Ý: đây là địa chỉ GIAO HÀNG (của khách), không phải địa chỉ quán.
      // Trước đây rơi về `restaurant.address` khi trống — sai về mặt dữ liệu
      // vì `deliveryLatitude/Longitude` bên dưới là toạ độ GPS thật của khách
      // (`restaurant.customerLatitude/Longitude`), không phải toạ độ quán;
      // hiện chuỗi địa chỉ của quán ở đây khiến người dùng đọc thấy "giao đến
      // <địa chỉ quán>" dù điểm giao thực tế là vị trí hiện tại của họ.
      address: 'Vị trí hiện tại của bạn',
      receiverName: 'Khách hàng',
      receiverPhone: '0961687964',
      deliveryLatitude: restaurant.customerLatitude,
      deliveryLongitude: restaurant.customerLongitude,
    );
  }

  void _openCheckout() {
    final order = _currentCheckoutOrder();
    OrderState.upsertCart(order);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutPage(order: order)),
    );
  }

  Future<void> _openCartPreview() async {
    if (_cartItems.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => _RestaurantCartSheet(
        restaurantName: widget.restaurant.name,
        items: List<CartItem>.unmodifiable(_cartItems),
        discount: _cartDiscount,
        onQuantityChanged: _updateCartLineQuantity,
        onCheckout: () {
          Navigator.pop(context);
          _openCheckout();
        },
      ),
    );
  }

  void _updateCartLineQuantity(CartItem item, int quantity) {
    setState(() {
      final index = _cartItems.indexWhere((line) => _sameCartLine(line, item));
      if (index < 0) return;
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
      }
    });

    if (_cartItems.isEmpty) {
      OrderState.removeCart(widget.restaurant.id);
      return;
    }
    OrderState.upsertCart(_currentCheckoutOrder());
  }

  bool _sameCartLine(CartItem a, CartItem b) {
    return a.id == b.id &&
        a.note == b.note &&
        _sameStringList(a.toppings, b.toppings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _HeaderSliver(
            restaurant: widget.restaurant,
            onSearchTap: _openMenuSearch,
          ),
          SliverToBoxAdapter(
            child: _RestaurantInfo(
              restaurant: widget.restaurant,
              displayAddress: _displayAddress,
              isFavorite: _isFavorite,
              onFavoriteTap: _toggleFavorite,
            ),
          ),
          SliverToBoxAdapter(
            child: _DeliveryAndDeals(restaurant: widget.restaurant),
          ),
          SliverToBoxAdapter(
            child: _PopularItems(items: _popularItems, onAdd: _addItem),
          ),
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: _SearchQueryBanner(
                query: _searchQuery,
                onClear: () => setState(() => _searchQuery = ''),
              ),
            ),
          if (_visibleSections.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _MenuTabsDelegate(sections: _visibleSections),
            ),
          if (_visibleSections.isEmpty)
            const SliverToBoxAdapter(child: _NoMenuSearchResult())
          else
            for (final section in _visibleSections)
              SliverToBoxAdapter(
                child: _MenuSection(section: section, onAdd: _addItem),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      bottomNavigationBar: _cartCount == 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                height: 52,
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _openCartPreview,
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_basket_outlined,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -3,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white),
                              ),
                              child: Text(
                                '$_cartCount',
                                style: const TextStyle(
                                  color: Color(0xFF8A1F10),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            checkoutFormatPrice(_cartTotal),
                            style: const TextStyle(
                              color: Color(0xFF212121),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _cartDiscount > 0
                                ? 'Đã tự áp mã giảm ${checkoutFormatPrice(_cartDiscount)}'
                                : 'Chạm giỏ để kiểm tra món',
                            style: TextStyle(
                              color: _cartDiscount > 0
                                  ? AppColors.success
                                  : const Color(0xFF757575),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _openCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Giao hàng',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
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

class _HeaderSliver extends StatelessWidget {
  final RestaurantDetailInput restaurant;
  final VoidCallback onSearchTap;

  const _HeaderSliver({required this.restaurant, required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final heroImageUrl = _normalizedRestaurantHeroImage(restaurant);
    return SliverAppBar(
      expandedHeight: restaurant.imageUrl == null ? 86 : 184,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      leading: _CircleIconButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.maybePop(context),
      ),
      title: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSearchTap,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF757575),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tìm món tại ${restaurant.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        _CircleIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
        _CircleIconButton(
          icon: Icons.share_outlined,
          onTap: () => _showAction(context, 'Chia sẻ quán'),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: restaurant.imageUrl == null
          ? null
          : FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _RemoteFoodImage(
                    imageUrl: heroImageUrl,
                    label: restaurant.name,
                    radius: 0,
                    showLabel: false,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.16),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.14),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 42,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        height: 25,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Đơn nhóm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RestaurantInfo extends StatelessWidget {
  final RestaurantDetailInput restaurant;
  final String displayAddress;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const _RestaurantInfo({
    required this.restaurant,
    required this.displayAddress,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final rating = restaurant.rating ?? 4.6;
    final comments = restaurant.sold >= 100
        ? '100+ Bình luận'
        : '${math.max(9, restaurant.sold ~/ 12)} Bình luận';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 6),
                child: Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFFFB300),
                  size: 16,
                ),
              ),
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 15,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? AppColors.primary
                      : const Color(0xFF757575),
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i + 1 <= rating.round()
                      ? Icons.star_rounded
                      : Icons.star_half_rounded,
                  color: const Color(0xFFFFB300),
                  size: 13,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${rating.toStringAsFixed(1)} ($comments) | ${restaurant.time} phút | ${restaurant.distance.toStringAsFixed(1)}km',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (displayAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: Color(0xFF9E9E9E),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    displayAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryAndDeals extends StatelessWidget {
  final RestaurantDetailInput restaurant;

  const _DeliveryAndDeals({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final deliveryAt = DateTime.now().add(
      Duration(minutes: restaurant.time + 8),
    );
    final hh = deliveryAt.hour.toString().padLeft(2, '0');
    final mm = deliveryAt.minute.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(top: 6),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        children: [
          _InfoLine(
            icon: Icons.local_shipping_outlined,
            iconColor: AppColors.success,
            title: 'Giao ngay',
            value: 'Dự kiến giao lúc $hh:$mm',
            action: 'Thay đổi',
          ),
          const SizedBox(height: 9),
          const _InfoLine(
            icon: Icons.flash_on_rounded,
            iconColor: Color(0xFFFF9800),
            title: 'Flash Sale',
            value: 'Giữ giá trong 12:00',
            action: 'Săn deal',
          ),
          const SizedBox(height: 9),
          const _InfoLine(
            icon: Icons.local_offer_rounded,
            iconColor: AppColors.primary,
            title: 'Ưu đãi dành cho bạn',
            value: '',
            action: 'Xem thêm',
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final minimums = [40000, 60000, 55000, 70000, 90000];
                return _VoucherChip(minimum: minimums[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularItems extends StatelessWidget {
  final List<MenuItemData> items;
  final ValueChanged<MenuItemData> onAdd;

  const _PopularItems({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 11, 0, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Món phổ biến',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                return _PopularItemCard(item: items[index], onAdd: onAdd);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<MenuSection> sections;

  const _MenuTabsDelegate({required this.sections});

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (_, index) {
          final active = index == 0;
          return Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              sections[index].title,
              style: TextStyle(
                color: active ? AppColors.primary : const Color(0xFF212121),
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MenuTabsDelegate oldDelegate) {
    return oldDelegate.sections != sections;
  }
}

class _MenuSection extends StatelessWidget {
  final MenuSection section;
  final ValueChanged<MenuItemData> onAdd;

  const _MenuSection({required this.section, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${section.title} (${section.items.length})',
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final item in section.items)
            _MenuItemRow(item: item, onAdd: () => onAdd(item)),
        ],
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final MenuItemData item;
  final VoidCallback onAdd;

  const _MenuItemRow({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEDEDED), width: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RemoteFoodImage(
            imageUrl: item.imageUrl,
            label: item.name,
            width: 68,
            height: 68,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 13,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  '${item.sold} đã bán | ${item.likes} lượt thích',
                  style: const TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatPrice(item.price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _AddButton(onTap: onAdd),
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

class _PopularItemCard extends StatelessWidget {
  final MenuItemData item;
  final ValueChanged<MenuItemData> onAdd;

  const _PopularItemCard({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 238,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEDEDED)),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Stack(
            children: [
              _RemoteFoodImage(
                imageUrl: item.imageUrl,
                label: item.name,
                width: 88,
                height: 88,
                radius: 0,
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  color: const Color(0xFFFFB300),
                  child: Text(
                    '${item.sold} đã bán',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatPrice(item.price),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _AddButton(onTap: () => onAdd(item)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String action;

  const _InfoLine({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF424242), fontSize: 12),
            ),
          ),
        ] else
          const Spacer(),
        Text(
          action,
          style: const TextStyle(color: Color(0xFF757575), fontSize: 12),
        ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF9E9E9E)),
      ],
    );
  }
}

class _VoucherChip extends StatelessWidget {
  final int minimum;

  const _VoucherChip({required this.minimum});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 114,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7FAF7),
        border: Border.all(color: const Color(0xFFBDEFE7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Giảm 50%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Đơn từ ${minimum ~/ 1000}K',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchQueryBanner extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _SearchQueryBanner({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang lọc món: "$query"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF424242),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Xóa lọc',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMenuSearchResult extends StatelessWidget {
  const _NoMenuSearchResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 46, 24, 56),
      child: const Column(
        children: [
          Icon(Icons.manage_search_rounded, color: Color(0xFFFFB6A8), size: 54),
          SizedBox(height: 12),
          Text(
            'Chưa tìm thấy món phù hợp',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Thử tên món khác hoặc xem các nhóm món còn lại của quán.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantMenuSearchDelegate extends SearchDelegate<String> {
  final String restaurantName;
  final List<MenuSection> sections;

  _RestaurantMenuSearchDelegate({
    required this.restaurantName,
    required this.sections,
  }) : super(
         searchFieldLabel: 'Tìm món tại $restaurantName',
         keyboardType: TextInputType.text,
         textInputAction: TextInputAction.search,
       );

  List<_MenuSearchHit> _hits(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return [
        for (final section in sections)
          for (final item in section.items.take(3))
            _MenuSearchHit(section: section.title, item: item),
      ].take(10).toList();
    }

    return [
      for (final section in sections)
        for (final item in section.items)
          if (item.name.toLowerCase().contains(normalized) ||
              item.description.toLowerCase().contains(normalized) ||
              section.title.toLowerCase().contains(normalized))
            _MenuSearchHit(section: section.title, item: item),
    ];
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF212121),
        surfaceTintColor: Colors.white,
        elevation: 0.5,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, ''),
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final value = query.trim();
    if (value.isEmpty) return buildSuggestions(context);
    return _SearchResultList(
      hits: _hits(value),
      emptyTitle: 'Không có món "$value"',
      onSelect: (item) => close(context, item.name),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final hits = _hits(query);
    return _SearchResultList(
      hits: hits,
      emptyTitle: 'Không có gợi ý phù hợp',
      onSelect: (item) => close(context, item.name),
    );
  }
}

class _MenuSearchHit {
  final String section;
  final MenuItemData item;

  const _MenuSearchHit({required this.section, required this.item});
}

class _SearchResultList extends StatelessWidget {
  final List<_MenuSearchHit> hits;
  final String emptyTitle;
  final ValueChanged<MenuItemData> onSelect;

  const _SearchResultList({
    required this.hits,
    required this.emptyTitle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return Container(
        color: Colors.white,
        width: double.infinity,
        padding: const EdgeInsets.only(top: 72),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Color(0xFFFFB6A8),
              size: 48,
            ),
            const SizedBox(height: 10),
            Text(
              emptyTitle,
              style: const TextStyle(
                color: Color(0xFF424242),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: hits.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEDEDED)),
      itemBuilder: (context, index) {
        final hit = hits[index];
        return ListTile(
          onTap: () => onSelect(hit.item),
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
          leading: _RemoteFoodImage(
            imageUrl: hit.item.imageUrl,
            label: hit.item.name,
            width: 52,
            height: 52,
            radius: 6,
          ),
          title: Text(
            hit.item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${hit.section} · ${_formatPrice(hit.item.price)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF757575), fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFBDBDBD),
          ),
        );
      },
    );
  }
}

class _RestaurantCartSheet extends StatefulWidget {
  final String restaurantName;
  final List<CartItem> items;
  final int discount;
  final void Function(CartItem item, int quantity) onQuantityChanged;
  final VoidCallback onCheckout;

  const _RestaurantCartSheet({
    required this.restaurantName,
    required this.items,
    required this.discount,
    required this.onQuantityChanged,
    required this.onCheckout,
  });

  @override
  State<_RestaurantCartSheet> createState() => _RestaurantCartSheetState();
}

class _RestaurantCartSheetState extends State<_RestaurantCartSheet> {
  late List<CartItem> _items;

  int get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  int get total => math.max(0, subtotal - widget.discount);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  @override
  void initState() {
    super.initState();
    _items = List<CartItem>.of(widget.items);
  }

  void _changeQuantity(CartItem item, int quantity) {
    setState(() {
      final index = _items.indexWhere(
        (line) =>
            line.id == item.id &&
            line.note == item.note &&
            _sameSheetList(line.toppings, item.toppings),
      );
      if (index < 0) return;
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
    });
    widget.onQuantityChanged(item, quantity);
    if (_items.isEmpty) {
      Navigator.pop(context);
    }
  }

  bool _sameSheetList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 9, bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_basket_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$itemCount món từ ${widget.restaurantName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      for (final item in List<CartItem>.of(_items)) {
                        widget.onQuantityChanged(item, 0);
                      }
                      setState(() => _items.clear());
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Xóa giỏ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.discount > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBDEFE7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.success,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Đơn này được giảm ${checkoutFormatPrice(widget.discount)} phí giao hàng',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: _items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFFEDEDED)),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RemoteFoodImage(
                          imageUrl: item.imageUrl,
                          label: item.name,
                          width: 50,
                          height: 50,
                          radius: 5,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF212121),
                                  fontSize: 13,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (item.toppings.isNotEmpty ||
                                  item.note.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (item.toppings.isNotEmpty)
                                      item.toppings.join(', '),
                                    if (item.note.isNotEmpty) item.note,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8A8A8A),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      checkoutFormatPrice(item.lineTotal),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _CartSheetStepper(
                                    quantity: item.quantity,
                                    onMinus: () => _changeQuantity(
                                      item,
                                      item.quantity - 1,
                                    ),
                                    onPlus: () => _changeQuantity(
                                      item,
                                      item.quantity + 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          checkoutFormatPrice(total),
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.discount > 0)
                          Text(
                            'Tạm tính ${checkoutFormatPrice(subtotal)}',
                            style: const TextStyle(
                              color: Color(0xFF8A8A8A),
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _items.isEmpty ? null : widget.onCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFFFCCBB),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: const Text(
                        'Giao hàng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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

class _CartSheetStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CartSheetStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CartSheetStepButton(icon: Icons.remove_rounded, onTap: onMinus),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _CartSheetStepButton(icon: Icons.add_rounded, onTap: onPlus),
      ],
    );
  }
}

class _CartSheetStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CartSheetStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class ToppingBottomSheet extends StatefulWidget {
  final MenuItemData item;
  final ScrollController scrollController;

  const ToppingBottomSheet({
    super.key,
    required this.item,
    required this.scrollController,
  });

  @override
  State<ToppingBottomSheet> createState() => _ToppingBottomSheetState();
}

class _ToppingBottomSheetState extends State<ToppingBottomSheet> {
  final _noteController = TextEditingController();
  final Set<String> _selectedToppings = {};
  int _quantity = 1;

  static const _toppings = [
    'Thêm trân châu',
    'Thêm phô mai',
    'Thêm sốt cay',
    'Thêm rau',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _total =>
      (widget.item.price + _selectedToppings.length * 5000) * _quantity;

  void _submit() {
    Navigator.pop(
      context,
      CartItem(
        id: widget.item.id,
        name: widget.item.name,
        description: widget.item.description,
        imageUrl: widget.item.imageUrl,
        unitPrice: widget.item.price,
        quantity: _quantity,
        toppings: _selectedToppings.toList(growable: false),
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(top: 9, bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RemoteFoodImage(
                    imageUrl: widget.item.imageUrl,
                    label: widget.item.name,
                    width: 82,
                    height: 82,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thêm món mới',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 16,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatPrice(widget.item.price),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SheetSectionTitle('Tùy chọn thêm'),
              const SizedBox(height: 6),
              for (final topping in _toppings)
                CheckboxListTile(
                  value: _selectedToppings.contains(topping),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedToppings.add(topping);
                      } else {
                        _selectedToppings.remove(topping);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    topping,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  secondary: const Text(
                    '+5.000đ',
                    style: TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const _SheetSectionTitle('Ghi chú cho quán'),
              TextField(
                controller: _noteController,
                minLines: 1,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF9E9E9E),
                    size: 19,
                  ),
                  hintText: 'Ví dụ: ít cay, không hành...',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
            ),
            child: Row(
              children: [
                _QuantityButton(
                  icon: Icons.remove_rounded,
                  enabled: _quantity > 1,
                  onTap: () => setState(() => _quantity--),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$_quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QuantityButton(
                  icon: Icons.add_rounded,
                  enabled: true,
                  onTap: () => setState(() => _quantity++),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Thêm vào giỏ - ${_formatPrice(_total)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  final String text;

  const _SheetSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF212121),
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: const Icon(Icons.add_rounded, size: 17),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.black.withValues(alpha: 0.34),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, color: Colors.white, size: 17),
          ),
        ),
      ),
    );
  }
}

class _RemoteFoodImage extends StatelessWidget {
  final String imageUrl;
  final String label;
  final double? width;
  final double? height;
  final double radius;
  final bool showLabel;

  const _RemoteFoodImage({
    required this.imageUrl,
    required this.label,
    this.width,
    this.height,
    this.radius = 8,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return FoodImage(
      source: DishImages.normalize(label: label, imageUrl: imageUrl),
      label: label,
      width: width,
      height: height,
      radius: radius,
      showLabel: showLabel,
    );
  }
}

class MenuSection {
  final String title;
  final List<MenuItemData> items;

  const MenuSection({required this.title, required this.items});
}

class MenuItemData {
  final String id;
  final String name;
  final String description;
  final int price;
  final int sold;
  final int likes;
  final String imageUrl;

  /// Phiên bản dữ liệu ảnh của document Firestore. Ảnh remote chỉ được tin
  /// khi >= [DishImages.approvedImageVersion] (xem `DishImages.normalize`).
  final int imageVersion;

  const MenuItemData({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.sold,
    required this.likes,
    required this.imageUrl,
    this.imageVersion = 0,
  });
}

class MenuFactory {
  static List<MenuSection> sectionsFor(RestaurantDetailInput restaurant) {
    // Ưu tiên bộ menu riêng theo loại quán (bún bò -> bún/phở, ốc -> hải sản).
    final blueprint = MenuCatalog.blueprintFor(
      category: restaurant.category,
      name: restaurant.name,
    );
    if (blueprint != null) {
      return _fromBlueprint(blueprint, restaurant);
    }

    // Quán lấy từ API địa điểm chỉ có category chung -> dùng bộ theme cũ.
    return switch (_themeFor(restaurant)) {
      'drink' => _expandSections(
        _drinkSections(restaurant),
        restaurant,
        'drink',
      ),
      'snack' => _expandSections(
        _snackSections(restaurant),
        restaurant,
        'snack',
      ),
      'fast_food' => _expandSections(
        _fastFoodSections(restaurant),
        restaurant,
        'fast_food',
      ),
      _ => _expandSections(
        _riceAndNoodleSections(restaurant),
        restaurant,
        'rice_noodle',
      ),
    };
  }

  /// `category` là tín hiệu đáng tin nhất vì luôn là giá trị máy không dấu
  /// (`rice`, `milk_tea`, `fast_food`...). Chỉ khi category lạ mới đoán theo
  /// tên quán. Thứ tự này tránh việc "Cơm gà xối mỡ" bị nhận thành quán gà rán
  /// chỉ vì trong tên có chữ "gà".
  static String _themeFor(RestaurantDetailInput restaurant) {
    const categoryThemes = <String, String>{
      'coffee': 'drink',
      'cafe': 'drink',
      'milk_tea': 'drink',
      'dessert': 'drink',
      'snack': 'snack',
      'bakery': 'snack',
      'breakfast': 'snack',
      'fast_food': 'fast_food',
      'korean': 'fast_food',
      'western': 'fast_food',
      'rice': 'rice_noodle',
      'noodle': 'rice_noodle',
      'hotpot': 'rice_noodle',
      'seafood': 'rice_noodle',
      'vegetarian': 'rice_noodle',
      'healthy': 'rice_noodle',
      'vietnamese': 'rice_noodle',
      'japanese': 'rice_noodle',
    };

    final category = restaurant.category.trim().toLowerCase();
    final mapped = categoryThemes[category];
    if (mapped != null) {
      return mapped;
    }

    final text = '${restaurant.name} $category'.toLowerCase();
    if (_containsAny(text, [
      'cafe',
      'coffee',
      'cà phê',
      'ca phe',
      'trà sữa',
      'tra sua',
      'matcha',
      'trà',
    ])) {
      return 'drink';
    }
    if (_containsAny(text, [
      'bánh mì',
      'banh mi',
      'bánh tráng',
      'banh trang',
      'phá lấu',
      'pha lau',
      'xiên que',
      'xien que',
      'ăn vặt',
      'an vat',
    ])) {
      return 'snack';
    }
    if (_containsAny(text, [
      'gà rán',
      'ga ran',
      'burger',
      'pizza',
      'fast_food',
      'mì cay',
      'mi cay',
    ])) {
      return 'fast_food';
    }
    return 'rice_noodle';
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  /// Dựng [MenuSection] từ bộ menu định nghĩa sẵn trong [MenuCatalog].
  static List<MenuSection> _fromBlueprint(
    List<MenuBlueprint> blueprint,
    RestaurantDetailInput restaurant,
  ) {
    final sections = <MenuSection>[];
    for (final group in blueprint) {
      final items = <MenuItemData>[];
      for (final dish in group.dishes) {
        items.add(
          _item(
            dish.name,
            dish.description,
            dish.price,
            restaurant,
            // Ảnh riêng của món nếu đã có trong assets/images/dishes/,
            // nếu chưa thì lấy ảnh gần đúng nhất theo loại món.
            DishImages.resolve(dish.name, salt: restaurant.id),
          ),
        );
      }
      if (items.isNotEmpty) {
        sections.add(MenuSection(title: group.title, items: items));
      }
    }
    return sections;
  }

  static List<MenuSection> _expandSections(
    List<MenuSection> sections,
    RestaurantDetailInput restaurant,
    String theme,
  ) {
    final currentCount = sections.fold<int>(
      0,
      (total, section) => total + section.items.length,
    );
    if (currentCount >= 22) return sections;

    final names = sections
        .expand((section) => section.items)
        .map((item) => item.name.toLowerCase())
        .toSet();
    final generated = <MenuItemData>[];
    final pool = _generatedPool(theme);
    var imageIndex = 0;
    for (final spec in pool) {
      if (generated.length + currentCount >= 22) break;
      if (!names.add(spec.$1.toLowerCase())) continue;
      generated.add(
        _item(
          spec.$1,
          spec.$2,
          spec.$3,
          restaurant,
          DishImages.resolve(
            spec.$1,
            salt: '${restaurant.id}-generated-${imageIndex++}',
          ),
        ),
      );
    }

    if (generated.isEmpty) return sections;
    return [...sections, MenuSection(title: 'Món gợi ý', items: generated)];
  }

  /// Xếp thứ tự ảnh cho các món sinh thêm sao cho:
  /// 1. Ưu tiên ảnh CHƯA xuất hiện ở các mục có sẵn của quán.
  /// 2. Mỗi quán có thứ tự riêng nhưng ổn định (xoay theo id quán), nên hai
  ///    quán khác nhau không mở ra cùng một dãy ảnh giống hệt.
  /// 3. Chỉ lặp lại ảnh sau khi đã dùng hết kho -> giảm tối đa cảm giác
  ///    dữ liệu trùng lặp trong cùng một menu.
  static List<(String, String, int)> _generatedPool(String theme) {
    return switch (theme) {
      'drink' => const [
        ('Trà đào cam sả', 'Đào miếng, cam vàng và sả thơm', 39000),
        ('Oolong sữa trân châu', 'Trà oolong đậm vị, trân châu đen', 42000),
        ('Matcha latte đậu đỏ', 'Matcha Nhật, đậu đỏ mềm', 45000),
        ('Sữa tươi trân châu đường đen', 'Sữa tươi, caramel nâu', 43000),
        ('Hồng trà macchiato', 'Kem cheese mặn nhẹ', 41000),
        ('Trà vải hoa hồng', 'Vải tươi, hương hoa hồng', 39000),
        ('Cà phê sữa đá', 'Cà phê pha phin, sữa đặc', 29000),
        ('Bạc xỉu đá', 'Nhiều sữa, ít cà phê', 32000),
        ('Cookie cream đá xay', 'Kem béo, bánh cookie giòn', 49000),
        ('Trà tắc mật ong', 'Tắc tươi, mật ong rừng', 28000),
        ('Soda chanh dây', 'Chanh dây tươi, soda mát lạnh', 36000),
        ('Yakult dâu tằm', 'Yakult, dâu tằm chua ngọt', 42000),
        ('Trà sữa khoai môn', 'Khoai môn béo và trân châu', 43000),
        ('Cà phê cốt dừa', 'Cốt dừa béo, cà phê đậm', 45000),
        ('Oreo cacao đá xay', 'Cacao, Oreo và kem tươi', 49000),
        ('Trà xanh sữa nhài', 'Trà xanh thanh, thạch nhài', 39000),
        ('Sữa chua việt quất', 'Việt quất, sữa chua mịn', 42000),
      ],
      'snack' => const [
        ('Bánh tráng trộn', 'Khô bò, trứng cút, xoài xanh', 35000),
        ('Bánh tráng cuốn sốt bơ', 'Sốt bơ trứng muối béo nhẹ', 42000),
        ('Xiên que thập cẩm', 'Cá viên, bò viên, tôm viên', 49000),
        ('Khoai lang kén', 'Vỏ giòn, nhân khoai mềm', 29000),
        ('Nem chua rán', 'Chiên nóng, chấm tương cay', 39000),
        ('Phô mai que', 'Phô mai kéo sợi, vỏ xù', 35000),
        ('Takoyaki bạch tuộc', '6 viên, cá bào và mayo', 45000),
        ('Gà lắc phô mai', 'Gà viên chiên, bột phô mai', 45000),
        ('Bắp xào tôm khô', 'Bắp Mỹ, bơ, tôm khô', 32000),
        ('Cá viên chiên', 'Phần lớn kèm rau răm', 39000),
        ('Hồ lô nướng', 'Xúc xích hồ lô nóng', 28000),
        ('Bánh mì chả cá', 'Chả cá chiên, rau dưa', 30000),
        ('Phá lấu bò', 'Lòng bò, nước dừa béo', 59000),
        ('Súp cua trứng bắc thảo', 'Cua, nấm, trứng bắc thảo', 42000),
        ('Gỏi khô bò', 'Đu đủ, khô bò, đậu phộng', 39000),
        ('Trứng cút sốt me', 'Sốt me chua ngọt', 35000),
        ('Bánh flan caramel', 'Flan mềm, caramel đắng nhẹ', 22000),
      ],
      'fast_food' => const [
        ('Gà giòn cay 1 miếng', 'Gà chiên giòn, vị cay', 39000),
        ('Combo gà burger', 'Burger, gà miếng và nước', 99000),
        ('Burger bò phô mai', 'Bò nướng, phô mai, rau tươi', 69000),
        ('Mì Ý sốt bò bằm', 'Sốt cà chua, bò bằm', 79000),
        ('Pizza hải sản mini', 'Tôm, mực, phô mai', 89000),
        ('Khoai tây chiên vừa', 'Khoai giòn, sốt tự chọn', 35000),
        ('Gà popcorn', 'Gà viên giòn cay nhẹ', 45000),
        ('Cánh gà BBQ', 'Cánh gà phủ sốt BBQ', 59000),
        ('Salad cá ngừ', 'Rau trộn, cá ngừ, sốt mè', 52000),
        ('Burger gà cay', 'Gà giòn, sốt cay', 65000),
        ('Cơm gà sốt tiêu', 'Cơm nóng, gà sốt tiêu đen', 69000),
        ('Mì cay gà giòn', 'Mì Hàn, gà giòn cay', 75000),
        ('Hotdog phô mai', 'Xúc xích, phô mai, ketchup', 42000),
        ('Combo gia đình', '4 miếng gà, khoai, 2 nước', 199000),
        ('Gà sốt Hàn Quốc', 'Sốt gochujang cay ngọt', 69000),
        ('Burger tôm', 'Tôm chiên, rau giòn', 72000),
        ('Nước ngọt lon', 'Pepsi/Coca/Sprite', 18000),
      ],
      _ => const [
        ('Cơm tấm sườn bì chả', 'Sườn nướng, bì, chả trứng', 59000),
        ('Cơm gà xối mỡ', 'Gà giòn da, cơm chiên tỏi', 62000),
        ('Bún bò Huế', 'Nước dùng đậm, bò bắp', 65000),
        ('Phở bò tái nạm', 'Phở nóng, thịt bò mềm', 59000),
        ('Hủ tiếu Nam Vang', 'Tôm, thịt, gan, trứng cút', 62000),
        ('Mì trộn xá xíu', 'Mì dai, xá xíu, trứng lòng đào', 55000),
        ('Bún thịt nướng chả giò', 'Thịt nướng than, chả giò', 58000),
        ('Bún đậu mắm tôm', 'Đậu giòn, chả cốm, thịt luộc', 79000),
        ('Cơm chiên hải sản', 'Tôm, mực, trứng, rau củ', 69000),
        ('Mì cay bò Mỹ', 'Bò Mỹ, xúc xích, nấm', 79000),
        ('Cháo sườn trứng bắc thảo', 'Cháo mềm, sườn non', 42000),
        ('Gỏi cuốn tôm thịt', 'Rau tươi, sốt đậu phộng', 39000),
        ('Bò kho bánh mì', 'Bò mềm, cà rốt, bánh mì', 65000),
        ('Bánh canh cua', 'Cua, chả cá, nấm rơm', 69000),
        ('Cơm bò lúc lắc', 'Bò lúc lắc, khoai chiên', 79000),
        ('Lẩu cá nhân tomyum', 'Tomyum cay chua, topping', 99000),
        ('Trà tắc ly lớn', 'Trà tắc mát lạnh', 18000),
      ],
    };
  }

  static List<MenuSection> _drinkSections(RestaurantDetailInput restaurant) {
    return [
      MenuSection(
        title: 'Trà sữa',
        items: [
          _item(
            'Trà sữa truyền thống',
            'Trân châu đen, flan và thạch nhà làm',
            34500,
            restaurant,
            '',
          ),
          _item(
            'Sâm dứa sữa size L',
            'Vị thơm nhẹ, ngọt vừa, nhiều topping',
            23500,
            restaurant,
            '',
          ),
          _item(
            'Choco Latte size L',
            'Latte cacao kèm Oreo giòn',
            29500,
            restaurant,
            '',
          ),
        ],
      ),
      MenuSection(
        title: 'Ăn vặt',
        items: [
          _item(
            'Xúc xích quay x2',
            'Không dùng dầu cũ, ăn kèm tương cay',
            22500,
            restaurant,
            '',
          ),
          _item(
            'Khoai tây lắc phô mai',
            'Khoai giòn nóng, bột phô mai phủ đều',
            29000,
            restaurant,
            '',
          ),
          _item(
            'Bánh tráng rong biển sate tỏi',
            'Túi lớn, vị cay nhẹ',
            85000,
            restaurant,
            '',
          ),
        ],
      ),
    ];
  }

  static List<MenuSection> _snackSections(RestaurantDetailInput restaurant) {
    return [
      MenuSection(
        title: 'Mua thêm',
        items: [
          _item(
            'Bánh mì',
            'Ổ mới nướng, dùng kèm món chính',
            3000,
            restaurant,
            '',
          ),
          _item(
            'Mì gói',
            'Mì trụng ăn kèm nước sốt hoặc phá lấu',
            5000,
            restaurant,
            '',
          ),
        ],
      ),
      MenuSection(
        title: 'Món chính',
        items: [
          _item(
            'Phá lấu bò phần nhỏ',
            'Lòng bò mềm, nước dừa béo nhẹ',
            39000,
            restaurant,
            '',
          ),
          _item(
            'Phá lấu bò thập cẩm',
            'Topping đầy đủ, ăn kèm bánh mì',
            59000,
            restaurant,
            '',
          ),
          _item(
            'Bánh mì phá lấu',
            'Bánh mì giòn, phá lấu chan sốt riêng',
            32000,
            restaurant,
            '',
          ),
        ],
      ),
    ];
  }

  static List<MenuSection> _fastFoodSections(RestaurantDetailInput restaurant) {
    return [
      MenuSection(
        title: 'Combo gà',
        items: [
          _item(
            'Combo gà giòn cay',
            '2 miếng gà, khoai tây và nước ngọt',
            79000,
            restaurant,
            '',
          ),
          _item(
            'Burger gà phô mai',
            'Gà giòn, sốt đặc biệt, phô mai lát',
            69000,
            restaurant,
            '',
          ),
          _item(
            'Cánh gà sốt cay',
            'Sốt cay ngọt, ăn kèm rau trộn',
            59000,
            restaurant,
            '',
          ),
        ],
      ),
      MenuSection(
        title: 'Ăn kèm',
        items: [
          _item(
            'Khoai tây chiên lớn',
            'Khoai nóng giòn, thêm tương miễn phí',
            35000,
            restaurant,
            '',
          ),
          _item(
            'Salad bắp cải',
            'Mát nhẹ, cân vị món chiên',
            25000,
            restaurant,
            '',
          ),
        ],
      ),
    ];
  }

  static List<MenuSection> _riceAndNoodleSections(
    RestaurantDetailInput restaurant,
  ) {
    return [
      MenuSection(
        title: 'Món chính',
        items: [
          _item(
            'Cơm Sườn Nướng Mỡ Hành',
            'Sườn ướp đậm vị, cơm nóng và đồ chua',
            45000,
            restaurant,
            '',
          ),
          _item(
            'Bún thịt nướng',
            'Thịt nướng than, rau sống và nước mắm chua ngọt',
            42000,
            restaurant,
            '',
          ),
          _item(
            'Mì trộn tóp mỡ',
            'Mì dai, topping đầy đủ, sốt riêng của quán',
            39000,
            restaurant,
            '',
          ),
        ],
      ),
      MenuSection(
        title: 'Gọi thêm',
        items: [
          _item(
            'Chả giò',
            'Chiên giòn, ăn kèm rau sống',
            25000,
            restaurant,
            '',
          ),
          _item('Trà tắc', 'Ly lớn, ít ngọt', 15000, restaurant, ''),
        ],
      ),
    ];
  }

  static MenuItemData _item(
    String name,
    String description,
    int price,
    RestaurantDetailInput restaurant,
    String imageUrl,
  ) {
    final seed = '${restaurant.id}-$name'.codeUnits.fold<int>(
      0,
      (a, b) => a + b,
    );
    final resolvedImage = DishImages.normalize(label: name, imageUrl: imageUrl);
    return MenuItemData(
      id: _stableItemId(restaurant, name),
      name: name,
      description: description,
      price: price,
      sold: 8 + seed % 520,
      likes: 2 + seed % 96,
      imageUrl: resolvedImage,
    );
  }

  static String _stableItemId(RestaurantDetailInput restaurant, String name) {
    final safeRestaurant = restaurant.id.replaceAll(
      RegExp(r'[^a-zA-Z0-9]+'),
      '-',
    );
    final safeName = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9À-ỹ]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$safeRestaurant-$safeName';
  }
}

String _normalizedRestaurantHeroImage(RestaurantDetailInput restaurant) {
  return DishImages.normalize(
    label: restaurant.name,
    imageUrl: restaurant.imageUrl,
  );
}

String _formatPrice(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '$bufferđ';
}

void _showAction(BuildContext context, String title) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(title),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.primary,
      ),
    );
}
