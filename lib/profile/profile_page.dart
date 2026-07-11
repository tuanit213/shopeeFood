import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';
import '../app/user_session.dart';

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
      body: _ProfileContent(profile: profile),
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

class _ProfileEmptyState extends StatelessWidget {
  final VoidCallback onLogin;

  const _ProfileEmptyState({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.gray500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa có dữ liệu tài khoản',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
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

  String get ratingLabel {
    if (ratingCount <= 0 || ratingAverage == null) {
      return 'Chưa đánh giá';
    }

    return '${ratingAverage!.toStringAsFixed(1)} ★';
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
