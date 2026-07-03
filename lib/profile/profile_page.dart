import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';
import '../shared/app_bottom_navigation.dart';
import '../shared/card_surface.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B3C), AppColors.primaryDark],
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0xFFFFD0B5),
                  child: Icon(Icons.person, size: 42, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Nguyễn Văn A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'you@example.com',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 8),
                      _ProfileBadge(label: 'Thành viên mới'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProfileMenuTile(
                  icon: Icons.person_outline,
                  title: 'Thông tin cá nhân',
                  onTap: () {},
                ),
                ProfileMenuTile(
                  icon: Icons.location_on_outlined,
                  title: 'Địa chỉ giao hàng',
                  onTap: () {},
                ),
                ProfileMenuTile(
                  icon: Icons.payment_outlined,
                  title: 'Thanh toán',
                  onTap: () {},
                ),
                ProfileMenuTile(
                  icon: Icons.notifications_none,
                  title: 'Thông báo',
                  onTap: () {},
                ),
                ProfileMenuTile(
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.changePassword),
                ),
                ProfileMenuTile(
                  icon: Icons.logout,
                  title: 'Đăng xuất',
                  danger: true,
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          icon,
          color: danger ? AppColors.error : AppColors.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: danger ? AppColors.error : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
