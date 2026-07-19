import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../address/address_pages.dart';
import '../address/address_repository.dart';
import '../app/app_colors.dart';
import '../app/app_routes.dart';
import '../app/user_session.dart';
import '../checkout/checkout_pages.dart';
import '../home/promo_results_page.dart';
import '../location/location_service.dart';
import '../orders/order_state.dart';
import '../restaurant/restaurant_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  _UserProfile? _profile;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await _userSub?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userId = await UserSession.getUserId();
    if (!mounted) {
      return;
    }

    if (userId == null || userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _profile = null;
      });
      return;
    }

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) {
              return;
            }

            final data = snapshot.data();
            setState(() {
              _profile = data == null ? null : _UserProfile.fromMap(data);
              _isLoading = false;
              _errorMessage = null;
            });
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = false;
              _errorMessage = 'Không thể tải thông tin. Thử lại';
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.gray50,
        body: _ProfileSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.gray50,
        body: _ProfileErrorState(
          message: _errorMessage!,
          onRetry: _loadProfile,
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColors.gray50,
        body: _ProfileEmptyState(onLogin: () => _goToLogin(context)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: ValueListenableBuilder<List<OrderEntry>>(
        valueListenable: OrderState.entries,
        builder: (context, entries, _) {
          return _ShopeeLikeProfileContent(
            profile: profile.withOrderMetrics(
              _ProfileOrderMetrics.fromEntries(entries),
            ),
          );
        },
      ),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _skeletonBox(height: 132),
            const SizedBox(height: 16),
            _skeletonBox(height: 68),
            const SizedBox(height: 16),
            _skeletonBox(height: 220),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.gray500,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopeeLikeProfileContent extends StatelessWidget {
  final _UserProfile profile;

  const _ShopeeLikeProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 146,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF512F), AppColors.primary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.phone,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CompactProfileStat('${profile.orderCount}', 'Đơn'),
                    _CompactDivider(),
                    _CompactProfileStat('${profile.shopeeXu}', 'Xu'),
                    _CompactDivider(),
                    _CompactProfileStat(profile.ratingLabel, 'Đánh giá'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ShopeeMenuGroup(
            children: [
              _ShopeeMenuRow(
                icon: Icons.local_offer_outlined,
                iconColor: AppColors.primary,
                label: 'ShopeeFood Trùm Deal',
                onTap: () => _openShopeeFoodDeals(context),
              ),
              _ShopeeMenuRow(
                icon: Icons.favorite_border_rounded,
                iconColor: Color(0xFFE53935),
                label: 'Quán yêu thích',
                onTap: () => _openFavoriteRestaurants(context),
              ),
              _ShopeeMenuRow(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: Color(0xFF1565C0),
                label: 'Thanh toán',
                onTap: () => _openPaymentMethods(context),
              ),
              _ShopeeMenuRow(
                icon: Icons.location_on_outlined,
                iconColor: Color(0xFF009688),
                label: 'Địa chỉ',
                onTap: () => _openAddressBook(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShopeeMenuGroup(
            children: [
              _ShopeeMenuRow(
                icon: Icons.mail_outline_rounded,
                iconColor: Color(0xFF1565C0),
                label: 'Mời bạn bè',
                onTap: () => _showInviteFriends(context),
              ),
              _ShopeeMenuRow(
                icon: Icons.storefront_outlined,
                iconColor: Color(0xFFFFA000),
                label: 'Ứng dụng cho chủ quán',
                onTap: () => _showMerchantAppInfo(context),
              ),
              _ShopeeMenuRow(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.gray700,
                label: 'Đổi mật khẩu',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.changePassword),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShopeeMenuGroup(
            children: [
              _ShopeeMenuRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.primary,
                label: 'Đăng xuất',
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Đăng xuất?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Bạn sẽ cần đăng nhập lại để tiếp tục đặt món.',
            style: TextStyle(color: AppColors.gray500),
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
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) return;
    await UserSession.clear(rememberPhone: profile.phone);
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _openPaymentMethods(BuildContext context) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const PaymentMethodPage(selectedMethod: 'Tiền mặt'),
      ),
    );
  }

  void _openShopeeFoodDeals(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PromoResultsPage(
          title: 'Trùm deal ngon ShopeeFood',
          subtitle: 'Flash Sale, Freeship Xtra và voucher món ngon hôm nay',
          seed: 'profile-trum-deal',
        ),
      ),
    );
  }

  void _showInviteFriends(BuildContext context) {
    const code = 'FOODLOVER50';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              const Icon(
                Icons.card_giftcard_rounded,
                color: AppColors.primary,
                size: 42,
              ),
              const SizedBox(height: 10),
              const Text(
                'Mời bạn bè đặt món',
                style: TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bạn bè nhận voucher 50K, bạn nhận ShopeeXu sau đơn đầu tiên.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCCBC)),
                ),
                child: const Center(
                  child: Text(
                    code,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: code));
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép mã mời bạn bè'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primary,
                          duration: Duration(milliseconds: 900),
                        ),
                      );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sao chép mã mời',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMerchantAppInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFFFFA000),
                    size: 34,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ShopeeFood Merchant',
                      style: TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _MerchantBenefitRow(
                icon: Icons.receipt_long_outlined,
                text: 'Quản lý đơn mới, món bán chạy và doanh thu trong ngày.',
              ),
              const _MerchantBenefitRow(
                icon: Icons.campaign_outlined,
                text: 'Tự tạo khuyến mãi để xuất hiện trong Trùm Deal.',
              ),
              const _MerchantBenefitRow(
                icon: Icons.support_agent_outlined,
                text: 'Nhận hỗ trợ vận hành quán và giao hàng.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Tìm hiểu sau',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFavoriteRestaurants(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const FavoriteRestaurantsPage()),
    );
  }

  Future<void> _openAddressBook(BuildContext context) async {
    final selected = await AddressRepository.loadSelectedAddress();
    if (!context.mounted) return;

    final currentLocation = selected == null
        ? AppLocation.fallback
        : AppLocation(
            latitude: selected.latitude,
            longitude: selected.longitude,
            address: selected.address,
            isFallback: false,
          );

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressBookPage(
          currentLocation: currentLocation,
          selectedAddress: selected,
        ),
      ),
    );
  }
}

class _CompactProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _CompactProfileStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompactDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: Colors.white24);
  }
}

class _ShopeeMenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _ShopeeMenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }
}

class _ShopeeMenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _ShopeeMenuRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF1F1F1), width: 0.7),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.gray500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ProfileContent extends StatelessWidget {
  final _UserProfile profile;

  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.only(
              top: 60,
              left: 20,
              right: 20,
              bottom: 25,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 45,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.phone,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF59D),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.stars,
                                  color: Colors.orange,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Thành viên mới',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HeaderStatItem(title: '${profile.orderCount} Đơn đã đặt'),
                    const Text('|', style: TextStyle(color: Colors.white30)),
                    _HeaderStatItem(title: '${profile.shopeeXu} ShopeeXu'),
                    const Text('|', style: TextStyle(color: Colors.white30)),
                    _HeaderStatItem(title: profile.ratingLabel),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickActionItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Voucher',
                  color: Colors.orange,
                ),
                _QuickActionItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'ShopeePay',
                  color: Colors.red,
                ),
                _QuickActionItem(
                  icon: Icons.card_giftcard,
                  label: 'Điểm thưởng',
                  color: Colors.amber,
                ),
                _QuickActionItem(
                  icon: Icons.favorite_border,
                  label: 'Yêu thích',
                  color: Colors.pink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuSection(
            title: 'Tài khoản',
            items: [
              const _MenuItem(
                icon: Icons.person_outline,
                label: 'Thông tin cá nhân',
              ),
              _MenuItem(
                icon: Icons.lock_outline,
                label: 'Đổi mật khẩu',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.changePassword);
                },
              ),
              const _MenuItem(
                icon: Icons.location_on_outlined,
                label: 'Địa chỉ giao hàng',
              ),
              const _MenuItem(
                icon: Icons.payment_outlined,
                label: 'Phương thức thanh toán',
              ),
              const _MenuItem(
                icon: Icons.notifications_none,
                label: 'Thông báo',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMenuSection(
            title: 'Hỗ trợ',
            items: const [
              _MenuItem(icon: Icons.help_outline, label: 'Trung tâm hỗ trợ'),
              _MenuItem(
                icon: Icons.phone_in_talk_outlined,
                label: 'Liên hệ chúng tôi',
              ),
              _MenuItem(icon: Icons.star_border, label: 'Đánh giá ứng dụng'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _confirmLogout(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(Icons.logout, color: AppColors.primary),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Đăng xuất?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Bạn sẽ cần đăng nhập lại để tiếp tục đặt món.',
            style: TextStyle(color: AppColors.gray500),
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
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    await UserSession.clear(rememberPhone: profile.phone);
    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Widget> items,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.gray700,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}

class FavoriteRestaurantsPage extends StatefulWidget {
  const FavoriteRestaurantsPage({super.key});

  @override
  State<FavoriteRestaurantsPage> createState() =>
      _FavoriteRestaurantsPageState();
}

class _MerchantBenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MerchantBenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF424242),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteRestaurantsPageState extends State<FavoriteRestaurantsPage> {
  static const _favoriteSnapshotPrefsKey = 'favorite_restaurant_snapshots_v1';

  late Future<List<_FavoriteRestaurant>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _loadFavorites();
  }

  Future<List<_FavoriteRestaurant>> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoriteSnapshotPrefsKey);
    if (raw == null || raw.isEmpty) return const <_FavoriteRestaurant>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_FavoriteRestaurant.fromJson)
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const <_FavoriteRestaurant>[];
    }
  }

  Future<void> _removeFavorite(_FavoriteRestaurant restaurant) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('favorite_restaurant_ids_v1') ?? const [];
    await prefs.setStringList(
      'favorite_restaurant_ids_v1',
      ids.where((id) => id != restaurant.id).toList(),
    );

    final favorites = await _loadFavorites();
    final next = favorites
        .where((item) => item.id != restaurant.id)
        .map((item) => item.toJson())
        .toList();
    if (next.isEmpty) {
      await prefs.remove(_favoriteSnapshotPrefsKey);
    } else {
      await prefs.setString(_favoriteSnapshotPrefsKey, jsonEncode(next));
    }

    if (!mounted) return;
    setState(
      () => _favoritesFuture = Future.value(
        next
            .map(_FavoriteRestaurant.fromJson)
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList(),
      ),
    );
  }

  void _openRestaurant(_FavoriteRestaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RestaurantDetailPage(restaurant: restaurant.toDetailInput()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
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
          'Quán yêu thích',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<List<_FavoriteRestaurant>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          final favorites = snapshot.data ?? const <_FavoriteRestaurant>[];
          if (snapshot.connectionState != ConnectionState.done) {
            return const _FavoriteLoadingState();
          }
          if (favorites.isEmpty) {
            return const _FavoriteEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final restaurant = favorites[index];
              return _FavoriteRestaurantCard(
                restaurant: restaurant,
                onTap: () => _openRestaurant(restaurant),
                onRemove: () => _removeFavorite(restaurant),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteRestaurant {
  final String id;
  final String name;
  final String address;
  final String category;
  final String? imageUrl;
  final double? rating;
  final double distance;
  final int time;
  final bool openNow;
  final double latitude;
  final double longitude;
  final double customerLatitude;
  final double customerLongitude;

  const _FavoriteRestaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.imageUrl,
    required this.rating,
    required this.distance,
    required this.time,
    required this.openNow,
    required this.latitude,
    required this.longitude,
    required this.customerLatitude,
    required this.customerLongitude,
  });

  factory _FavoriteRestaurant.fromJson(Map<String, dynamic> json) {
    return _FavoriteRestaurant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      category: json['category'] as String? ?? 'restaurant',
      imageUrl: json['imageUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      time: (json['time'] as num?)?.toInt() ?? 24,
      openNow: json['openNow'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 10.7843,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 106.5682,
      customerLatitude:
          (json['customerLatitude'] as num?)?.toDouble() ?? 10.7843,
      customerLongitude:
          (json['customerLongitude'] as num?)?.toDouble() ?? 106.5682,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'category': category,
      'imageUrl': imageUrl,
      'rating': rating,
      'distance': distance,
      'time': time,
      'openNow': openNow,
      'latitude': latitude,
      'longitude': longitude,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
    };
  }

  RestaurantDetailInput toDetailInput() {
    return RestaurantDetailInput(
      id: id,
      name: name,
      address: address,
      seed: id,
      category: category,
      rating: rating,
      distance: distance,
      time: time,
      sold: 120,
      imageUrl: imageUrl,
      openNow: openNow,
      latitude: latitude,
      longitude: longitude,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
    );
  }
}

class _FavoriteRestaurantCard extends StatelessWidget {
  final _FavoriteRestaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteRestaurantCard({
    required this.restaurant,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FavoriteImage(path: restaurant.imageUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFFFB300),
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF212121),
                              fontSize: 14,
                              height: 1.18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (restaurant.rating != null)
                          '★ ${restaurant.rating!.toStringAsFixed(1)}',
                        '${restaurant.distance.toStringAsFixed(1)}km',
                        '${restaurant.time} phút',
                      ].join('  |  '),
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (restaurant.address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        restaurant.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: restaurant.openNow
                                ? const Color(0xFFE8F8F5)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            restaurant.openNow ? 'Đang mở cửa' : 'Tạm đóng',
                            style: TextStyle(
                              color: restaurant.openNow
                                  ? AppColors.success
                                  : AppColors.gray500,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: onRemove,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: AppColors.primary,
                              size: 18,
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
      ),
    );
  }
}

class _FavoriteImage extends StatelessWidget {
  final String? path;

  const _FavoriteImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFFEDEDED),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            if (path != null && path!.startsWith('assets/'))
              Image.asset(path!, fit: BoxFit.cover)
            else if (path != null && path!.isNotEmpty)
              Image.network(
                path!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteLoadingState extends StatelessWidget {
  const _FavoriteLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _FavoriteEmptyState extends StatelessWidget {
  const _FavoriteEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.favorite_border_rounded,
              color: Color(0xFFFFB6A8),
              size: 56,
            ),
            SizedBox(height: 12),
            Text(
              'Chưa có quán yêu thích',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Bấm tim ở trang quán để lưu lại những quán bạn hay đặt.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  final VoidCallback onLogin;

  const _ProfileEmptyState({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 128,
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF512F), AppColors.primary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Đăng nhập ShopeeFood',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Xem đơn hàng, địa chỉ và ưu đãi cá nhân',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ShopeeMenuGroup(
            children: [
              _ShopeeMenuRow(
                icon: Icons.receipt_long_outlined,
                iconColor: AppColors.primary,
                label: 'Theo dõi đơn hàng',
                onTap: onLogin,
              ),
              _ShopeeMenuRow(
                icon: Icons.location_on_outlined,
                iconColor: Color(0xFF009688),
                label: 'Địa chỉ giao hàng',
                onTap: onLogin,
              ),
              _ShopeeMenuRow(
                icon: Icons.local_offer_outlined,
                iconColor: Color(0xFFFFA000),
                label: 'Ưu đãi của tôi',
                onTap: onLogin,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'Đăng nhập / Đăng ký',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserProfile {
  final String fullName;
  final String phone;
  final int orderCount;
  final int shopeeXu;
  final int ratingCount;
  final double? ratingAverage;

  const _UserProfile({
    required this.fullName,
    required this.phone,
    required this.orderCount,
    required this.shopeeXu,
    required this.ratingCount,
    required this.ratingAverage,
  });

  factory _UserProfile.fromMap(Map<String, dynamic> data) {
    final rating = data['ratingAverage'];
    return _UserProfile(
      fullName: (data['fullName'] as String?)?.trim().isNotEmpty == true
          ? (data['fullName'] as String).trim()
          : 'Người dùng',
      phone: (data['phone'] as String?)?.trim() ?? '',
      orderCount: (data['orderCount'] as num?)?.toInt() ?? 0,
      shopeeXu: (data['shopeeXu'] as num?)?.toInt() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      ratingAverage: rating is num ? rating.toDouble() : null,
    );
  }

  _UserProfile withOrderMetrics(_ProfileOrderMetrics metrics) {
    return _UserProfile(
      fullName: fullName,
      phone: phone,
      orderCount: metrics.completedOrderCount,
      shopeeXu: metrics.shopeeXu,
      ratingCount: metrics.ratingCount,
      ratingAverage: metrics.ratingAverage,
    );
  }

  String get ratingLabel {
    if (ratingCount <= 0 || ratingAverage == null) {
      return 'Chưa đánh giá';
    }

    return '${ratingAverage!.toStringAsFixed(1)} ★';
  }
}

class _ProfileOrderMetrics {
  final int completedOrderCount;
  final int shopeeXu;
  final int ratingCount;
  final double? ratingAverage;

  const _ProfileOrderMetrics({
    required this.completedOrderCount,
    required this.shopeeXu,
    required this.ratingCount,
    required this.ratingAverage,
  });

  factory _ProfileOrderMetrics.fromEntries(List<OrderEntry> entries) {
    final completed = entries
        .where(
          (entry) =>
              entry.status == OrderStatus.delivered ||
              entry.status == OrderStatus.rated,
        )
        .toList();
    final rated = entries
        .where((entry) => entry.status == OrderStatus.rated)
        .where(
          (entry) => entry.shopRating != null && entry.driverRating != null,
        )
        .toList();
    final ratingAverage = rated.isEmpty
        ? null
        : rated
                  .map((entry) => (entry.shopRating! + entry.driverRating!) / 2)
                  .fold<double>(0, (total, value) => total + value) /
              rated.length;

    return _ProfileOrderMetrics(
      completedOrderCount: completed.length,
      shopeeXu: completed.fold<int>(
        0,
        (total, entry) => total + (entry.order.total / 1000).floor(),
      ),
      ratingCount: rated.length,
      ratingAverage: ratingAverage,
    );
  }
}

class _HeaderStatItem extends StatelessWidget {
  final String title;

  const _HeaderStatItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.gray700),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: AppColors.gray700, size: 22),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.gray700),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.gray500,
          size: 20,
        ),
        onTap: onTap ?? () {},
      ),
    );
  }
}
