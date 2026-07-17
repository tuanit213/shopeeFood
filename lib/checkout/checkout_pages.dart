import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../orders/order_state.dart';
import '../orders/order_tracking_detail_page.dart';
import 'checkout_models.dart';

const _bg = Color(0xFFF5F5F5);
const _textDark = Color(0xFF212121);
const _textGray = Color(0xFF757575);
const _line = Color(0xFFEDEDED);
const _blue = Color(0xFF1A73E8);

class CheckoutPage extends StatefulWidget {
  final CheckoutOrder order;

  const CheckoutPage({super.key, required this.order});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late CheckoutOrder _order;
  int _deliveryMode = 0;
  int _tip = 0;
  bool _useCutlery = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _openPaymentMethod() async {
    final method = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodPage(selectedMethod: _order.paymentMethod),
      ),
    );
    if (method == null || !mounted) return;
    setState(() => _order = _order.copyWith(paymentMethod: method));
  }

  void _showConfirmDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmOrderDialog(order: _order, tip: _tip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _order.total + _tip;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.4,
        leadingWidth: 42,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        title: const Text(
          'Xác nhận đơn hàng',
          style: TextStyle(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 14),
        children: [
          _CheckoutCard(
            children: [
              _InfoTile(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.primary,
                title: _order.address,
                subtitle: '${_order.receiverName} | ${_order.receiverPhone}',
                trailing: 'Thay đổi',
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              const _SectionTitle('Thời gian giao hàng'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceBox(
                      selected: _deliveryMode == 0,
                      title: 'Giao ngay',
                      subtitle:
                          '${_order.restaurant.deliveryMinutes + 8}-${_order.restaurant.deliveryMinutes + 18} phút',
                      onTap: () => setState(() => _deliveryMode = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceBox(
                      selected: _deliveryMode == 1,
                      title: 'Đặt lịch',
                      subtitle: 'Chọn giờ nhận',
                      onTap: () => setState(() => _deliveryMode = 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              _SectionTitle(_order.restaurant.name),
              const SizedBox(height: 10),
              for (final item in _order.items) _OrderItemRow(item: item),
              const Divider(height: 22, color: _line),
              _NoteRow(
                icon: Icons.edit_note_rounded,
                text: 'Ghi chú cho quán',
                value: 'Không cay, để riêng nước chấm',
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              _InfoTile(
                icon: Icons.local_offer_outlined,
                iconColor: AppColors.primary,
                title: 'Voucher ShopeeFood',
                subtitle: _order.discount > 0
                    ? 'Đã áp dụng ${checkoutFormatPrice(_order.discount)}'
                    : 'Chọn mã giảm giá',
                trailing: 'Chọn',
              ),
              const Divider(height: 18, color: _line),
              _InfoTile(
                icon: Icons.payments_outlined,
                iconColor: AppColors.primary,
                title: _order.paymentMethod,
                subtitle: 'Phương thức thanh toán',
                trailing: 'Đổi',
                onTap: _openPaymentMethod,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _openPaymentMethod,
                  child: const Text(
                    'Phương thức thanh toán khác',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              const _SectionTitle('Thưởng tài xế'),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final value in [0, 5000, 10000, 15000]) ...[
                    Expanded(
                      child: _TipChip(
                        value: value,
                        selected: _tip == value,
                        onTap: () => setState(() => _tip = value),
                      ),
                    ),
                    if (value != 15000) const SizedBox(width: 6),
                  ],
                ],
              ),
              const Divider(height: 22, color: _line),
              Row(
                children: [
                  const Icon(
                    Icons.flatware_outlined,
                    color: _textGray,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Lấy dụng cụ ăn uống',
                      style: TextStyle(fontSize: 13, color: _textDark),
                    ),
                  ),
                  Switch(
                    value: _useCutlery,
                    activeThumbColor: AppColors.success,
                    onChanged: (value) => setState(() => _useCutlery = value),
                  ),
                ],
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              _PriceRow('Tạm tính', _order.subtotal),
              _PriceRow('Phí giao hàng', _order.deliveryFee),
              _PriceRow('Phí dịch vụ', _order.serviceFee),
              if (_order.discount > 0)
                _PriceRow('Giảm giá', -_order.discount, highlight: true),
              if (_tip > 0) _PriceRow('Thưởng tài xế', _tip),
              const Divider(height: 20, color: _line),
              _PriceRow('Tổng cộng', total, total: true),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _showConfirmDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Đặt đơn - ${checkoutFormatPrice(total)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentMethodPage extends StatefulWidget {
  final String selectedMethod;

  const PaymentMethodPage({super.key, required this.selectedMethod});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedMethod;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
        title: const Text(
          'Phương thức thanh toán',
          style: TextStyle(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                Text(
                  'SHOPEE ĐẢM BẢO',
                  style: TextStyle(
                    color: _textGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.verified_user_outlined, color: _textGray, size: 16),
              ],
            ),
          ),
          _PaymentCard(
            children: [
              _PaymentRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Số dư Ví ShopeePay',
                subtitle: 'Nhanh chóng, nhiều ưu đãi',
                trailing: _SmallOutlineButton('Nâng cấp'),
              ),
              _PaymentRow(
                icon: Icons.schedule_outlined,
                title: 'SPayLater',
                subtitle: 'Mua trước trả sau',
                trailing: _SmallOutlineButton('Nộp lại hồ sơ'),
              ),
              _PaymentRow(
                icon: Icons.account_balance_outlined,
                title: 'Ngân hàng liên kết Ví ShopeePay',
                subtitle: 'Chưa khả dụng',
                disabled: true,
              ),
              _PaymentRow(
                icon: Icons.add_circle_outline_rounded,
                title: 'Thêm Ngân hàng liên kết',
                subtitle: 'Hỗ trợ nhiều ngân hàng nội địa',
                trailing: const Text(
                  '+23',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SelectablePaymentRow(
                title: 'Thanh toán khi nhận hàng',
                icon: Icons.payments_outlined,
                selected: _selected == 'Tiền mặt',
                onTap: () => setState(() => _selected = 'Tiền mặt'),
              ),
              _SelectablePaymentRow(
                title: 'Thẻ Tín dụng/Ghi nợ',
                subtitle: 'Visa/Mastercard/JCB',
                icon: Icons.credit_card_outlined,
                selected: _selected == 'Thẻ',
                onTap: () => setState(() => _selected = 'Thẻ'),
              ),
              _SelectablePaymentRow(
                title: 'Thẻ nội địa Napas',
                icon: Icons.credit_score_outlined,
                selected: _selected == 'Napas',
                onTap: () => setState(() => _selected = 'Napas'),
              ),
              _SelectablePaymentRow(
                title: 'Apple Pay',
                subtitle: 'Mới',
                icon: Icons.phone_iphone_outlined,
                selected: _selected == 'Apple Pay',
                onTap: () => setState(() => _selected = 'Apple Pay'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          color: Colors.white,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'ĐỒNG Ý',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrderTrackingPage extends StatelessWidget {
  final CheckoutOrder order;

  const OrderTrackingPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leadingWidth: 42,
        leading: IconButton(
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
          icon: const Icon(
            Icons.close_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: const Text(
          'Theo dõi đơn hàng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CheckoutCard(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đơn đã được nhận',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Dự kiến giao sau ${order.restaurant.deliveryMinutes + 12} phút',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _TrackingStep(
                title: 'Quán đang chuẩn bị món',
                active: true,
                subtitle: order.restaurant.name,
              ),
              const _TrackingStep(
                title: 'Tài xế đến lấy món',
                active: false,
                subtitle: 'Đang tìm tài xế gần quán',
              ),
              _TrackingStep(
                title: 'Giao đến bạn',
                active: false,
                subtitle: order.address,
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConfirmOrderDialog extends StatefulWidget {
  final CheckoutOrder order;
  final int tip;

  const ConfirmOrderDialog({super.key, required this.order, required this.tip});

  @override
  State<ConfirmOrderDialog> createState() => _ConfirmOrderDialogState();
}

class _ConfirmOrderDialogState extends State<ConfirmOrderDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  int _seconds = 9;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..reverse(from: 1);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        _placeOrder();
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _placeOrder() {
    if (!mounted) return;
    OrderState.markDelivering(widget.order);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderTrackingDetailPage(
          entry: OrderEntry(
            order: widget.order,
            status: OrderStatus.delivering,
            updatedAt: DateTime.now(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.order.total + widget.tip;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 22),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) => CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 3,
                    color: AppColors.primary,
                    backgroundColor: _line,
                  ),
                ),
              ),
              Text(
                '${_seconds}s',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Xác nhận đặt đơn',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Bạn ơi, hãy kiểm tra thông tin lần nữa nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGray, fontSize: 13, height: 1.35),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                _DialogInfoRow(
                  icon: Icons.location_on_outlined,
                  text:
                      '${widget.order.address}\n${widget.order.receiverName} | ${widget.order.receiverPhone}',
                ),
                const SizedBox(height: 12),
                const _DialogInfoRow(
                  icon: Icons.access_time_outlined,
                  text: 'Giao ngay trong hôm nay',
                ),
                const SizedBox(height: 12),
                _DialogInfoRow(
                  icon: Icons.receipt_long_outlined,
                  text:
                      '${checkoutFormatPrice(total)} (${widget.order.itemCount} món) | ${widget.order.paymentMethod}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: _line),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: _line),
                Expanded(
                  child: TextButton(
                    onPressed: _placeOrder,
                    child: const Text(
                      'Đặt đơn ngay',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

class _CheckoutCard extends StatelessWidget {
  final List<Widget> children;

  const _CheckoutCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _textDark,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGray, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceBox extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceBox({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.primary : _textDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: _textGray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final CartItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.toppings.isNotEmpty) item.toppings.join(', '),
      if (item.note.trim().isNotEmpty) item.note.trim(),
    ].join(' | ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.quantity}x',
            style: const TextStyle(
              color: _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textGray, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            checkoutFormatPrice(item.lineTotal),
            style: const TextStyle(
              color: _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String value;

  const _NoteRow({required this.icon, required this.text, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _textGray, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _textDark, fontSize: 13),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _textGray, fontSize: 12),
        ),
      ],
    );
  }
}

class _TipChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _TipChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          value == 0 ? 'Không' : checkoutFormatPrice(value),
          style: TextStyle(
            color: selected ? AppColors.primary : _textDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;
  final bool total;

  const _PriceRow(
    this.label,
    this.value, {
    this.highlight = false,
    this.total = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : _textDark;
    final prefix = value < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: total ? _textDark : _textGray,
                fontSize: total ? 14 : 13,
                fontWeight: total ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$prefix${checkoutFormatPrice(value.abs())}',
            style: TextStyle(
              color: color,
              fontSize: total ? 16 : 13,
              fontWeight: total ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final List<Widget> children;

  const _PaymentCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool disabled;

  const _PaymentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled ? const Color(0xFFBDBDBD) : _textDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line, width: 0.7)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: disabled ? const Color(0xFFBDBDBD) : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _textGray, fontSize: 11),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SelectablePaymentRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectablePaymentRow({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line, width: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (subtitle == 'Mới') ...[
                        const SizedBox(width: 6),
                        const _NewBadge(),
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle != 'Mới') ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: _textGray, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            _PaymentRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _PaymentRadio extends StatelessWidget {
  final bool selected;

  const _PaymentRadio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFBDBDBD),
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
          : null,
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  final String label;

  const _SmallOutlineButton(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'Mới',
        style: TextStyle(color: _textGray, fontSize: 10),
      ),
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DialogInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _textDark,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool last;

  const _TrackingStep({
    required this.title,
    required this.subtitle,
    required this.active,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              child: active
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
            if (!last)
              Container(width: 1, height: 42, color: const Color(0xFFE0E0E0)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? _textDark : _textGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGray, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
