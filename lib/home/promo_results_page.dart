import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_pages.dart';
import '../orders/order_state.dart';
import '../restaurant/restaurant_detail_page.dart';

class PromoResultsPage extends StatefulWidget {
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
  State<PromoResultsPage> createState() => _PromoResultsPageState();
}

class _PromoResultsPageState extends State<PromoResultsPage> {
  int _activeTab = 0;

  List<_PromoItem> _sortItems(List<_PromoItem> items) {
    final sorted = List<_PromoItem>.of(items);
    switch (_activeTab) {
      case 1:
        sorted.sort((a, b) => b.sold.compareTo(a.sold));
      case 2:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case 3:
        sorted.sort((a, b) => a.deliveryMinutes.compareTo(b.deliveryMinutes));
      default:
        sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final config = _CategoryPromoConfig.resolve(
      widget.title,
      widget.subtitle,
      widget.seed,
    );
    final items = _sortItems(_PromoItem.itemsFor(config));

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
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _PromoHeader(config: config)),
                  SliverToBoxAdapter(
                    child: _CampaignShortcutStrip(config: config),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CampaignTabsDelegate(
                      activeIndex: _activeTab,
                      onTap: (index) => setState(() => _activeTab = index),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 74),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _CampaignPromoCard(
                        item: items[index],
                        accent: config.accent,
                        onTap: () =>
                            _openPromoRestaurant(context, items[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: ValueListenableBuilder<List<OrderEntry>>(
                valueListenable: OrderState.entries,
                builder: (context, entries, _) {
                  final cartEntries = _cartEntries(entries);
                  return _MyDealsFloatingPill(
                    count: _cartItemCount(cartEntries),
                    onTap: () => _showMyDealsSheet(context, config),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDealsFloatingPill extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MyDealsFloatingPill({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFFFCCBC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_mall_outlined,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Deal của tôi ($count)',
                style: const TextStyle(
                  color: Color(0xFF6D4C41),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMyDealsSheet(BuildContext context, _CategoryPromoConfig config) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) => _MyDealsSheetContent(config: config),
  );
}

class _MyDealsSheetContent extends StatefulWidget {
  final _CategoryPromoConfig config;

  const _MyDealsSheetContent({required this.config});

  @override
  State<_MyDealsSheetContent> createState() => _MyDealsSheetContentState();
}

class _MyDealsSheetContentState extends State<_MyDealsSheetContent> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 440,
        child: ValueListenableBuilder<List<OrderEntry>>(
          valueListenable: OrderState.entries,
          builder: (context, entries, _) {
            final cartEntries = _cartEntries(entries);
            final count = _cartItemCount(cartEntries);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Deal của tôi ($count)',
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF757575),
                      ),
                    ],
                  ),
                ),
                _MyDealsLocationRow(config: widget.config),
                _MyDealsTabBar(
                  activeIndex: _activeTab,
                  onTap: (index) => setState(() => _activeTab = index),
                ),
                if (_activeTab == 1)
                  const Expanded(
                    child: _MyDealsEmptyState(
                      title: 'Chưa có Deal đã dùng',
                      description:
                          'Các deal đã đặt hoặc hết hạn sẽ được lưu tại đây để bạn xem lại.',
                      actionLabel: 'Quay lại săn Deal',
                    ),
                  )
                else if (cartEntries.isEmpty)
                  const Expanded(child: _MyDealsEmptyState())
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                      itemCount: cartEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _MyDealRestaurantGroup(entry: cartEntries[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyDealsTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _MyDealsTabBar({required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          _MyDealsTab(
            label: 'Có hiệu lực',
            selected: activeIndex == 0,
            onTap: () => onTap(0),
          ),
          _MyDealsTab(
            label: 'Đã dùng/Hết hạn',
            selected: activeIndex == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _MyDealsTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MyDealsTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : const Color(0xFF424242),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 70 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyDealsLocationRow extends StatelessWidget {
  final _CategoryPromoConfig config;

  const _MyDealsLocationRow({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Giao đến: ${config.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF616161),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9E9E9E)),
        ],
      ),
    );
  }
}

class _MyDealsEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;

  const _MyDealsEmptyState({
    this.title = 'Bạn chưa có Deal nào',
    this.description = 'Lướt săn Deal, thêm món ngon rồi đặt ngay tại đây.',
    this.actionLabel = 'Săn Deal ngay',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _MyDealsEmptyIllustration(),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF616161),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(116, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MyDealsEmptyIllustration extends StatelessWidget {
  const _MyDealsEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 4,
            child: Container(
              width: 62,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const Positioned(
            left: 10,
            top: 18,
            child: Icon(
              Icons.restaurant_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          Container(
            width: 48,
            height: 34,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Positioned(
            right: 10,
            top: 19,
            child: Icon(
              Icons.local_dining_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDealRestaurantGroup extends StatelessWidget {
  final OrderEntry entry;

  const _MyDealRestaurantGroup({required this.entry});

  @override
  Widget build(BuildContext context) {
    final order = entry.order;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 9, 7),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${order.restaurant.distanceKm.toStringAsFixed(1)}km · ${order.restaurant.deliveryMinutes} phút',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  checkoutFormatPrice(order.total),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          for (final item in order.items)
            _MyDealItemRow(restaurantId: order.restaurant.id, item: item),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.itemCount} món · Tạm tính ${checkoutFormatPrice(order.subtotal)}',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutPage(order: order),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Đặt nhóm này',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _MyDealItemRow extends StatelessWidget {
  final String restaurantId;
  final CartItem item;

  const _MyDealItemRow({required this.restaurantId, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 9, 0),
      child: Row(
        children: [
          _FoodImage(path: item.imageUrl, size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  checkoutFormatPrice(item.unitPrice),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _DealQtyButton(
            icon: Icons.remove_rounded,
            onTap: () => OrderState.updateCartItemQuantity(
              restaurantId: restaurantId,
              item: item,
              quantity: item.quantity - 1,
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _DealQtyButton(
            icon: Icons.add_rounded,
            onTap: () => OrderState.updateCartItemQuantity(
              restaurantId: restaurantId,
              item: item,
              quantity: item.quantity + 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DealQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DealQtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton.filled(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFFFF0ED),
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 16),
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
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      height: 102,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: config.accent.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -30,
            child: _GlowCircle(size: 94, color: Colors.white),
          ),
          Positioned(
            left: -34,
            bottom: -40,
            child: _GlowCircle(size: 104, color: Colors.yellowAccent),
          ),
          Positioned(
            right: 84,
            top: -18,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                width: 38,
                height: 136,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: -30,
            child: _GlowCircle(size: 82, color: Colors.white),
          ),
          Positioned(
            right: 12,
            top: 16,
            child: Text(
              config.emoji,
              style: TextStyle(
                fontSize: config.emoji.length > 2 ? 34 : 40,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.92),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
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
            padding: const EdgeInsets.fromLTRB(12, 11, 96, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  config.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
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

class _CampaignShortcutStrip extends StatelessWidget {
  final _CategoryPromoConfig config;

  const _CampaignShortcutStrip({required this.config});

  @override
  Widget build(BuildContext context) {
    const shortcuts = [
      (Icons.workspace_premium_outlined, 'Duy nhất\nhôm nay'),
      (Icons.flash_on_rounded, 'Flash\nSale'),
      (Icons.card_giftcard_rounded, 'Ưu đãi\nsuất ăn'),
      (Icons.star_border_rounded, 'Nổi bật'),
      (Icons.local_offer_outlined, 'Voucher'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Row(
        children: [
          for (final item in shortcuts)
            Expanded(
              child: InkWell(
                onTap: () {},
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: config.accent.withValues(alpha: 0.08),
                        border: Border.all(
                          color: config.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(item.$1, size: 14, color: config.accent),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF616161),
                        fontSize: 8.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
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

class _CampaignTabsDelegate extends SliverPersistentHeaderDelegate {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _CampaignTabsDelegate({required this.activeIndex, required this.onTap});

  static const _tabs = ['Gần tôi', 'Bán chạy', 'Đánh giá', 'Giao nhanh'];

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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: activeIndex == index
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      color: activeIndex == index
                          ? AppColors.primary
                          : const Color(0xFF424242),
                      fontSize: 12,
                      fontWeight: activeIndex == index
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CampaignTabsDelegate oldDelegate) {
    return oldDelegate.activeIndex != activeIndex;
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

class _CampaignPromoCard extends StatelessWidget {
  final _PromoItem item;
  final Color accent;
  final VoidCallback onTap;

  const _CampaignPromoCard({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final menuPreview = _previewItemsFor(item);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FoodImage(path: item.image, size: 68),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFFFFA000),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.restaurant,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF212121),
                                fontSize: 13,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB300),
                            size: 13,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF616161),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF9E9E9E),
                            size: 12,
                          ),
                          Text(
                            '${item.distanceKm.toStringAsFixed(1)}km',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF9E9E9E),
                            size: 12,
                          ),
                          Text(
                            '${item.deliveryMinutes} phút',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _SmallChip(label: item.tagA),
                          _SmallChip(label: item.tagB),
                          _DiscountBadge(
                            discount: item.discount,
                            color: accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final preview in menuPreview) ...[
              _PromoMenuPreviewRow(item: item, preview: preview),
              if (preview != menuPreview.last) const SizedBox(height: 7),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.sold} đã bán hôm nay',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: () => _orderPromoItemNow(context, item),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Mua ngay',
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
    );
  }
}

class _PromoMenuPreviewRow extends StatelessWidget {
  final _PromoItem item;
  final _PromoMenuPreview preview;

  const _PromoMenuPreviewRow({required this.item, required this.preview});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FoodImage(path: preview.image, size: 38),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF424242),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _formatPrice(preview.price),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (preview.originalPrice > preview.price)
                    Text(
                      _formatPrice(preview.originalPrice),
                      style: const TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton.filled(
            onPressed: () => _addPromoPreviewToCart(context, item, preview),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.add_rounded, size: 17),
          ),
        ),
      ],
    );
  }
}

class _PromoMenuPreview {
  final String id;
  final String name;
  final int price;
  final int originalPrice;
  final String image;

  const _PromoMenuPreview({
    required this.id,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.image,
  });
}

List<_PromoMenuPreview> _previewItemsFor(_PromoItem item) {
  return [
    _PromoMenuPreview(
      id: item.id,
      name: item.name,
      price: item.price,
      originalPrice: item.originalPrice,
      image: item.image,
    ),
    _PromoMenuPreview(
      id: '${item.id}-combo',
      name: _alternateDishName(item),
      price: (item.price * 0.82).round(),
      originalPrice: (item.originalPrice * 0.92).round(),
      image:
          _localFoodImages[(item.id.hashCode.abs() + 7) %
              _localFoodImages.length],
    ),
  ];
}

String _alternateDishName(_PromoItem item) {
  final dishes = [
    'Combo thêm nước tiết kiệm',
    'Món bán chạy trong ngày',
    'Set no bụng giá tốt',
    'Ưu đãi chỉ có hôm nay',
    'Phần ăn kèm freeship',
  ];
  return dishes[item.id.hashCode.abs() % dishes.length];
}

// ignore: unused_element
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
                          fontSize: 13,
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

void _addPromoPreviewToCart(
  BuildContext context,
  _PromoItem item,
  _PromoMenuPreview preview,
) {
  OrderState.mergeCartItem(_checkoutOrderForPromoPreview(item, preview));
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${preview.name} vào giỏ hàng'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
}

List<OrderEntry> _cartEntries(List<OrderEntry> entries) {
  return entries
      .where((entry) => entry.status == OrderStatus.cart)
      .where((entry) => entry.order.items.isNotEmpty)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

int _cartItemCount(List<OrderEntry> entries) {
  return entries.fold(0, (sum, entry) => sum + entry.order.itemCount);
}

void _orderPromoItemNow(BuildContext context, _PromoItem item) {
  final order = OrderState.mergeCartItem(_checkoutOrderForPromoItem(item));
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CheckoutPage(order: order)),
  );
}

void _openPromoRestaurant(BuildContext context, _PromoItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailPage(
        restaurant: RestaurantDetailInput(
          id: 'promo-${_stableId(item.restaurant)}',
          name: item.restaurant,
          address: item.address,
          seed: item.id,
          category: item.tagA,
          rating: item.rating,
          distance: item.distanceKm,
          time: item.deliveryMinutes,
          sold: item.sold,
          imageUrl: item.image,
          openNow: true,
          latitude: item.latitude,
          longitude: item.longitude,
          customerLatitude: _mockUserLatitude,
          customerLongitude: _mockUserLongitude,
        ),
      ),
    ),
  );
}

CheckoutOrder _checkoutOrderForPromoItem(_PromoItem item) {
  return _checkoutOrderForPromoPreview(
    item,
    _PromoMenuPreview(
      id: item.id,
      name: item.name,
      price: item.price,
      originalPrice: item.originalPrice,
      image: item.image,
    ),
  );
}

CheckoutOrder _checkoutOrderForPromoPreview(
  _PromoItem item,
  _PromoMenuPreview preview,
) {
  return CheckoutOrder(
    restaurant: CheckoutRestaurantInfo(
      id: 'promo-${_stableId(item.restaurant)}',
      name: item.restaurant,
      address: item.address,
      deliveryMinutes: item.deliveryMinutes,
      distanceKm: item.distanceKm,
      latitude: item.latitude,
      longitude: item.longitude,
    ),
    items: [
      CartItem(
        id: preview.id,
        name: preview.name,
        description: '${item.tagA} · ${item.tagB}',
        imageUrl: preview.image,
        unitPrice: preview.price,
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

  _CategoryPromoConfig copyWith({
    String? title,
    String? subtitle,
    String? badge,
    String? emoji,
    List<String>? restaurants,
    List<String>? dishes,
    List<String>? tags,
  }) {
    return _CategoryPromoConfig(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      badge: badge ?? this.badge,
      emoji: emoji ?? this.emoji,
      accent: accent,
      gradient: gradient,
      restaurants: restaurants ?? this.restaurants,
      dishes: dishes ?? this.dishes,
      images: images,
      tags: tags ?? this.tags,
    );
  }

  static _CategoryPromoConfig resolve(
    String title,
    String subtitle,
    String seed,
  ) {
    final key = '$title $subtitle $seed'.toLowerCase();
    if (key.contains('hàn')) return _cleanPromoConfig(_configs['korean']!);
    if (key.contains('mart')) return _cleanPromoConfig(_configs['mart']!);
    if (key.contains('xiên') || key.contains('ăn vặt')) {
      return _cleanPromoConfig(_configs['skewer']!);
    }
    if (key.contains('katinat') || key.contains('trà')) {
      return _cleanPromoConfig(_configs['katinat']!);
    }
    if (key.contains('đặt trước') || key.contains('dat_truoc')) {
      return _cleanPromoConfig(_configs['pickup']!);
    }
    if (key.contains('ví') || key.contains('vi_dung_dinh')) {
      return _cleanPromoConfig(_configs['wallet']!);
    }
    if (key.contains('lễ hội') || key.contains('deal_le_hoi')) {
      return _cleanPromoConfig(_configs['festival']!);
    }
    if (key.contains('freeship')) {
      return _cleanPromoConfig(_configs['freeship']!);
    }
    if (key.contains('50k')) return _cleanPromoConfig(_configs['discount50']!);
    return _cleanPromoConfig(_configs['deal']!);
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
  final double rating;
  final int sold;
  final int deliveryMinutes;
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
    required this.rating,
    required this.sold,
    required this.deliveryMinutes,
    required this.image,
    required this.tagA,
    required this.tagB,
  });

  static List<_PromoItem> itemsFor(_CategoryPromoConfig config) {
    final restaurants = _cleanRestaurantsFor(config.id, config.restaurants);
    final dishes = _cleanDishesFor(config.id, config.dishes);
    final tags = _cleanTagsFor(config.id, config.tags);
    return List.generate(24, (index) {
      final basePrice = 24000 + (index % 8) * 7000 + (index ~/ 8) * 3000;
      final discount = 30 + (index * 7 + config.id.length) % 36;
      final original = (basePrice / (1 - discount / 100)).round();
      return _PromoItem(
        id: '${config.id}-$index',
        restaurant:
            '${restaurants[index % restaurants.length]} - CN ${index + 1}',
        name: dishes[index % dishes.length],
        address: _cleanMockAddresses[index % _cleanMockAddresses.length],
        latitude: _mockRestaurantLatitude(index),
        longitude: _mockRestaurantLongitude(index),
        distanceKm: _mockDistanceKm(index),
        price: basePrice,
        originalPrice: original,
        discount: discount,
        rating: 4.2 + ((index + config.id.length) % 8) / 10,
        sold: 38 + index * 9 + config.id.length * 3,
        deliveryMinutes: 18 + (index % 8) * 3,
        image: config.images[index % config.images.length],
        tagA: tags[index % tags.length],
        tagB: index.isEven ? 'Mã giảm ${(15 + index % 5 * 5)}K' : 'Freeship',
      );
    });
  }
}

_CategoryPromoConfig _cleanPromoConfig(_CategoryPromoConfig config) {
  final meta = _cleanPromoMeta[config.id];
  if (meta == null) return config;
  return config.copyWith(
    title: meta.title,
    subtitle: meta.subtitle,
    badge: meta.badge,
    emoji: meta.emoji,
    restaurants: _cleanRestaurantsFor(config.id, config.restaurants),
    dishes: _cleanDishesFor(config.id, config.dishes),
    tags: _cleanTagsFor(config.id, config.tags),
  );
}

List<String> _cleanRestaurantsFor(String id, List<String> fallback) {
  return _cleanRestaurants[id] ?? fallback;
}

List<String> _cleanDishesFor(String id, List<String> fallback) {
  return _cleanDishes[id] ?? fallback;
}

List<String> _cleanTagsFor(String id, List<String> fallback) {
  return _cleanTags[id] ?? fallback;
}

class _CleanPromoMeta {
  final String title;
  final String subtitle;
  final String badge;
  final String emoji;

  const _CleanPromoMeta({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.emoji,
  });
}

const Map<String, _CleanPromoMeta> _cleanPromoMeta = {
  'deal': _CleanPromoMeta(
    title: 'Deal Đỉnh Hôm Nay',
    subtitle: 'Món hot giảm sâu, canh giờ là có giá đẹp',
    badge: 'Giảm tới 65%',
    emoji: '7.7',
  ),
  'korean': _CleanPromoMeta(
    title: 'Món Hàn',
    subtitle: 'Gà rán, tokbokki, kimbap chuẩn vị Hàn',
    badge: 'Gà rán -50%',
    emoji: 'KR',
  ),
  'mart': _CleanPromoMeta(
    title: 'Mart',
    subtitle: 'Nhu yếu phẩm, đồ uống, snack giao nhanh',
    badge: 'Giảm 177K',
    emoji: 'M',
  ),
  'skewer': _CleanPromoMeta(
    title: 'Xiên Que',
    subtitle: 'Ăn vặt đêm, xiên chiên, sốt cay cực cuốn',
    badge: 'Freeship 0Đ',
    emoji: 'XQ',
  ),
  'katinat': _CleanPromoMeta(
    title: 'KATINAT & Trà sữa',
    subtitle: 'Trà sữa, cà phê, matcha mát lạnh',
    badge: 'Giảm đến 100K',
    emoji: 'TEA',
  ),
  'pickup': _CleanPromoMeta(
    title: 'Đặt Trước',
    subtitle: 'Đặt trước, lấy tại quán, khỏi chờ lâu',
    badge: 'Lấy tại quán',
    emoji: 'GO',
  ),
  'wallet': _CleanPromoMeta(
    title: 'Ví Đúng Đỉnh',
    subtitle: 'Thanh toán ví, hoàn xu, giảm thêm mỗi đơn',
    badge: 'Hoàn xu x5',
    emoji: 'PAY',
  ),
  'festival': _CleanPromoMeta(
    title: 'Deal Lễ Hội',
    subtitle: 'Món tiệc, combo nhóm, ưu đãi mùa lễ',
    badge: 'Giảm 40K',
    emoji: 'WOW',
  ),
  'freeship': _CleanPromoMeta(
    title: 'Freeship Xtra',
    subtitle: 'Quán gần bạn, phí ship nhẹ, chốt đơn nhanh',
    badge: 'Ship 0Đ',
    emoji: '0Đ',
  ),
  'discount50': _CleanPromoMeta(
    title: 'Giảm 50K',
    subtitle: 'Voucher lớn cho món ngon mỗi ngày',
    badge: 'Voucher 50K',
    emoji: '50K',
  ),
};

const Map<String, List<String>> _cleanRestaurants = {
  'deal': [
    'Gà Rán Popeyes',
    'Cơm Tấm Đêm',
    'Bún Đậu 1975',
    'Mì Cay Seoul',
    'Bánh Mì Chảo Cô Ba',
    'Burger Station',
  ],
  'korean': [
    'Gà Rán K-Food',
    'Chicken Seoul',
    'Kimbap & Tokbokki',
    'Oppa Kitchen',
    'Busan Bites',
    'Kimchi House',
  ],
  'mart': [
    'ShopeeFood Mart',
    'Mini Stop',
    'Family Mart',
    'Circle K',
    'GS25',
    'Bách Hóa Nhanh',
  ],
  'skewer': [
    'Xiên Que Cô Ba',
    'Ăn Vặt Hẻm',
    'Tokbokki & Xiên',
    'Bếp Nướng Ống Tre',
    'Cá Viên 1999',
    'Snack Corner',
  ],
  'katinat': [
    'KATINAT',
    'Phúc Long',
    'Mơ Coffee',
    'Milk Tea House',
    'Trà Sữa Nhà Làm',
    'Matcha Lab',
  ],
  'pickup': [
    'Bếp Nhà 5 Phút',
    'Cơm Văn Phòng',
    'Bánh Mì Mẹ Làm',
    'Healthy Box',
    'Bún Thịt Nướng 88',
    'Cơm Gà Hội An',
  ],
  'wallet': [
    'Ví Deal Food',
    'Xu Xtra Kitchen',
    'Pay Day Meals',
    'Hoàn Xu Quán',
    'Voucher Kitchen',
    'Cashback Bites',
  ],
  'festival': [
    'Tiệc Nhà Vui',
    'Gà Nướng Cơm Lam',
    'Lẩu Mini Party',
    'BBQ Home',
    'Pizza Party',
    'Mẹt Ngon Cuối Tuần',
  ],
  'freeship': [
    'Freeship Kitchen',
    'Quán Gần Đây',
    'Ship 0Đ Food',
    'Xtra Deal',
    'Bếp Gần Nhà',
    'Giao Nhanh Quán',
  ],
  'discount50': [
    'Voucher Food',
    'Deal 50K Quán',
    'Món Ngon Giá Hời',
    'Bếp Ưu Đãi',
    'Tiệm Ngon Mỗi Ngày',
    'Ăn No Deal Lớn',
  ],
};

const Map<String, List<String>> _cleanTags = {
  'deal': ['Flash Sale', 'Deal sốc', 'Freeship Xtra', 'Mua ngay'],
  'korean': ['Mã giảm 25K', 'Chuẩn vị Hàn', 'Freeship', 'Best seller'],
  'mart': ['Giao 20 phút', 'Mart deal', 'Mã 177K', 'Mua kèm rẻ'],
  'skewer': ['Ăn vặt hot', 'Freeship 0Đ', 'Mua 2 giảm', 'Đêm nay'],
  'katinat': ['Best seller', 'Giảm 100K', 'Mua 1 tặng 1', 'Size L'],
  'pickup': ['Không cần chờ', 'Pickup deal', 'Giữ món', 'Đặt trước'],
  'wallet': ['Hoàn xu', 'Ví giảm thêm', 'Deal ví', 'Xu x5'],
  'festival': ['Combo nhóm', 'Giảm 40K', 'Tiệc ngon', 'Set đông người'],
  'freeship': ['Freeship Xtra', 'Gần bạn', 'Ship 0Đ', 'Giao nhanh'],
  'discount50': ['Voucher 50K', 'Giảm mạnh', 'Món hời', 'Săn deal'],
};

const Map<String, List<String>> _cleanDishes = {
  'deal': [
    'Combo Gà Giòn + Khoai Tây',
    'Cơm Sườn Nướng Mỡ Hành',
    'Bún Đậu Nem Chua Chả Cốm',
    'Mì Cay Hải Sản Cấp Độ 2',
    'Burger Bò Phô Mai + Pepsi',
    'Bánh Mì Chảo Đặc Biệt',
    'Cơm Gà Xối Mỡ Da Giòn',
    'Bún Bò Huế Tô Đặc Biệt',
    'Phở Bò Tái Nạm Gầu',
    'Hủ Tiếu Nam Vang Tôm Thịt',
    'Bánh Canh Cua Chả Cá',
    'Cháo Sườn Quẩy Giòn',
    'Cơm Chiên Hải Sản',
    'Mì Ý Sốt Bò Bằm',
    'Pizza Hải Sản Mini',
    'Gỏi Cuốn Tôm Thịt',
    'Bánh Xèo Miền Tây',
    'Bún Thịt Nướng Nem',
    'Cơm Tấm Bì Chả Trứng',
    'Mì Trộn Tóp Mỡ',
    'Gà Sốt Cay Hàn Quốc',
    'Lẩu Thái Mini',
    'Bò Lúc Lắc Khoai Tây',
    'Bánh Mì Heo Quay',
  ],
  'korean': [
    'Combo Gà Rán Sốt Hàn + Khoai',
    'Cánh Gà Sốt Cay Hàn Quốc',
    'Tokbokki Phô Mai Cay',
    'Kimbap Cá Ngừ Rong Biển',
    'Cơm Trộn Bulgogi Bibimbap',
    'Mì Tương Đen Jajangmyeon',
    'Gà Không Xương Sốt Mật Ong',
    'Miến Trộn Japchae',
    'Canh Kimchi Thịt Heo',
    'Cơm Gà Sốt Teriyaki',
    'Hotdog Phô Mai Kéo Sợi',
    'Bánh Gạo Lắc Phô Mai',
    'Mandu Chiên Nhân Thịt',
    'Gà Sốt Tỏi Đậu Nành',
    'Cơm Cuộn Thanh Cua',
    'Mì Cay Bò Mỹ',
    'Lẩu Tokbokki Mini',
    'Gà Rán Sốt Snow Cheese',
    'Cơm Bento Hàn Quốc',
    'Bánh Cá Hàn Quốc',
    'Tokbokki Hải Sản',
    'Kimbap Bulgogi',
    'Mì Lạnh Bibim Guksu',
    'Set Gà Rán Gia Đình',
  ],
  'mart': [
    'Combo Nước Suối + Snack Khoai',
    'Sữa Tươi Ít Đường Lốc 4 Hộp',
    'Mì Ly Hải Sản + Xúc Xích',
    'Trái Cây Cắt Sẵn Hộp Lớn',
    'Bánh Sandwich + Cà Phê Lon',
    'Combo Kem Mát Lạnh',
    'Nước Cam Ép Chai Lạnh',
    'Sữa Chua Uống Lốc 4',
    'Bánh Quy Bơ Hộp Nhỏ',
    'Snack Rong Biển Giòn',
    'Cà Phê Sữa Đá Đóng Chai',
    'Trà Đào Chai Lạnh',
    'Xúc Xích Ăn Liền',
    'Bánh Bao Nóng',
    'Salad Rau Củ Hộp',
    'Combo Mì + Trứng + Nước',
    'Kem Ốc Quế Chocolate',
    'Nước Tăng Lực Lon',
    'Bánh Gạo Cay Hàn Quốc',
    'Hộp Cơm Gà Teriyaki',
    'Trà Sữa Đóng Chai',
    'Bắp Rang Bơ Túi Lớn',
    'Bánh Mì Que Pate',
    'Combo Snack Xem Phim',
  ],
  'skewer': [
    'Set Xiên Que Sốt Cay',
    'Xúc Xích Quay + Khoai Lắc',
    'Cá Viên Chiên Mắm Tỏi',
    'Nem Chua Rán Hà Nội',
    'Xiên Bò Lá Lốt Nướng',
    'Phô Mai Que Kéo Sợi',
    'Tôm Viên Chiên Giòn',
    'Đậu Hũ Cá Phô Mai',
    'Bánh Tráng Trộn Đặc Biệt',
    'Bánh Tráng Cuốn Bơ',
    'Khoai Tây Lắc Xí Muội',
    'Gà Viên Sốt Cay',
    'Chả Cá Hàn Quốc Xiên',
    'Mực Viên Chiên',
    'Bò Viên Sốt Sa Tế',
    'Hồ Lô Nướng Mật Ong',
    'Tokbokki Sốt Phô Mai',
    'Trứng Cút Lắc Me',
    'Bắp Xào Bơ Tép',
    'Chân Gà Sả Tắc',
    'Khô Gà Lá Chanh',
    'Mẹt Ăn Vặt 2 Người',
    'Set Xiên Nướng Muối Ớt',
    'Combo Đêm Không Ngủ',
  ],
  'katinat': [
    'Trà Sữa Oolong Nướng',
    'Trà Đào Cam Sả Size L',
    'Matcha Latte Kem Mặn',
    'Cà Phê Sữa Đá Đậm Vị',
    'Trà Lài Vải Tươi',
    'Sữa Tươi Trân Châu Đường Đen',
    'Oolong Sen Vàng',
    'Trà Xanh Macchiato',
    'Cold Brew Cam Vàng',
    'Cacao Kem Cheese',
    'Trà Dâu Tằm Nha Đam',
    'Matcha Đậu Đỏ',
    'Cà Phê Muối',
    'Trà Sữa Earl Grey',
    'Oolong Đào Sữa',
    'Trà Chanh Mật Ong',
    'Latte Caramel Đá',
    'Trà Sữa Khoai Môn',
    'Soda Vải Bạc Hà',
    'Trà Tắc Xí Muội',
    'Americano Đá',
    'Trà Sữa Socola',
    'Matcha Dừa Non',
    'Combo 2 Ly Best Seller',
  ],
  'pickup': [
    'Cơm Gà Xối Mỡ Đặt Trước',
    'Bánh Mì Heo Quay Giòn Bì',
    'Salad Ức Gà Sốt Mè Rang',
    'Cơm Trưa Sườn Bì Chả',
    'Bún Thịt Nướng Nem',
    'Set Cơm Gia Đình Mini',
    'Cơm Cá Kho Tộ',
    'Cơm Bò Lúc Lắc',
    'Bánh Mì Gà Xé',
    'Cơm Chiên Dương Châu',
    'Bún Chả Hà Nội',
    'Mì Xào Hải Sản',
    'Cơm Gà Hội An',
    'Bánh Cuốn Nóng',
    'Xôi Gà Lá Chanh',
    'Cơm Văn Phòng 3 Món',
    'Bún Riêu Cua',
    'Phở Gà Ta',
    'Mì Quảng Gà',
    'Hủ Tiếu Bò Kho',
    'Gỏi Gà Măng Cụt',
    'Cơm Tôm Rim',
    'Bánh Mì Chảo Bò',
    'Set Healthy Low Carb',
  ],
  'wallet': [
    'Combo Cơm Gà Hoàn Xu',
    'Pizza Mini Thanh Toán Ví',
    'Trà Sữa Deal Ví Đúng Đỉnh',
    'Burger Gà Giòn Tặng Xu',
    'Bún Bò Voucher Ví',
    'Mì Ý Sốt Bò Bằm',
    'Cơm Tấm Hoàn Xu X5',
    'Gà Rán Ví Ưu Đãi',
    'Bánh Mì Chảo Cashback',
    'Bún Đậu Thanh Toán Ví',
    'Combo Mì Cay Tặng Xu',
    'Hủ Tiếu Nam Vang Giảm Ví',
    'Cơm Bò Lúc Lắc Ví Deal',
    'Trà Đào Hoàn Xu',
    'Sushi Bento Ví Đúng Đỉnh',
    'Lẩu Thái Mini Cashback',
    'Cà Phê Sữa Ví Giảm',
    'Gỏi Cuốn Tôm Thịt Tặng Xu',
    'Cơm Gà Teriyaki Ví',
    'Bánh Canh Cua Hoàn Xu',
    'Bánh Xèo Voucher Ví',
    'Set Ăn Vặt Thanh Toán Ví',
    'Combo 2 Người Xu Xtra',
    'Deal Trưa Hoàn Xu',
  ],
  'festival': [
    'Combo Gà Nướng Cơm Lam',
    'Lẩu Thái Hải Sản Mini',
    'Set BBQ Heo Bò Nướng',
    'Pizza Hải Sản Size L',
    'Mẹt Bún Đậu Đại Tiệc',
    'Combo Trà Sữa 4 Ly',
    'Gà Rán Tiệc Nhóm',
    'Lẩu Kim Chi Gia Đình',
    'Mẹt Ăn Vặt Lễ Hội',
    'Combo Burger 3 Người',
    'Cơm Gà Nướng Sốt Mật Ong',
    'Set Xiên Nướng Party',
    'Bò Né Chảo Nóng',
    'Sườn Nướng BBQ',
    'Mì Cay Hải Sản Đại Tiệc',
    'Bánh Mì Que Combo',
    'Sushi Party Box',
    'Gỏi Cuốn Khai Vị',
    'Cánh Gà Sốt Cay',
    'Pizza Phô Mai Kéo Sợi',
    'Cơm Chiên Dương Châu Lớn',
    'Lẩu Bò Nhúng Ớt',
    'Combo Gia Đình 4 Món',
    'Tiệc Ngon Cuối Tuần',
  ],
  'freeship': [
    'Cơm Tấm Freeship Xtra',
    'Bún Bò Huế Gần Bạn',
    'Gà Rán Ship 0Đ',
    'Bánh Canh Cua Nóng',
    'Cháo Sườn Quẩy Giòn',
    'Hủ Tiếu Nam Vang',
    'Bánh Mì Heo Quay Gần Nhà',
    'Cơm Gà Xối Mỡ Ship Nhanh',
    'Bún Thịt Nướng Freeship',
    'Mì Trộn Tóp Mỡ 0Đ Ship',
    'Phở Bò Tái Gần Bạn',
    'Cơm Chiên Hải Sản',
    'Gỏi Cuốn Tôm Thịt',
    'Bánh Xèo Miền Tây',
    'Bún Riêu Cua Đồng',
    'Mì Quảng Gà',
    'Bò Kho Bánh Mì',
    'Cháo Lòng Nóng',
    'Cơm Cá Kho Tộ',
    'Bánh Cuốn Nóng',
    'Xôi Mặn Thập Cẩm',
    'Cơm Văn Phòng Freeship',
    'Set Ăn Trưa Giao Nhanh',
    'Combo Gần Đây Giá Tốt',
  ],
  'discount50': [
    'Combo Burger Bò Giảm 50K',
    'Cơm Gà Mắm Tỏi Voucher',
    'Bún Thái Hải Sản Chua Cay',
    'Mì Trộn Tóp Mỡ Trứng Lòng Đào',
    'Gỏi Cuốn Tôm Thịt',
    'Bánh Xèo Miền Tây',
    'Gà Rán Combo Voucher 50K',
    'Pizza Xúc Xích Phô Mai',
    'Cơm Sườn Que Mật Ong',
    'Lẩu Tokbokki Hải Sản',
    'Bánh Mì Chảo Đặc Biệt',
    'Mì Cay Bò Mỹ',
    'Bún Đậu Mắm Tôm',
    'Cơm Bò Lúc Lắc',
    'Sushi Mix Giảm 50K',
    'Bánh Canh Ghẹ',
    'Hủ Tiếu Sa Tế Nai',
    'Cháo Ếch Singapore',
    'Cơm Gà Hội An',
    'Trà Sữa Combo 2 Ly',
    'Bánh Tráng Trộn Đặc Biệt',
    'Cơm Niêu Cá Kho',
    'Set BBQ Mini',
    'Deal No Bụng 50K',
  ],
};

const List<String> _cleanMockAddresses = [
  '23 Đường số 6, Vĩnh Lộc A, Bình Chánh, TP.HCM',
  '41 Nguyễn Thị Tú, Bình Hưng Hòa B, Bình Tân, TP.HCM',
  '12A Đường Công Nghệ Mới, Vĩnh Lộc B, Bình Chánh, TP.HCM',
  '88 Liên Ấp 2-6, Vĩnh Lộc A, Bình Chánh, TP.HCM',
  '19 Hẻm 5 Tây Lân, Bình Trị Đông A, Bình Tân, TP.HCM',
  '56 Đường số 4, KCN Vĩnh Lộc, Bình Tân, TP.HCM',
  '102 Quách Điêu, Vĩnh Lộc A, Bình Chánh, TP.HCM',
  '7A Đường 1A, An Lạc, Bình Tân, TP.HCM',
];

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
];

const _mockUserLatitude = 10.7843;
const _mockUserLongitude = 106.5682;

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

// ignore: unused_element
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FoodImage(path: item.image, size: 82),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatPrice(item.price)}  ·  ${item.tagA}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
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
                    const SizedBox(height: 9),
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
