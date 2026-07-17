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
      builder: (context) => _CartDetailSheet(carts: carts),
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
              height: 52 + bottomInset,
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
                  height: 52,
                  child: MediaQuery.withNoTextScaling(
                    child: Row(
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF9E9E9E),
                  size: 22,
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
  final List<OrderEntry> carts;

  const _CartDetailSheet({required this.carts});

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
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
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
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 20),
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
