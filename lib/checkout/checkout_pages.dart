import 'dart:async';

import 'package:flutter/material.dart';

import '../address/address_pages.dart';
import '../address/address_repository.dart';
import '../address/delivery_address.dart';
import '../app/app_colors.dart';
import '../location/location_service.dart';
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
  int _deliveryMode = 1;
  late String _deliveryTimeLabel;
  int _tip = 0;
  bool _useCutlery = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _deliveryTimeLabel = _order.deliveryTimeLabel.isEmpty
        ? _standardDeliveryLabel(_order.restaurant.deliveryMinutes)
        : _order.deliveryTimeLabel;
    if (_order.deliveryTimeLabel.startsWith('Hẹn giờ')) {
      _deliveryMode = 2;
    }
    _tip = _order.driverTip;
    _useCutlery = _order.useCutlery;
  }

  CheckoutOrder get _effectiveOrder => _order.copyWith(
    driverTip: _tip,
    useCutlery: _useCutlery,
    deliveryTimeLabel: _deliveryTimeLabel,
  );

  void _applyOrder(CheckoutOrder nextOrder) {
    final effectiveOrder = _withCurrentControls(nextOrder);
    setState(() => _order = effectiveOrder);
    OrderState.upsertCart(effectiveOrder);
  }

  void _applyOrderWithControls(CheckoutOrder nextOrder) {
    setState(() {
      _order = nextOrder;
      _tip = nextOrder.driverTip;
      _useCutlery = nextOrder.useCutlery;
      if (nextOrder.deliveryTimeLabel.isNotEmpty) {
        _deliveryTimeLabel = nextOrder.deliveryTimeLabel;
      }
    });
    OrderState.upsertCart(nextOrder);
  }

  CheckoutOrder _withCurrentControls(CheckoutOrder order) {
    return order.copyWith(
      driverTip: _tip,
      useCutlery: _useCutlery,
      deliveryTimeLabel: _deliveryTimeLabel,
    );
  }

  void _setDriverTip(int value) {
    _applyOrderWithControls(_order.copyWith(driverTip: value));
  }

  void _setUseCutlery(bool value) {
    _applyOrderWithControls(_order.copyWith(useCutlery: value));
  }

  Future<void> _openPaymentMethod() async {
    final method = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodPage(selectedMethod: _order.paymentMethod),
      ),
    );
    if (method == null || !mounted) return;
    _applyOrder(_order.copyWith(paymentMethod: method));
  }

  Future<void> _openDeliveryAddress() async {
    final selected = await AddressRepository.loadSelectedAddress();
    if (!mounted) return;

    final currentLocation = AppLocation(
      latitude: _order.deliveryLatitude ?? selected?.latitude ?? 10.7843,
      longitude: _order.deliveryLongitude ?? selected?.longitude ?? 106.5682,
      address: _order.address,
      isFallback: false,
    );

    final currentSelected =
        selected ??
        DeliveryAddress(
          id: 'current-location',
          label: 'Nhà',
          receiverName: _order.receiverName,
          phone: _order.receiverPhone,
          address: _order.address,
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        );

    final result = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressBookPage(
          currentLocation: currentLocation,
          selectedAddress: currentSelected,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final normalized = result.normalized();
    final nextOrder = _order.copyWith(
      address: normalized.displayAddress,
      receiverName: normalized.receiverName.isEmpty
          ? _order.receiverName
          : normalized.receiverName,
      receiverPhone: normalized.phone.isEmpty
          ? _order.receiverPhone
          : normalized.phone,
      deliveryLatitude: normalized.latitude,
      deliveryLongitude: normalized.longitude,
    );
    _applyOrder(nextOrder);
  }

  void _showConfirmDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmOrderDialog(order: _effectiveOrder),
    );
  }

  Future<void> _editOrderNote() async {
    final controller = TextEditingController(text: _order.orderNote);
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ghi chú cho quán',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 120,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: không cay, để riêng nước chấm...',
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, controller.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Lưu ghi chú'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (note == null || !mounted) return;
    _applyOrder(_order.copyWith(orderNote: note));
  }

  Future<void> _openVoucherPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VoucherPickerSheet(
        subtotal: _order.subtotal,
        selectedDiscount: _order.voucherDiscount,
      ),
    );
    if (selected == null || !mounted) return;
    _applyOrder(_order.copyWith(voucherDiscount: selected));
  }

  void _setDeliveryMode(int mode) {
    final label = switch (mode) {
      0 => _priorityDeliveryLabel(_order.restaurant.deliveryMinutes),
      1 => _standardDeliveryLabel(_order.restaurant.deliveryMinutes),
      _ => _deliveryTimeLabel,
    };
    final nextOrder = _order.copyWith(deliveryTimeLabel: label);
    setState(() => _deliveryMode = mode);
    _applyOrderWithControls(nextOrder);
  }

  Future<void> _openScheduleSheet() async {
    final label = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DeliveryScheduleSheet(
        selectedLabel: _deliveryMode == 2 ? _deliveryTimeLabel : '',
      ),
    );
    if (label == null || !mounted) return;
    final nextOrder = _order.copyWith(deliveryTimeLabel: label);
    setState(() => _deliveryMode = 2);
    _applyOrderWithControls(nextOrder);
  }

  void _addSuggestion(_CheckoutSuggestion suggestion) {
    final incoming = CartItem(
      id: 'addon-${suggestion.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9À-ỹ]+', unicode: true), '-')}',
      name: suggestion.name,
      description: suggestion.description,
      imageUrl: suggestion.imageUrl,
      unitPrice: suggestion.price,
      quantity: 1,
      toppings: const [],
      note: '',
    );

    final items = List<CartItem>.of(_order.items);
    final index = items.indexWhere((item) => item.id == incoming.id);
    if (index >= 0) {
      final oldItem = items[index];
      items[index] = oldItem.copyWith(quantity: oldItem.quantity + 1);
    } else {
      items.add(incoming);
    }

    final nextOrder = _order.copyWith(items: items);
    _applyOrder(nextOrder);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${suggestion.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
          backgroundColor: AppColors.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final total = _effectiveOrder.total;

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
                onTap: _openDeliveryAddress,
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              Row(
                children: [
                  const Expanded(child: _SectionTitle('Thời gian giao hàng')),
                  TextButton(
                    onPressed: _openScheduleSheet,
                    style: TextButton.styleFrom(
                      foregroundColor: _blue,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _deliveryMode == 2 ? 'Đổi giờ' : 'Đổi sang hẹn giờ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceBox(
                      selected: _deliveryMode == 0,
                      title: _priorityDeliveryLabel(
                        _order.restaurant.deliveryMinutes,
                      ),
                      subtitle: 'Ưu tiên tài xế gần quán',
                      onTap: () => _setDeliveryMode(0),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ChoiceBox(
                      selected: _deliveryMode == 1,
                      title: _standardDeliveryLabel(
                        _order.restaurant.deliveryMinutes,
                      ),
                      subtitle: 'Giao ngay hôm nay',
                      onTap: () => _setDeliveryMode(1),
                    ),
                  ),
                ],
              ),
              if (_deliveryMode == 2) ...[
                const SizedBox(height: 7),
                _ScheduledDeliveryNotice(label: _deliveryTimeLabel),
              ],
            ],
          ),
          _CheckoutCard(
            children: [
              _SectionTitle(_order.restaurant.name),
              const SizedBox(height: 8),
              for (final item in _order.items) _OrderItemRow(item: item),
              const Divider(height: 18, color: _line),
              _NoteRow(
                icon: Icons.edit_note_rounded,
                text: 'Ghi chú cho quán',
                value: _order.orderNote.isEmpty
                    ? 'Thêm ghi chú'
                    : _order.orderNote,
                onTap: _editOrderNote,
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              const _SectionTitle('Khách đặt các món này cùng đặt thêm'),
              const SizedBox(height: 8),
              SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _checkoutSuggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _SuggestionCard(
                    suggestion: _checkoutSuggestions[index],
                    onAdd: () => _addSuggestion(_checkoutSuggestions[index]),
                  ),
                ),
              ),
            ],
          ),
          _CheckoutCard(
            children: [
              _InfoTile(
                icon: Icons.local_offer_outlined,
                iconColor: AppColors.primary,
                title: 'Voucher ShopeeFood',
                subtitle: _order.voucherDiscount > 0
                    ? 'Đã chọn ${checkoutFormatPrice(_order.voucherDiscount)}'
                    : _order.automaticDiscount > 0
                    ? 'Tự áp ưu đãi ${checkoutFormatPrice(_order.automaticDiscount)}'
                    : 'Chọn mã giảm giá',
                trailing: _order.voucherDiscount > 0 ? 'Đổi' : 'Chọn',
                onTap: _openVoucherPicker,
              ),
              const Divider(height: 15, color: _line),
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
                    'Phương thức khác',
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
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final value in [0, 5000, 10000, 15000]) ...[
                    Expanded(
                      child: _TipChip(
                        value: value,
                        selected: _tip == value,
                        onTap: () => _setDriverTip(value),
                      ),
                    ),
                    if (value != 15000) const SizedBox(width: 6),
                  ],
                ],
              ),
              const Divider(height: 18, color: _line),
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
                    onChanged: _setUseCutlery,
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
              if (_order.automaticDiscount > 0)
                _PriceRow(
                  'Ưu đãi đơn hàng',
                  -_order.automaticDiscount,
                  highlight: true,
                ),
              if (_order.voucherDiscount > 0)
                _PriceRow(
                  'Voucher ShopeeFood',
                  -_order.voucherDiscount,
                  highlight: true,
                ),
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
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BottomPaymentChip(
                      label: 'Ví ShopeePay',
                      selected: _order.paymentMethod == 'ShopeePay',
                      onTap: () => _applyOrder(
                        _order.copyWith(paymentMethod: 'ShopeePay'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _BottomPaymentChip(
                      label: _order.paymentMethod,
                      selected: _order.paymentMethod != 'ShopeePay',
                      onTap: _openPaymentMethod,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showConfirmDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    'Đặt đơn - ${checkoutFormatPrice(total)}',
                    style: const TextStyle(
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

class PaymentMethodPage extends StatefulWidget {
  final String selectedMethod;

  const PaymentMethodPage({super.key, required this.selectedMethod});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _CheckoutSuggestion {
  final String name;
  final String description;
  final int price;
  final String imageUrl;

  const _CheckoutSuggestion({
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });
}

const _checkoutSuggestions = [
  _CheckoutSuggestion(
    name: 'Mì thêm',
    description: 'Ăn kèm món chính',
    price: 19000,
    imageUrl: 'assets/images/restaurants/food_02.jpg',
  ),
  _CheckoutSuggestion(
    name: 'Trà tắc',
    description: 'Ly lạnh ít ngọt',
    price: 15000,
    imageUrl: 'assets/images/restaurants/food_05.jpg',
  ),
  _CheckoutSuggestion(
    name: 'Khoai tây chiên',
    description: 'Giòn nóng',
    price: 29000,
    imageUrl: 'assets/images/restaurants/food_11.jpg',
  ),
  _CheckoutSuggestion(
    name: 'Chả giò',
    description: 'Phần nhỏ 3 cuốn',
    price: 25000,
    imageUrl: 'assets/images/restaurants/food_03.jpg',
  ),
];

String _formatEta(int minutes) {
  final safeMinutes = minutes.clamp(1, 99);
  return '00:${safeMinutes.toString().padLeft(2, '0')}';
}

String _priorityDeliveryLabel(int deliveryMinutes) {
  return 'Ưu tiên - ${_formatEta(deliveryMinutes + 8)}';
}

String _standardDeliveryLabel(int deliveryMinutes) {
  return 'Tiêu chuẩn - ${_formatEta(deliveryMinutes + 14)}';
}

class _ScheduledDeliveryNotice extends StatelessWidget {
  final String label;

  const _ScheduledDeliveryNotice({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F2),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFFFCCBC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: AppColors.primary,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryScheduleSheet extends StatelessWidget {
  final String selectedLabel;

  const _DeliveryScheduleSheet({required this.selectedLabel});

  List<String> get _slots {
    final now = DateTime.now();
    final baseHour = now.hour < 21 ? now.hour + 1 : 9;
    final tomorrow = now.hour < 21 ? false : true;
    final dayLabel = tomorrow ? 'Ngày mai' : 'Hôm nay';
    final start = baseHour.clamp(9, 22);
    return {
      for (var index = 0; index < 6; index++)
        _slotLabel(dayLabel, (start + index).clamp(9, 22)),
    }.toList();
  }

  String _slotLabel(String dayLabel, int hour) {
    final from = hour.toString().padLeft(2, '0');
    final to = (hour + 1).clamp(10, 23).toString().padLeft(2, '0');
    return 'Hẹn giờ - $dayLabel $from:00 - $to:00';
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn thời gian giao',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Đặt lịch giúp quán chuẩn bị đúng khung giờ bạn muốn nhận món.',
              style: TextStyle(color: _textGray, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            for (final slot in slots)
              _ScheduleSlotTile(
                label: slot,
                selected: slot == selectedLabel,
                onTap: () => Navigator.pop(context, slot),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutVoucher {
  final String title;
  final String subtitle;
  final int discount;
  final int minimumSubtotal;
  final IconData icon;
  final Color accent;

  const _CheckoutVoucher({
    required this.title,
    required this.subtitle,
    required this.discount,
    required this.minimumSubtotal,
    required this.icon,
    required this.accent,
  });

  bool isUsable(int subtotal) => subtotal >= minimumSubtotal;
}

const _checkoutVouchers = [
  _CheckoutVoucher(
    title: 'Freeship Xtra',
    subtitle: 'Giảm phí giao cho đơn từ 40K',
    discount: 10000,
    minimumSubtotal: 40000,
    icon: Icons.local_shipping_outlined,
    accent: AppColors.success,
  ),
  _CheckoutVoucher(
    title: 'Voucher món ngon 20K',
    subtitle: 'Áp dụng cho đơn từ 100K',
    discount: 20000,
    minimumSubtotal: 100000,
    icon: Icons.local_offer_outlined,
    accent: AppColors.primary,
  ),
  _CheckoutVoucher(
    title: 'Siêu tiệc giảm 35K',
    subtitle: 'Dành cho đơn lớn từ 180K',
    discount: 35000,
    minimumSubtotal: 180000,
    icon: Icons.flash_on_outlined,
    accent: Color(0xFFFF9800),
  ),
];

class _VoucherPickerSheet extends StatelessWidget {
  final int subtotal;
  final int selectedDiscount;

  const _VoucherPickerSheet({
    required this.subtotal,
    required this.selectedDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn Voucher ShopeeFood',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _textGray,
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: _textGray,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tạm tính món: ${checkoutFormatPrice(subtotal)}',
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  _VoucherTile(
                    title: 'Không dùng voucher',
                    subtitle: 'Chỉ áp dụng ưu đãi tự động nếu đủ điều kiện',
                    icon: Icons.block_outlined,
                    accent: _textGray,
                    selected: selectedDiscount == 0,
                    enabled: true,
                    trailing: '0đ',
                    onTap: () => Navigator.pop(context, 0),
                  ),
                  const SizedBox(height: 8),
                  for (final voucher in _checkoutVouchers) ...[
                    _VoucherTile(
                      title: voucher.title,
                      subtitle: voucher.isUsable(subtotal)
                          ? voucher.subtitle
                          : 'Cần thêm ${checkoutFormatPrice(voucher.minimumSubtotal - subtotal)} để dùng',
                      icon: voucher.icon,
                      accent: voucher.accent,
                      selected: selectedDiscount == voucher.discount,
                      enabled: voucher.isUsable(subtotal),
                      trailing: '-${checkoutFormatPrice(voucher.discount)}',
                      onTap: () => Navigator.pop(context, voucher.discount),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final bool enabled;
  final String trailing;
  final VoidCallback onTap;

  const _VoucherTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.enabled,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = enabled ? accent : const Color(0xFFBDBDBD);
    return Material(
      color: enabled ? Colors.white : const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: effectiveAccent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? _textDark : const Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? _textGray : const Color(0xFFBDBDBD),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trailing,
                    style: TextStyle(
                      color: enabled
                          ? AppColors.primary
                          : const Color(0xFFBDBDBD),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFBDBDBD),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSlotTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleSlotTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFFFF5F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : const Color(0xFFBDBDBD),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.primary : _textDark,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final _CheckoutSuggestion suggestion;
  final VoidCallback onAdd;

  const _SuggestionCard({required this.suggestion, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              child: _CheckoutFoodImage(
                path: suggestion.imageUrl,
                width: double.infinity,
                height: 54,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    suggestion.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textGray, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          checkoutFormatPrice(suggestion.price),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: ElevatedButton(
                          onPressed: onAdd,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.add_rounded, size: 16),
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

class _CheckoutFoodImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;

  const _CheckoutFoodImage({required this.path, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFFEDEDED)),
          if (path.startsWith('assets/'))
            Image.asset(path, fit: BoxFit.cover)
          else
            Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _BottomPaymentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomPaymentChip({
    required this.label,
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
          color: selected ? const Color(0xFFFFF5F2) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 13,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.primary : _textGray,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 88),
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
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          color: Colors.white,
          child: SizedBox(
            height: 44,
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
                  fontSize: 13,
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

  const ConfirmOrderDialog({super.key, required this.order});

  @override
  State<ConfirmOrderDialog> createState() => _ConfirmOrderDialogState();
}

class _ConfirmOrderDialogState extends State<ConfirmOrderDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _placed = false;
  int _seconds = 7;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
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
    if (!mounted || _placed) return;
    _placed = true;
    _timer?.cancel();
    final entry = OrderState.markDelivering(widget.order);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => OrderTrackingDetailPage(entry: entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.order.total;
    final discount = widget.order.discount;
    final itemSummary = _orderItemSummary(widget.order);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) => CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 2.4,
                    color: AppColors.primary,
                    backgroundColor: _line,
                  ),
                ),
              ),
              Text(
                '${_seconds}s',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            'Xác nhận đặt đơn',
            style: TextStyle(
              color: _textDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'Bạn ơi, hãy kiểm tra thông tin lần nữa nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGray, fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _DialogInfoRow(
                  icon: Icons.location_on_outlined,
                  text:
                      '${widget.order.address}\n${widget.order.receiverName} | ${widget.order.receiverPhone}',
                ),
                const SizedBox(height: 9),
                _DialogInfoRow(
                  icon: Icons.access_time_outlined,
                  text: widget.order.deliveryTimeLabel.isEmpty
                      ? 'Giao ngay trong hôm nay'
                      : widget.order.deliveryTimeLabel,
                ),
                const SizedBox(height: 9),
                _DialogInfoRow(
                  icon: Icons.storefront_outlined,
                  text: '${widget.order.restaurant.name}\n$itemSummary',
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 9),
                  _DialogInfoRow(
                    icon: Icons.local_offer_outlined,
                    text: 'Đã áp dụng ưu đãi -${checkoutFormatPrice(discount)}',
                  ),
                ],
                const SizedBox(height: 9),
                _DialogInfoRow(
                  icon: Icons.receipt_long_outlined,
                  text:
                      '${checkoutFormatPrice(total)} (${widget.order.itemCount} món) | ${widget.order.paymentMethod}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _line),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 13,
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
                        fontSize: 13,
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

  String _orderItemSummary(CheckoutOrder order) {
    final visibleItems = order.items
        .take(2)
        .map((item) => '${item.quantity}x ${item.name}')
        .join(', ');
    final hiddenCount = order.items.length - 2;
    if (hiddenCount <= 0) return visibleItems;
    return '$visibleItems, +$hiddenCount món khác';
  }
}

class _CheckoutCard extends StatelessWidget {
  final List<Widget> children;

  const _CheckoutCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
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
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 7),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGray, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: _textGray, fontSize: 11),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.quantity}x',
            style: const TextStyle(
              color: _textDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 7),
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
                    fontSize: 12,
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
          const SizedBox(width: 7),
          Text(
            checkoutFormatPrice(item.lineTotal),
            style: const TextStyle(
              color: _textDark,
              fontSize: 12,
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
  final VoidCallback? onTap;

  const _NoteRow({
    required this.icon,
    required this.text,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: _textGray, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _textDark, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _textGray, fontSize: 12),
            ),
          ),
        ],
      ),
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
        height: 30,
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
            fontSize: 11,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: total ? _textDark : _textGray,
                fontSize: total ? 13 : 12,
                fontWeight: total ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$prefix${checkoutFormatPrice(value.abs())}',
            style: TextStyle(
              color: color,
              fontSize: total ? 15 : 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line, width: 0.7)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: disabled ? const Color(0xFFBDBDBD) : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 9),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line, width: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 9),
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
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFBDBDBD),
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
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
      height: 27,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
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
        Icon(icon, color: AppColors.primary, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _textDark,
              fontSize: 11,
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
