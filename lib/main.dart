import 'package:flutter/material.dart';

void main() {
  runApp(const ShopeeFoodApp());
}

class ShopeeFoodApp extends StatelessWidget {
  const ShopeeFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ShopeeFood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashPage(),
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.register: (_) => const RegisterPage(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
        AppRoutes.changePassword: (_) => const ChangePasswordPage(),
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.main: (_) => const MainPage(),
      },
    );
  }
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const changePassword = '/change-password';
  static const profile = '/profile';
  static const main = '/main';
}

class AppColors {
  static const primary = Color(0xFFEE4D2D);
  static const primaryDark = Color(0xFFD73B1D);
  static const background = Color(0xFFF5F5F5);
  static const text = Color(0xFF222222);
  static const muted = Color(0xFF757575);
  static const border = Color(0xFFE8E8E8);
  static const success = Color(0xFF00B14F);
  static const error = Color(0xFFFF3B30);
  static const primaryTint = Color(0xFFFFF0ED);
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6B3C),
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 32,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'SF',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ShopeeFood',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đặt món nhanh, giao tận nơi',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Bắt đầu',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.login),
                ),
                const SizedBox(height: 20),
                const Text('v1.0.0', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Sử dụng email để tiếp tục đặt món',
      children: [
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
        ),
        const AppTextField(
          label: 'Mật khẩu',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.forgotPassword),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        PrimaryButton(
          label: 'Đăng nhập',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.main),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text('Chưa có tài khoản? Đăng ký'),
        ),
      ],
    );
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đăng ký',
      subtitle: 'Tạo tài khoản ShopeeFood mới',
      children: [
        const AppTextField(
          label: 'Họ tên',
          hint: 'Nguyễn Văn A',
          icon: Icons.person_outline,
        ),
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
        ),
        const AppTextField(
          label: 'Số điện thoại',
          hint: '0901 234 567',
          icon: Icons.phone_outlined,
        ),
        const AppTextField(
          label: 'Mật khẩu',
          hint: 'Tối thiểu 8 ký tự',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const AppTextField(
          label: 'Nhập lại mật khẩu',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        PrimaryButton(
          label: 'Tạo tài khoản',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.main),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã có tài khoản? Đăng nhập'),
        ),
      ],
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Quên mật khẩu',
      subtitle: 'Nhập email để nhận mã xác minh',
      children: [
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
        ),
        PrimaryButton(label: 'Gửi mã xác minh', onPressed: () {}),
        const OtpPreviewCard(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại đăng nhập'),
        ),
      ],
    );
  }
}

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đổi mật khẩu',
      subtitle: 'Cập nhật mật khẩu để bảo vệ tài khoản',
      children: [
        const AppTextField(
          label: 'Mật khẩu hiện tại',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const AppTextField(
          label: 'Mật khẩu mới',
          hint: 'Tối thiểu 8 ký tự',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const AppTextField(
          label: 'Nhập lại mật khẩu mới',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const InfoCard(
          title: 'Yêu cầu mật khẩu',
          body:
              '✓ Ít nhất 8 ký tự\n✓ Có chữ hoa, chữ thường\n✓ Có số hoặc ký tự đặc biệt',
        ),
        PrimaryButton(
          label: 'Cập nhật mật khẩu',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

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

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: MainHeader(
              onProfileTap: () =>
                  Navigator.pushNamed(context, AppRoutes.profile),
            ),
          ),
          const SliverToBoxAdapter(child: PromoBanner()),
          const SliverToBoxAdapter(child: CategorySection()),
          const SliverToBoxAdapter(child: RestaurantSection()),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 32),
            ...children.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    super.key,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class OtpPreviewCard extends StatelessWidget {
  const OtpPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mã OTP',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (_) => Container(
                width: 40,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mã có hiệu lực trong 5 phút',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      color: AppColors.primaryTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: AppColors.text, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class MainHeader extends StatelessWidget {
  const MainHeader({required this.onProfileTap, super.key});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B3C), AppColors.primary],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '📍 Quận 1, TP.HCM ▼',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                color: Colors.white,
                onPressed: onProfileTap,
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm món ăn, nhà hàng...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: const Icon(Icons.mic_none),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B3C), AppColors.primary],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Freeship 0đ hôm nay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Đặt món nhanh, ưu đãi nhiều',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Text('🍱', style: TextStyle(fontSize: 54)),
          ],
        ),
      ),
    );
  }
}

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    const categories = [
      ('🍚', 'Cơm'),
      ('🍜', 'Phở'),
      ('🍕', 'Pizza'),
      ('🍔', 'Burger'),
      ('🥤', 'Nước'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh mục',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: categories
                .map(
                  (item) => Container(
                    width: 62,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(item.$1, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text(item.$2),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class RestaurantSection extends StatelessWidget {
  const RestaurantSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Gợi ý cho bạn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12),
          RestaurantCard(name: 'Bún Bò Huế Dì Liên', icon: '🍜', rating: '4.9'),
          RestaurantCard(name: 'KFC Nguyễn Huệ', icon: '🍗', rating: '4.8'),
        ],
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    required this.name,
    required this.icon,
    required this.rating,
    super.key,
  });

  final String name;
  final String icon;
  final String rating;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5DE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '⭐ $rating · 20 phút · 1.2km',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Từ 45.000đ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
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

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.currentIndex, super.key});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        NavigationDestination(icon: Icon(Icons.search), label: 'Khám phá'),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Đơn hàng',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Tin nhắn',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Tôi',
        ),
      ],
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

class CardSurface extends StatelessWidget {
  const CardSurface({
    required this.child,
    this.color = Colors.white,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
