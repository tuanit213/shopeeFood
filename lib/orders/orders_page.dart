import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../checkout/checkout_models.dart';
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

  static const _tabs = ['Đang đến', 'Đơn nháp', 'Lịch sử'];

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
                      final visible = _entriesForTab(entries);
                      if (visible.isEmpty) {
                        return _EmptyOrderState(tabLabel: _tabs[_activeTab]);
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      1 => entries.where((entry) => entry.status == OrderStatus.cart).toList(),
      _ => const <OrderEntry>[],
    };
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primary,
            iconSize: 22,
            tooltip: 'Quay lại',
          ),
          const Expanded(
            child: Text(
              'Đơn hàng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showSearchHint(context),
            icon: const Icon(Icons.search_rounded),
            color: AppColors.primary,
            iconSize: 22,
            tooltip: 'Tìm đơn hàng',
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      color: Colors.white,
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _activeTab = index),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: index == _activeTab
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabs[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: index == _activeTab
                          ? AppColors.primary
                          : const Color(0xFF212121),
                      fontSize: 14,
                      fontWeight: index == _activeTab
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

  void _showSearchHint(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Chưa có thêm bộ lọc đơn hàng'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
    final isDelivering = entry.status == OrderStatus.delivering;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingDetailPage(entry: entry),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF0ED),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDelivering
                            ? Icons.delivery_dining_rounded
                            : Icons.shopping_basket_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDelivering
                                ? 'Đang vận chuyển'
                                : 'Đang có trong giỏ',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
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
                              fontSize: 14,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (firstItem != null)
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: _OrderFoodImage(path: firstItem.imageUrl),
                      ),
                      const SizedBox(width: 9),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${order.itemCount} món · ${order.paymentMethod}',
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              order.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 11,
                              ),
                            ),
                          ],
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
  }
}

class _OrderFoodImage extends StatelessWidget {
  final String path;

  const _OrderFoodImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final isAsset = path.startsWith('assets/');
    if (isAsset) {
      return Image.asset(path, width: 54, height: 54, fit: BoxFit.cover);
    }
    return Image.network(
      path,
      width: 54,
      height: 54,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 54,
        height: 54,
        color: const Color(0xFFEDEDED),
        child: const Icon(Icons.restaurant_rounded, color: Colors.white),
      ),
    );
  }
}

class _EmptyOrderState extends StatelessWidget {
  final String tabLabel;

  const _EmptyOrderState({required this.tabLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: Color(0xFFE4E4E4))),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 74, 24, 32),
          child: Column(
            children: [
              const _LoadingDots(),
              const SizedBox(height: 82),
              const SizedBox(
                width: 116,
                height: 116,
                child: CustomPaint(painter: _OrderEmptyPainter()),
              ),
              const SizedBox(height: 30),
              const Text(
                'Quên chưa đặt món rồi nè bạn ơi?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF424242),
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _messageForTab(tabLabel),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6F6F6F),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _messageForTab(String tabLabel) {
    if (tabLabel == 'Đang đến') {
      return 'Bạn sẽ nhìn thấy món đang chuẩn bị hoặc đang giao tại đây.';
    }
    if (tabLabel == 'Đơn nháp') {
      return 'Món vừa thêm vào giỏ sẽ xuất hiện ở đây để bạn quay lại đặt tiếp.';
    }
    return 'Lịch sử đơn hàng sẽ hiển thị khi bạn hoàn tất đơn.';
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Dot(opacity: 0.92, size: 10),
        SizedBox(width: 6),
        _Dot(opacity: 0.78, size: 10),
        SizedBox(width: 6),
        _Dot(opacity: 0.92, size: 14),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final double opacity;
  final double size;

  const _Dot({required this.opacity, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _OrderEmptyPainter extends CustomPainter {
  const _OrderEmptyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final red = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final paper = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.26,
        size.height * 0.14,
        size.width * 0.48,
        size.height * 0.68,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(paper, orange);

    final topCurl = Path()
      ..moveTo(size.width * 0.26, size.height * 0.24)
      ..lineTo(size.width * 0.16, size.height * 0.24)
      ..lineTo(size.width * 0.16, size.height * 0.14)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.08,
        size.width * 0.24,
        size.height * 0.08,
      )
      ..lineTo(size.width * 0.33, size.height * 0.08);
    canvas.drawPath(topCurl, orange);

    final bottomRoll = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.78,
        size.width * 0.62,
        size.height * 0.14,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(bottomRoll, orange);

    for (final y in [0.33, 0.47, 0.61]) {
      canvas.drawCircle(
        Offset(size.width * 0.34, size.height * y),
        4,
        dotPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.46, size.height * y),
        Offset(size.width * 0.68, size.height * y),
        orange,
      );
    }

    final pencil = Path()
      ..moveTo(size.width * 0.58, size.height * 0.66)
      ..lineTo(size.width * 0.91, size.height * 0.33);
    canvas.drawPath(pencil, red);

    final tip = Path()
      ..moveTo(size.width * 0.53, size.height * 0.72)
      ..lineTo(size.width * 0.59, size.height * 0.58)
      ..lineTo(size.width * 0.68, size.height * 0.67)
      ..close();
    canvas.drawPath(tip, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
