import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_pages.dart';
import '../orders/order_state.dart';

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
  late final List<MenuSection> _sections;
  late final List<MenuItemData> _popularItems;
  final List<CartItem> _cartItems = [];

  int get _cartCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  int get _cartTotal => _cartItems.fold(0, (sum, item) => sum + item.lineTotal);

  @override
  void initState() {
    super.initState();
    _sections = MenuFactory.sectionsFor(widget.restaurant);
    _popularItems = _sections
        .expand((section) => section.items)
        .take(4)
        .toList();
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
        initialChildSize: 0.74,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, controller) =>
            ToppingBottomSheet(item: item, scrollController: controller),
      ),
    );

    if (configured == null || !mounted) return;
    setState(() => _cartItems.add(configured));
    OrderState.upsertCart(_currentCheckoutOrder());
  }

  CheckoutOrder _currentCheckoutOrder() {
    final restaurant = widget.restaurant;
    return CheckoutOrder(
      restaurant: CheckoutRestaurantInfo(
        id: restaurant.id,
        name: restaurant.name,
        address: restaurant.address,
        deliveryMinutes: restaurant.time,
        distanceKm: restaurant.distance,
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
      ),
      items: List<CartItem>.unmodifiable(_cartItems),
      address: restaurant.address.isEmpty
          ? 'Vị trí hiện tại của bạn'
          : restaurant.address,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _HeaderSliver(restaurant: widget.restaurant),
          SliverToBoxAdapter(
            child: _RestaurantInfo(restaurant: widget.restaurant),
          ),
          SliverToBoxAdapter(
            child: _DeliveryAndDeals(restaurant: widget.restaurant),
          ),
          SliverToBoxAdapter(
            child: _PopularItems(items: _popularItems, onAdd: _addItem),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _MenuTabsDelegate(sections: _sections),
          ),
          for (final section in _sections)
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
                height: 60,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF0ED),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_basket_outlined,
                            color: AppColors.primary,
                            size: 23,
                          ),
                        ),
                        Positioned(
                          top: -3,
                          right: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            checkoutFormatPrice(_cartTotal),
                            style: const TextStyle(
                              color: Color(0xFF212121),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Đã gồm món và topping',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _openCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Giao hàng',
                          style: TextStyle(
                            fontSize: 14,
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

  const _HeaderSliver({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: restaurant.imageUrl == null ? 96 : 214,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      leading: _CircleIconButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.maybePop(context),
      ),
      title: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        _CircleIconButton(
          icon: Icons.search_rounded,
          onTap: () => _showAction(context, 'Tìm món'),
        ),
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
                    imageUrl:
                        restaurant.imageUrl ?? _restaurantHeroImage(restaurant),
                    radius: 0,
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
                ],
              ),
            ),
    );
  }
}

class _RestaurantInfo extends StatelessWidget {
  final RestaurantDetailInput restaurant;

  const _RestaurantInfo({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final rating = restaurant.rating ?? 4.6;
    final comments = restaurant.sold >= 100
        ? '100+ Bình luận'
        : '${math.max(9, restaurant.sold ~/ 12)} Bình luận';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4, right: 7),
                child: Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFFFB300),
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 20,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showAction(context, 'Đã lưu quán'),
                icon: const Icon(Icons.favorite_border_rounded, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i + 1 <= rating.round()
                      ? Icons.star_rounded
                      : Icons.star_half_rounded,
                  color: const Color(0xFFFFB300),
                  size: 16,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${rating.toStringAsFixed(1)} ($comments) | ${restaurant.time} phút | ${restaurant.distance.toStringAsFixed(1)}km',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (restaurant.address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: Color(0xFF9E9E9E),
                  size: 17,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    restaurant.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 12,
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
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          _InfoLine(
            icon: Icons.local_shipping_outlined,
            iconColor: AppColors.success,
            title: 'Giao ngay',
            value: 'Dự kiến giao lúc $hh:$mm',
            action: 'Thay đổi',
          ),
          const SizedBox(height: 12),
          const _InfoLine(
            icon: Icons.local_offer_rounded,
            iconColor: AppColors.primary,
            title: 'Ưu đãi dành cho bạn',
            value: '',
            action: 'Xem thêm',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
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
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Món phổ biến',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 26),
        itemBuilder: (_, index) {
          final active = index == 0;
          return Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              sections[index].title,
              style: TextStyle(
                color: active ? AppColors.primary : const Color(0xFF212121),
                fontSize: 14,
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${section.title} (${section.items.length})',
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEDEDED), width: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RemoteFoodImage(imageUrl: item.imageUrl, width: 92, height: 92),
          const SizedBox(width: 14),
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
                    fontSize: 15,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  '${item.sold} đã bán | ${item.likes} lượt thích',
                  style: const TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatPrice(item.price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
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
      width: 288,
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
                width: 104,
                height: 104,
                radius: 0,
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  color: const Color(0xFFFFB300),
                  child: Text(
                    '${item.sold} đã bán',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 14,
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
                            fontSize: 17,
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
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF424242), fontSize: 13),
            ),
          ),
        ] else
          const Spacer(),
        Text(
          action,
          style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
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
      width: 124,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            size: 19,
          ),
          const SizedBox(width: 7),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Đơn từ ${minimum ~/ 1000}K',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 11,
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
        id: '${widget.item.name}-${DateTime.now().microsecondsSinceEpoch}',
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
      width: 32,
      height: 32,
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
      width: 32,
      height: 32,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: const Icon(Icons.add_rounded, size: 22),
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
  final double? width;
  final double? height;
  final double radius;

  const _RemoteFoodImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isAsset = imageUrl.startsWith('assets/');
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFFE0E0E0),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            if (isAsset)
              Image.asset(imageUrl, fit: BoxFit.cover)
            else
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const SizedBox.shrink();
                },
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class MenuSection {
  final String title;
  final List<MenuItemData> items;

  const MenuSection({required this.title, required this.items});
}

class MenuItemData {
  final String name;
  final String description;
  final int price;
  final int sold;
  final int likes;
  final String imageUrl;

  const MenuItemData({
    required this.name,
    required this.description,
    required this.price,
    required this.sold,
    required this.likes,
    required this.imageUrl,
  });
}

class MenuFactory {
  static List<MenuSection> sectionsFor(RestaurantDetailInput restaurant) {
    final text = '${restaurant.name} ${restaurant.category}'.toLowerCase();
    if (_containsAny(text, [
      'cafe',
      'coffee',
      'cà phê',
      'trà sữa',
      'tra sua',
    ])) {
      return _drinkSections(restaurant);
    }
    if (_containsAny(text, ['bánh', 'banh mi', 'phá lấu', 'pha lau'])) {
      return _snackSections(restaurant);
    }
    if (_containsAny(text, ['gà', 'ga ran', 'fast_food'])) {
      return _fastFoodSections(restaurant);
    }
    return _riceAndNoodleSections(restaurant);
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
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
            _img('milk-tea', 1),
          ),
          _item(
            'Sâm dứa sữa size L',
            'Vị thơm nhẹ, ngọt vừa, nhiều topping',
            23500,
            restaurant,
            _img('green-milk-tea', 2),
          ),
          _item(
            'Choco Latte size L',
            'Latte cacao kèm Oreo giòn',
            29500,
            restaurant,
            _img('choco-latte', 3),
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
            _img('sausage', 4),
          ),
          _item(
            'Khoai tây lắc phô mai',
            'Khoai giòn nóng, bột phô mai phủ đều',
            29000,
            restaurant,
            _img('fries', 5),
          ),
          _item(
            'Bánh tráng rong biển sate tỏi',
            'Túi lớn, vị cay nhẹ',
            85000,
            restaurant,
            _img('snack', 6),
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
            _img('banh-mi', 7),
          ),
          _item(
            'Mì gói',
            'Mì trụng ăn kèm nước sốt hoặc phá lấu',
            5000,
            restaurant,
            _img('noodle', 8),
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
            _img('pha-lau', 9),
          ),
          _item(
            'Phá lấu bò thập cẩm',
            'Topping đầy đủ, ăn kèm bánh mì',
            59000,
            restaurant,
            _img('beef-stew', 10),
          ),
          _item(
            'Bánh mì phá lấu',
            'Bánh mì giòn, phá lấu chan sốt riêng',
            32000,
            restaurant,
            _img('banh-mi', 11),
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
            _img('fried-chicken', 12),
          ),
          _item(
            'Burger gà phô mai',
            'Gà giòn, sốt đặc biệt, phô mai lát',
            69000,
            restaurant,
            _img('burger', 13),
          ),
          _item(
            'Cánh gà sốt cay',
            'Sốt cay ngọt, ăn kèm rau trộn',
            59000,
            restaurant,
            _img('chicken-wing', 14),
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
            _img('fries', 15),
          ),
          _item(
            'Salad bắp cải',
            'Mát nhẹ, cân vị món chiên',
            25000,
            restaurant,
            _img('salad', 16),
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
            'Cơm sườn nướng',
            'Sườn ướp đậm vị, cơm nóng và đồ chua',
            45000,
            restaurant,
            _img('com-suon', 17),
          ),
          _item(
            'Bún thịt nướng',
            'Thịt nướng than, rau sống và nước mắm chua ngọt',
            42000,
            restaurant,
            _img('bun-thit-nuong', 18),
          ),
          _item(
            'Mì trộn đặc biệt',
            'Mì dai, topping đầy đủ, sốt riêng của quán',
            39000,
            restaurant,
            _img('mixed-noodle', 19),
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
            _img('spring-roll', 20),
          ),
          _item(
            'Trà tắc',
            'Ly lớn, ít ngọt',
            15000,
            restaurant,
            _img('iced-tea', 21),
          ),
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
    return MenuItemData(
      name: name,
      description: description,
      price: price,
      sold: 8 + seed % 520,
      likes: 2 + seed % 96,
      imageUrl: imageUrl,
    );
  }

  static String _img(String query, int lock) {
    const images = {
      'milk-tea': 'assets/images/restaurants/food_05.jpg',
      'green-milk-tea': 'assets/images/restaurants/food_12.jpg',
      'choco-latte': 'assets/images/restaurants/food_04.jpg',
      'sausage': 'assets/images/restaurants/food_06.jpg',
      'fries': 'assets/images/restaurants/food_11.jpg',
      'snack': 'assets/images/restaurants/food_08.jpg',
      'banh-mi': 'assets/images/restaurants/food_10.jpg',
      'noodle': 'assets/images/restaurants/food_02.jpg',
      'pha-lau': 'assets/images/restaurants/food_09.jpg',
      'beef-stew': 'assets/images/restaurants/food_08.jpg',
      'fried-chicken': 'assets/images/restaurants/food_06.jpg',
      'burger': 'assets/images/restaurants/food_07.jpg',
      'chicken-wing': 'assets/images/restaurants/food_01.jpg',
      'salad': 'assets/images/restaurants/food_03.jpg',
      'com-suon': 'assets/images/restaurants/food_01.jpg',
      'bun-thit-nuong': 'assets/images/restaurants/food_07.jpg',
      'mixed-noodle': 'assets/images/restaurants/food_02.jpg',
      'spring-roll': 'assets/images/restaurants/food_03.jpg',
      'iced-tea': 'assets/images/restaurants/food_05.jpg',
      'vietnamese-food': 'assets/images/restaurants/food_01.jpg',
    };
    return images[query] ?? images['vietnamese-food']!;
  }
}

String _restaurantHeroImage(RestaurantDetailInput restaurant) {
  final category = restaurant.category;
  final query = switch (category) {
    'cafe' => 'milk-tea',
    'fast_food' => 'fried-chicken',
    'bakery' => 'banh-mi',
    _ => 'vietnamese-food',
  };
  return MenuFactory._img(query, restaurant.id.hashCode.abs() % 1000);
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
