import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class OrdersPage extends StatefulWidget {
  final VoidCallback? onBack;

  const OrdersPage({super.key, this.onBack});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _activeTab = 0;

  final List<String> _tabs = const [
    'Đang đến',
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
                Expanded(child: _EmptyOrderState(tabLabel: _tabs[_activeTab])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primary,
            iconSize: 30,
            tooltip: 'Quay lại',
          ),
          const Expanded(
            child: Text(
              'Đơn hàng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showSearchHint(context),
            icon: const Icon(Icons.search_rounded),
            color: AppColors.primary,
            iconSize: 30,
            tooltip: 'Tìm đơn hàng',
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final active = index == _activeTab;

          return InkWell(
            onTap: () => setState(() => _activeTab = index),
            child: Container(
              constraints: const BoxConstraints(minWidth: 94),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppColors.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _tabs[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.primary : const Color(0xFF212121),
                  fontSize: 17,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSearchHint(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Chưa có đơn hàng để tìm kiếm'),
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
          padding: const EdgeInsets.fromLTRB(24, 86, 24, 32),
          child: Column(
            children: [
              const _LoadingDots(),
              const SizedBox(height: 100),
              const SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(painter: _OrderEmptyPainter()),
              ),
              const SizedBox(height: 34),
              const Text(
                'Quên chưa đặt món rồi nè bạn ơi?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF424242),
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _messageForTab(tabLabel),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6F6F6F),
                  fontSize: 17,
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
      return 'Bạn sẽ nhìn thấy các món đang được chuẩn bị hoặc giao đi tại đây để kiểm tra đơn hàng nhanh hơn!';
    }

    return 'Khi có dữ liệu ở mục $tabLabel, thông tin đơn hàng sẽ hiển thị tại đây.';
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Dot(opacity: 0.92, size: 14),
        SizedBox(width: 7),
        _Dot(opacity: 0.78, size: 14),
        SizedBox(width: 7),
        _Dot(opacity: 0.92, size: 18),
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
