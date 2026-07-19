import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_pages.dart';
import 'order_state.dart';
import 'order_tracking_detail_page.dart';

class OrdersPage extends StatefulWidget {
  final VoidCallback? onBack;

  const OrdersPage({super.key, this.onBack});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _activeTab = 0;

  static const _tabs = [
    'Đang giao',
    'Deal đã mua',
    'Lịch sử',
    'Đánh giá',
    'Đơn nháp',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _buildHeader(context),
                _buildTabs(),
                Expanded(
                  child: ValueListenableBuilder<List<OrderEntry>>(
                    valueListenable: OrderState.entries,
                    builder: (context, entries, _) {
                      final visible = _entriesForTab(entries)
                        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                      if (visible.isEmpty) {
                        return _EmptyOrderState(
                          tabLabel: _tabs[_activeTab],
                          onExplore: widget.onBack,
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) =>
                            _OrderCard(entry: visible[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<OrderEntry> _entriesForTab(List<OrderEntry> entries) {
    return switch (_activeTab) {
      0 =>
        entries
            .where((entry) => entry.status == OrderStatus.delivering)
            .toList(),
      1 =>
        entries
            .where(_isCompletedEntry)
            .where((entry) => entry.order.discount > 0)
            .toList(),
      2 => entries.where(_isCompletedEntry).toList(),
      3 =>
        entries
            .where((entry) => entry.status == OrderStatus.delivered)
            .toList(),
      4 => entries.where((entry) => entry.status == OrderStatus.cart).toList(),
      _ => <OrderEntry>[],
    };
  }

  bool _isCompletedEntry(OrderEntry entry) {
    return entry.status == OrderStatus.delivered ||
        entry.status == OrderStatus.rated;
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.primary,
            iconSize: 18,
            tooltip: 'Quay lại',
          ),
          const Expanded(
            child: Text(
              'Đơn hàng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _openOrderSearch(context),
            icon: const Icon(Icons.search_rounded),
            color: AppColors.primary,
            iconSize: 20,
            tooltip: 'Tìm đơn hàng',
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 38,
      color: Colors.white,
      child: ValueListenableBuilder<List<OrderEntry>>(
        valueListenable: OrderState.entries,
        builder: (context, entries, _) {
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final active = index == _activeTab;
              return InkWell(
                onTap: () => setState(() => _activeTab = index),
                child: Container(
                  width: switch (index) {
                    0 => 74,
                    1 => 72,
                    2 => 58,
                    3 => 60,
                    _ => 60,
                  },
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: _OrderTabLabel(
                    label: _tabs[index],
                    count: _tabCount(entries, index),
                    active: active,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _tabCount(List<OrderEntry> entries, int index) {
    return switch (index) {
      0 =>
        entries.where((entry) => entry.status == OrderStatus.delivering).length,
      1 =>
        entries
            .where(_isCompletedEntry)
            .where((entry) => entry.order.discount > 0)
            .length,
      2 => entries.where(_isCompletedEntry).length,
      3 =>
        entries.where((entry) => entry.status == OrderStatus.delivered).length,
      4 => entries.where((entry) => entry.status == OrderStatus.cart).length,
      _ => 0,
    };
  }

  Future<void> _openOrderSearch(BuildContext context) async {
    final entries = List<OrderEntry>.of(OrderState.entries.value)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await showSearch<void>(
      context: context,
      delegate: _OrderSearchDelegate(entries),
    );
  }
}

class _OrderTabLabel extends StatelessWidget {
  final String label;
  final int count;
  final bool active;

  const _OrderTabLabel({
    required this.label,
    required this.count,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : const Color(0xFF424242);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Container(
            constraints: const BoxConstraints(minWidth: 15),
            height: 15,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : const Color(0xFFFFE5DE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                color: active ? Colors.white : AppColors.primary,
                fontSize: 8.5,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderSearchDelegate extends SearchDelegate<void> {
  final List<OrderEntry> entries;

  _OrderSearchDelegate(this.entries);

  @override
  String? get searchFieldLabel => 'Tìm quán, món, địa chỉ...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.4,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Xóa',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      tooltip: 'Quay lại',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final results = _filteredEntries();
    if (results.isEmpty) {
      return _OrderSearchEmptyState(hasQuery: query.trim().isNotEmpty);
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
        itemCount: results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _OrderCard(entry: results[index]),
      ),
    );
  }

  List<OrderEntry> _filteredEntries() {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return entries.take(10).toList();

    return entries.where((entry) {
      final order = entry.order;
      final itemNames = order.items.map((item) => item.name).join(' ');
      final haystack = [
        order.restaurant.name,
        order.restaurant.address,
        order.address,
        order.paymentMethod,
        itemNames,
        _statusTextForEntry(entry),
      ].join(' ').toLowerCase();
      return haystack.contains(keyword);
    }).toList();
  }
}

class _OrderSearchEmptyState extends StatelessWidget {
  final bool hasQuery;

  const _OrderSearchEmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.fromLTRB(24, 84, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasQuery ? 'Không tìm thấy đơn phù hợp' : 'Chưa có đơn để tìm',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Thử tìm theo tên quán, tên món hoặc địa chỉ giao hàng.'
                : 'Các đơn trong giỏ, đang giao và lịch sử sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: const TextStyle(
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

class _OrderCard extends StatelessWidget {
  final OrderEntry entry;

  const _OrderCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    final firstItem = order.items.isEmpty ? null : order.items.first;

    return InkWell(
      onTap: () => _openEntry(context),
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
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0ED),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon, color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                    ],
                  ),
                ),
                Text(
                  checkoutFormatPrice(order.total),
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (firstItem != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _OrderFoodImage(path: firstItem.imageUrl),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItem.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _itemSummary(order),
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _OrderActionRow(entry: entry, onOpen: () => _openEntry(context)),
          ],
        ),
      ),
    );
  }

  String _itemSummary(CheckoutOrder order) {
    final extra = order.items.length > 1
        ? ' · +${order.items.length - 1} món'
        : '';
    return '${order.itemCount} món$extra · ${order.paymentMethod}';
  }

  IconData get _statusIcon {
    return switch (entry.status) {
      OrderStatus.cart => Icons.shopping_basket_outlined,
      OrderStatus.delivering => Icons.delivery_dining_rounded,
      OrderStatus.delivered => Icons.check_circle_outline_rounded,
      OrderStatus.rated => Icons.star_rounded,
    };
  }

  String get _statusText {
    return _statusTextForEntry(entry);
  }

  void _openEntry(BuildContext context) {
    if (entry.status == OrderStatus.cart) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CheckoutPage(order: entry.order)),
      );
      return;
    }
    if (entry.status == OrderStatus.delivering) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingDetailPage(entry: entry),
        ),
      );
      return;
    }
    _showDeliveredOrderSheet(context, entry);
  }
}

class _OrderActionRow extends StatelessWidget {
  final OrderEntry entry;
  final VoidCallback onOpen;

  const _OrderActionRow({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final secondary = _secondaryAction(context);

    return Row(
      children: [
        if (secondary != null) ...[
          Expanded(child: secondary),
          const SizedBox(width: 8),
        ] else
          const Spacer(),
        SizedBox(
          height: 32,
          child: ElevatedButton(
            onPressed: () => _primaryAction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              _primaryLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  String get _primaryLabel {
    return switch (entry.status) {
      OrderStatus.cart => 'Tiếp tục đặt',
      OrderStatus.delivering => 'Xem lộ trình',
      OrderStatus.delivered => 'Đánh giá',
      OrderStatus.rated => 'Đặt lại',
    };
  }

  void _primaryAction(BuildContext context) {
    switch (entry.status) {
      case OrderStatus.cart:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CheckoutPage(order: entry.order)),
        );
      case OrderStatus.delivering:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingDetailPage(entry: entry),
          ),
        );
      case OrderStatus.delivered:
        _showDeliveredOrderSheet(context, entry);
      case OrderStatus.rated:
        final order = OrderState.mergeCartItem(entry.order);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CheckoutPage(order: order)),
        );
    }
  }

  Widget? _secondaryAction(BuildContext context) {
    if (entry.status == OrderStatus.cart) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: () => _confirmRemoveCart(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: Color(0xFFFFCCBC)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text(
            'Xóa giỏ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    if (entry.status == OrderStatus.delivered ||
        entry.status == OrderStatus.rated) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: () => _showDeliveredOrderSheet(context, entry),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF424242),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            entry.status == OrderStatus.rated ? 'Xem đánh giá' : 'Chi tiết',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onOpen,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF424242),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text(
          'Chi tiết',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveCart(BuildContext context) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Xóa giỏ hàng?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Các món từ ${entry.order.restaurant.name} sẽ được xóa khỏi giỏ.',
          style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;
    OrderState.removeCart(entry.order.restaurant.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã xóa giỏ hàng'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          duration: Duration(milliseconds: 900),
        ),
      );
  }
}

String _statusTextForEntry(OrderEntry entry) {
  return switch (entry.status) {
    OrderStatus.cart => 'Đang có trong giỏ',
    OrderStatus.delivering => 'Đang vận chuyển',
    OrderStatus.delivered => 'Đã giao · Chờ đánh giá',
    OrderStatus.rated => 'Đã đánh giá',
  };
}

class _OrderFoodImage extends StatelessWidget {
  final String path;

  const _OrderFoodImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final image = path.startsWith('assets/')
        ? Image.asset(path, width: 50, height: 50, fit: BoxFit.cover)
        : Image.network(
            path,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 50,
              height: 50,
              color: const Color(0xFFEDEDED),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(7), child: image);
  }
}

class _EmptyOrderState extends StatelessWidget {
  final String tabLabel;
  final VoidCallback? onExplore;

  const _EmptyOrderState({required this.tabLabel, this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: Color(0xFFE4E4E4))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                tabLabel == 'Đánh giá'
                    ? Icons.star_border_rounded
                    : Icons.receipt_long_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _titleForTab(tabLabel),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF424242),
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _messageForTab(tabLabel),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6F6F6F),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (onExplore != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: onExplore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    _actionForTab(tabLabel),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _titleForTab(String tabLabel) {
    if (tabLabel == 'Đơn nháp') return 'Chưa có món trong giỏ';
    if (tabLabel == 'Đang giao') return 'Chưa có đơn đang giao';
    if (tabLabel == 'Đánh giá') return 'Chưa có đơn cần đánh giá';
    return 'Chưa có dữ liệu';
  }

  String _messageForTab(String tabLabel) {
    if (tabLabel == 'Đang giao') {
      return 'Đơn đã đặt và trạng thái tài xế sẽ hiển thị tại đây.';
    }
    if (tabLabel == 'Đơn nháp') {
      return 'Món vừa thêm vào giỏ sẽ nằm ở đây để bạn quay lại đặt tiếp.';
    }
    if (tabLabel == 'Đánh giá') {
      return 'Sau khi nhận món, bạn có thể đánh giá quán và tài xế tại đây.';
    }
    return 'Lịch sử đơn hàng sẽ hiển thị khi bạn hoàn tất đơn.';
  }

  String _actionForTab(String tabLabel) {
    if (tabLabel == 'Deal đã mua') return 'Săn deal ngay';
    if (tabLabel == 'Đơn nháp') return 'Đặt món ngay';
    return 'Về trang chủ';
  }
}

void _showDeliveredOrderSheet(BuildContext context, OrderEntry entry) {
  var shopRating = entry.shopRating ?? 0;
  var driverRating = entry.driverRating ?? 0;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void updateRating({int? shop, int? driver}) {
            setModalState(() {
              shopRating = shop ?? shopRating;
              driverRating = driver ?? driverRating;
            });
            if (shopRating > 0 && driverRating > 0) {
              if (entry.id.isNotEmpty) {
                OrderState.rateEntry(
                  entryId: entry.id,
                  shopRating: shopRating,
                  driverRating: driverRating,
                );
              } else {
                OrderState.rateOrder(
                  restaurantId: entry.order.restaurant.id,
                  shopRating: shopRating,
                  driverRating: driverRating,
                );
              }
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.status == OrderStatus.rated
                              ? 'Đơn đã đánh giá'
                              : 'Đơn đã giao thành công',
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.order.restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.order.itemCount} món · ${checkoutFormatPrice(entry.order.total)}',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SheetRatingRow(
                    label: 'Đánh giá quán',
                    value: shopRating,
                    onChanged: (value) => updateRating(shop: value),
                  ),
                  const SizedBox(height: 10),
                  _SheetRatingRow(
                    label: 'Đánh giá tài xế',
                    value: driverRating,
                    onChanged: (value) => updateRating(driver: value),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: FilledButton(
                      onPressed: shopRating > 0 && driverRating > 0
                          ? () => Navigator.pop(sheetContext)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFFFFCCBC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Hoàn tất'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SheetRatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SheetRatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var i = 1; i <= 5; i++)
          InkWell(
            onTap: () => onChanged(i),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFFFB300),
                size: 23,
              ),
            ),
          ),
      ],
    );
  }
}
