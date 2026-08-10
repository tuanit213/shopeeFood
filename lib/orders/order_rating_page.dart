import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'order_state.dart';

/// Trang đánh giá sau khi đơn giao xong. Tách khỏi màn theo dõi lộ trình: khi
/// đơn hoàn thành, người dùng được chuyển hẳn sang đây để đánh giá tài xế và
/// quán ăn bằng SAO và bằng CHỮ.
class OrderRatingPage extends StatefulWidget {
  final OrderEntry entry;
  final String driverName;
  final String? driverPlate;

  const OrderRatingPage({
    super.key,
    required this.entry,
    required this.driverName,
    this.driverPlate,
  });

  @override
  State<OrderRatingPage> createState() => _OrderRatingPageState();
}

class _OrderRatingPageState extends State<OrderRatingPage> {
  late int _driverStars;
  late int _shopStars;
  late final TextEditingController _driverComment;
  late final TextEditingController _shopComment;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _driverStars = widget.entry.driverRating ?? 0;
    _shopStars = widget.entry.shopRating ?? 0;
    _driverComment = TextEditingController(
      text: widget.entry.driverComment ?? '',
    );
    _shopComment = TextEditingController(text: widget.entry.shopComment ?? '');
  }

  @override
  void dispose() {
    _driverComment.dispose();
    _shopComment.dispose();
    super.dispose();
  }

  bool get _canSubmit => _driverStars > 0 && _shopStars > 0 && !_submitted;

  void _submit() {
    if (!_canSubmit) return;
    setState(() => _submitted = true);

    final shopComment = _shopComment.text.trim();
    final driverComment = _driverComment.text.trim();

    if (widget.entry.id.isNotEmpty) {
      OrderState.rateEntry(
        entryId: widget.entry.id,
        shopRating: _shopStars,
        driverRating: _driverStars,
        shopComment: shopComment.isEmpty ? null : shopComment,
        driverComment: driverComment.isEmpty ? null : driverComment,
      );
    } else {
      OrderState.rateOrder(
        restaurantId: widget.entry.order.restaurant.id,
        shopRating: _shopStars,
        driverRating: _driverStars,
        shopComment: shopComment.isEmpty ? null : shopComment,
        driverComment: driverComment.isEmpty ? null : driverComment,
      );
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã đánh giá!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          duration: Duration(milliseconds: 1200),
        ),
      );

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.entry.order.restaurant;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFF212121),
            size: 22,
          ),
        ),
        title: const Text(
          'Đánh giá đơn hàng',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
            children: [
              const _DeliveredBanner(),
              const SizedBox(height: 12),
              _RatingSection(
                avatar: _CircleAvatar(
                  initial: _firstLetter(widget.driverName),
                  color: AppColors.primary,
                ),
                title: 'Đánh giá tài xế',
                subtitle: widget.driverPlate == null
                    ? widget.driverName
                    : '${widget.driverName} · ${widget.driverPlate}',
                stars: _driverStars,
                onStars: (value) => setState(() => _driverStars = value),
                controller: _driverComment,
                hint: 'Tài xế giao nhanh, thân thiện không? (không bắt buộc)',
              ),
              const SizedBox(height: 10),
              _RatingSection(
                avatar: _CircleAvatar(
                  initial: _firstLetter(restaurant.name),
                  color: const Color(0xFF00B14F),
                ),
                title: 'Đánh giá quán ăn',
                subtitle: restaurant.name,
                stars: _shopStars,
                onStars: (value) => setState(() => _shopStars = value),
                controller: _shopComment,
                hint: 'Món ăn ngon, đóng gói ổn không? (không bắt buộc)',
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFF2B8AC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Gửi đánh giá',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Để sau',
                    style: TextStyle(color: Color(0xFF757575)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstLetter(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}

class _DeliveredBanner extends StatelessWidget {
  const _DeliveredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F7EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00B14F),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn hàng đã giao thành công',
                  style: TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Đánh giá của bạn giúp quán và tài xế phục vụ tốt hơn.',
                  style: TextStyle(color: Color(0xFF757575), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  final Widget avatar;
  final String title;
  final String subtitle;
  final int stars;
  final ValueChanged<int> onStars;
  final TextEditingController controller;
  final String hint;

  const _RatingSection({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.stars,
    required this.onStars,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StarRow(value: stars, onChanged: onStars),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _starLabel(stars),
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  String _starLabel(int stars) {
    return switch (stars) {
      0 => 'Chạm vào sao để đánh giá',
      1 => 'Rất tệ',
      2 => 'Không hài lòng',
      3 => 'Bình thường',
      4 => 'Hài lòng',
      _ => 'Tuyệt vời',
    };
  }
}

class _StarRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          InkWell(
            onTap: () => onChanged(i),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFFFB300),
                size: 34,
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  final String initial;
  final Color color;

  const _CircleAvatar({required this.initial, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
