import 'package:flutter/material.dart';
import '../app/app_colors.dart';
import '../change_pass/change_password_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SingleChildScrollView(
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
                            const Text(
                              'Nguyễn Văn Tuấn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '090*****67',
                              style: TextStyle(
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
                                    'Thành viên Vàng',
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _HeaderStatItem(title: '12 Đơn đã đặt'),
                      Text('|', style: TextStyle(color: Colors.white30)),
                      _HeaderStatItem(title: '2.450 ShopeeXu'),
                      Text('|', style: TextStyle(color: Colors.white30)),
                      _HeaderStatItem(title: '4.8 ★'),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
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
              items: [
                const _MenuItem(
                  icon: Icons.help_outline,
                  label: 'Trung tâm hỗ trợ',
                ),
                const _MenuItem(
                  icon: Icons.phone_in_talk_outlined,
                  label: 'Liên hệ chúng tôi',
                ),
                const _MenuItem(
                  icon: Icons.star_border,
                  label: 'Đánh giá ứng dụng',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {},
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
      ),
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

class _HeaderStatItem extends StatelessWidget {
  final String title;
  const _HeaderStatItem({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
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
    return ListTile(
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
    );
  }
}
