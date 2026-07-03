import 'package:flutter/material.dart';

import '../change_pass/change_password_page.dart';
import '../forgot_pass/forgot_password_page.dart';
import '../login/login_page.dart';
import '../main_page/main_page.dart';
import '../profile/profile_page.dart';
import '../register/register_page.dart';
import '../splash/splash_page.dart';
import 'app_colors.dart';
import 'app_routes.dart';

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
