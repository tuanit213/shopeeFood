import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../change_pass/change_password_page.dart';
import '../forgot_pass/forgot_password_page.dart';
import '../forgot_pass/otp_page.dart';
import '../login/login_page.dart';
import '../main_page/main_page.dart';
import '../profile/profile_page.dart';
import '../register/register_page.dart';
import '../splash/splash_page.dart';
import 'app_colors.dart';
import 'app_routes.dart';

class ShopeeFoodApp extends StatelessWidget {
  const ShopeeFoodApp({super.key});

  static const _knownRoutes = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.otp,
    AppRoutes.changePassword,
    AppRoutes.profile,
    AppRoutes.main,
  };

  String get _initialRoute {
    final uri = Uri.base;
    final hashRoute = uri.fragment.startsWith('/') ? uri.fragment : null;
    final pathRoute = uri.path == '/' ? null : uri.path;
    final route = hashRoute ?? pathRoute ?? AppRoutes.splash;

    return _knownRoutes.contains(route) ? route : AppRoutes.splash;
  }

  @override
  Widget build(BuildContext context) {
    final robotoFamily = GoogleFonts.roboto().fontFamily;
    final robotoTextTheme = GoogleFonts.robotoTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ShopeeFood',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.08),
        ),
        child: child!,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.gray50,
        useMaterial3: true,
        // ShopeeFood trên Android dùng cảm giác system sans gọn, chắc.
        // Roboto giữ toàn app đồng bộ và gần app gốc hơn Nunito Sans.
        fontFamily: robotoFamily,
        textTheme: robotoTextTheme,
        primaryTextTheme: robotoTextTheme,
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.roboto(
            color: const Color(0xFF212121),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: GoogleFonts.roboto(color: const Color(0xFF9E9E9E)),
        ),
      ),
      initialRoute: _initialRoute,
      routes: {
        AppRoutes.splash: (_) => const SplashPage(),
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.register: (_) => const RegisterPage(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
        AppRoutes.otp: (_) => const OtpPage(),
        AppRoutes.changePassword: (_) => const ChangePasswordPage(),
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.main: (_) => const MainPage(),
      },
    );
  }
}
