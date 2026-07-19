import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_pages.dart';
import '../home/home_page.dart';
import '../orders/orders_page.dart';
import '../orders/order_state.dart';
import '../profile/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _hideBottomNavForLocation = true;
  String? _hiddenCartKey;
  late final List<Widget? Function()> _pageBuilders;
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _pageBuilders = [
      () => HomePage(
        onProfileTap: () => _onItemTapped(2),
        onLocationGateChanged: _setLocationGateVisible,
      ),
      () => OrdersPage(onBack: () => _onItemTapped(0)),
      () => const ProfilePage(),
    ];
    _pages = List<Widget?>.filled(_pageBuilders.length, null);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _setLocationGateVisible(bool visible) {
    if (!mounted || _hideBottomNavForLocation == visible) {
      return;
    }

    setState(() {
      _hideBottomNavForLocation = visible;
    });
  }

  void _hideCartPreview(OrderEntry entry) {
    setState(() {
      _hiddenCartKey =
          '${entry.order.restaurant.id}:${entry.updatedAt.millisecondsSinceEpoch}';
    });
  }

  void _openCartDetail(List<OrderEntry> carts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const _CartDetailSheet(),
    );
  }

  Widget _buildPage(int index) {
    if (_pages[index] == null) {
      debugPrint('[MainPage] build tab $index');
      _pages[index] = _pageBuilders[index]();
    }
    return _pages[index]!;
  }

  Widget _buildLoadedPages() {
    _buildPage(_selectedIndex);

    return Stack(
      children: [
        for (var index = 0; index < _pages.length; index++)
          if (_pages[index] != null)
            Offstage(
              offstage: index != _selectedIndex,
              child: TickerMode(
                enabled: index == _selectedIndex,
                child: _pages[index]!,
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navWidth = screenWidth <= 600
        ? screenWidth
        : math.min(screenWidth, 390.0);

    return Scaffold(
      body: Stack(
        children: [
          _buildLoadedPages(),
          if (!(_hideBottomNavForLocation && _selectedIndex == 0))
            _CartPreviewHost(
              selectedIndex: _selectedIndex,
              bottomOffset: 0,
              hiddenCartKey: _hiddenCartKey,
              onTap: _openCartDetail,
              onDismiss: _hideCartPreview,
            ),
        ],
      ),
      bottomNavigationBar: _hideBottomNavForLocation && _selectedIndex == 0
          ? null
          : Container(
              height: 50 + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: navWidth,
                  height: 50,
                  child: MediaQuery.withNoTextScaling(
                    child: ValueListenableBuilder<List<OrderEntry>>(
                      valueListenable: OrderState.entries,
                      builder: (context, entries, _) {
                        final orderBadgeCount = entries
                            .where(
                              (entry) =>
                                  entry.status == OrderStatus.cart ||
                                  entry.status == OrderStatus.delivering,
                            )
                            .length;

                        return Row(
                          children: [
                            _BottomNavItem(
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home,
                              label: 'Trang chủ',
                              selected: _selectedIndex == 0,
                              onTap: () => _onItemTapped(0),
                            ),
                            _BottomNavItem(
                              icon: Icons.assignment_outlined,
                              activeIcon: Icons.assignment,
                              label: 'Đơn hàng',
                              selected: _selectedIndex == 1,
                              badgeCount: orderBadgeCount,
                              onTap: () => _onItemTapped(1),
                            ),
                            _BottomNavItem(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person,
                              label: 'Tôi',
                              selected: _selectedIndex == 2,
                              onTap: () => _onItemTapped(2),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartPreviewHost extends StatelessWidget {
  final int selectedIndex;
  final double bottomOffset;
  final String? hiddenCartKey;
  final ValueChanged<List<OrderEntry>> onTap;
  final ValueChanged<OrderEntry> onDismiss;

  const _CartPreviewHost({
    required this.selectedIndex,
    required this.bottomOffset,
    required this.hiddenCartKey,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedIndex != 0) return const SizedBox.shrink();

    return ValueListenableBuilder<List<OrderEntry>>(
      valueListenable: OrderState.entries,
      builder: (context, entries, _) {
        final carts =
            entries.where((entry) => entry.status == OrderStatus.cart).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (carts.isEmpty) return const SizedBox.shrink();

        final entry = carts.first;
        final key =
            '${entry.order.restaurant.id}:${entry.updatedAt.millisecondsSinceEpoch}';
        if (hiddenCartKey == key) return const SizedBox.shrink();

        return Positioned(
          left: 12,
          right: 12,
          bottom: bottomOffset,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 456),
              child: _FloatingCartPreview(
                entry: entry,
                extraCount: carts.length - 1,
                onTap: () => onTap(carts),
                onDismiss: () => onDismiss(entry),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingCartPreview extends StatelessWidget {
  final OrderEntry entry;
  final int extraCount;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FloatingCartPreview({
    required this.entry,
    required this.extraCount,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    final firstItem = order.items.isEmpty ? null : order.items.first;
    final title = extraCount > 0
        ? '${order.restaurant.name} + $extraCount giỏ khác'
        : order.restaurant.name;
    final subtitle = firstItem == null
        ? '${order.itemCount} món - ${checkoutFormatPrice(order.total)}'
        : '${order.itemCount} món - ${checkoutFormatPrice(order.total)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF616161),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF9E9E9E),
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartDetailSheet extends StatelessWidget {
  const _CartDetailSheet();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<OrderEntry>>(
      valueListenable: OrderState.entries,
      builder: (context, entries, _) {
        final carts =
            entries.where((entry) => entry.status == OrderStatus.cart).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (carts.isEmpty) return const _CartEmptySheet();

        final totalItems = carts.fold<int>(
          0,
          (total, entry) => total + entry.order.itemCount,
        );
        final totalPrice = carts.fold<int>(
          0,
          (total, entry) => total + entry.order.total,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        carts.length == 1
                            ? carts.first.order.restaurant.name
                            : '${carts.length} giỏ hàng đang có',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: carts.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) => _CartRestaurantGroup(
                      entry: carts[index],
                      onCheckout: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CheckoutPage(order: carts[index].order),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$totalItems món · ${checkoutFormatPrice(totalPrice)}',
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CheckoutPage(order: carts.first.order),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Đặt giỏ mới nhất'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CartEmptySheet extends StatelessWidget {
  const _CartEmptySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              color: AppColors.primary,
              size: 42,
            ),
            const SizedBox(height: 10),
            const Text(
              'Giỏ hàng đang trống',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Món vừa xóa sẽ biến mất khỏi giỏ ngay lập tức.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tiếp tục chọn món'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartRestaurantGroup extends StatelessWidget {
  final OrderEntry entry;
  final VoidCallback onCheckout;

  const _CartRestaurantGroup({required this.entry, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.restaurant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => OrderState.removeCart(order.restaurant.id),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9E9E9E),
                padding: EdgeInsets.zero,
                minimumSize: const Size(42, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Xóa'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in order.items) ...[
          _CartItemRow(order: order, item: item),
          if (item != order.items.last) const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                checkoutFormatPrice(order.total),
                style: const TextStyle(
                  color: Color(0xFF616161),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Đặt đơn này',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CheckoutOrder order;
  final CartItem item;

  const _CartItemRow({required this.order, required this.item});

  @override
  Widget build(BuildContext context) {
    final optionText = item.toppings.isEmpty
        ? 'Không topping'
        : item.toppings.join(', ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CartFoodImage(path: item.imageUrl),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                optionText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF757575), fontSize: 12),
              ),
              const SizedBox(height: 7),
              _CartQuantityStepper(order: order, item: item),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          checkoutFormatPrice(item.lineTotal),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CartQuantityStepper extends StatelessWidget {
  final CheckoutOrder order;
  final CartItem item;

  const _CartQuantityStepper({required this.order, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CartStepButton(
          icon: item.quantity <= 1
              ? Icons.delete_outline_rounded
              : Icons.remove_rounded,
          onTap: () => OrderState.updateCartItemQuantity(
            restaurantId: order.restaurant.id,
            item: item,
            quantity: item.quantity - 1,
          ),
        ),
        Container(
          width: 34,
          alignment: Alignment.center,
          child: Text(
            '${item.quantity}',
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _CartStepButton(
          icon: Icons.add_rounded,
          strong: true,
          onTap: () => OrderState.updateCartItemQuantity(
            restaurantId: order.restaurant.id,
            item: item,
            quantity: item.quantity + 1,
          ),
        ),
      ],
    );
  }
}

class _CartStepButton extends StatelessWidget {
  final IconData icon;
  final bool strong;
  final VoidCallback onTap;

  const _CartStepButton({
    required this.icon,
    required this.onTap,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: strong ? AppColors.primary : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary),
        ),
        child: Icon(
          icon,
          size: 16,
          color: strong ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _LegacyCartDetailSheet extends StatelessWidget {
  final List<OrderEntry> carts;

  const _LegacyCartDetailSheet({required this.carts});

  @override
  Widget build(BuildContext context) {
    final orders = carts.map((entry) => entry.order).toList();
    final totalItems = orders.fold<int>(
      0,
      (sum, order) => sum + order.itemCount,
    );
    final totalPrice = orders.fold<int>(0, (sum, order) => sum + order.total);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    carts.length == 1
                        ? orders.first.restaurant.name
                        : '${carts.length} giỏ hàng đang có',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: orders.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in order.items) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CartFoodImage(path: item.imageUrl),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity} phần · ${item.toppings.isEmpty ? 'Không topping' : item.toppings.join(', ')}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF757575),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              checkoutFormatPrice(item.lineTotal),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        if (item != order.items.last)
                          const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          checkoutFormatPrice(order.total),
                          style: const TextStyle(
                            color: Color(0xFF616161),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$totalItems món · ${checkoutFormatPrice(totalPrice)}',
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutPage(order: orders.first),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Xem giỏ hàng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartFoodImage extends StatelessWidget {
  final String path;

  const _CartFoodImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final image = path.startsWith('assets/')
        ? Image.asset(path, width: 54, height: 54, fit: BoxFit.cover)
        : Image.network(path, width: 54, height: 54, fit: BoxFit.cover);
    return ClipRRect(borderRadius: BorderRadius.circular(7), child: image);
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.gray500;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? activeIcon : icon, color: color, size: 19),
                  if (badgeCount > 0)
                    Positioned(
                      right: -10,
                      top: -7,
                      child: _BottomNavBadge(count: badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBadge extends StatelessWidget {
  final int count;

  const _BottomNavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          height: 1.0,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
