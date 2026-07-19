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
    final baseTextTheme = ThemeData.light(useMaterial3: true).textTheme;
    final robotoTextTheme = GoogleFonts.robotoTextTheme(baseTextTheme)
        .copyWith(
          displayLarge: GoogleFonts.roboto(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.06,
          ),
          displayMedium: GoogleFonts.roboto(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
          displaySmall: GoogleFonts.roboto(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
          headlineLarge: GoogleFonts.roboto(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
          headlineMedium: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.18,
          ),
          headlineSmall: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.22,
          ),
          titleLarge: GoogleFonts.roboto(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.22,
          ),
          titleMedium: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleSmall: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          bodyLarge: GoogleFonts.roboto(fontSize: 13, height: 1.33),
          bodyMedium: GoogleFonts.roboto(fontSize: 12, height: 1.32),
          bodySmall: GoogleFonts.roboto(fontSize: 11, height: 1.32),
          labelLarge: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          labelMedium: GoogleFonts.roboto(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          labelSmall: GoogleFonts.roboto(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.18,
          ),
        )
        .apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ShopeeFood',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.0),
        ),
        child: child!,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          error: const Color(0xFFE53935),
        ),
        scaffoldBackgroundColor: AppColors.gray50,
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        splashFactory: InkRipple.splashFactory,
        // ShopeeFood trên Android dùng cảm giác system sans gọn, chắc.
        // Roboto giữ toàn app đồng bộ và gần app gốc hơn Nunito Sans.
        fontFamily: robotoFamily,
        textTheme: robotoTextTheme,
        primaryTextTheme: robotoTextTheme,
        appBarTheme: AppBarTheme(
          toolbarHeight: 44,
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.white,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          iconTheme: const IconThemeData(color: AppColors.primary, size: 20),
          titleTextStyle: GoogleFonts.roboto(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          hintStyle: GoogleFonts.roboto(
            color: const Color(0xFF9E9E9E),
            fontSize: 13,
          ),
          labelStyle: GoogleFonts.roboto(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE53935)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.4),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 0.7,
          space: 1,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          modalBackgroundColor: Colors.white,
          modalBarrierColor: Color(0x99000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.gray500,
          backgroundColor: Colors.white,
          elevation: 8,
          selectedIconTheme: const IconThemeData(size: 20),
          unselectedIconTheme: const IconThemeData(size: 20),
          selectedLabelStyle: GoogleFonts.roboto(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
          unselectedLabelStyle: GoogleFonts.roboto(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            textStyle: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            textStyle: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
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
