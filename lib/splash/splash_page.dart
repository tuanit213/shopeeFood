import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.65,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _navigationTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryLight,
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ShopeeFood',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: const _LoadingMark(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Đang chuẩn bị món ngon',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Vui lòng chờ trong giây lát',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFE5DE),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'ShopeeFood',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingMark extends StatelessWidget {
  const _LoadingMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const Icon(Icons.delivery_dining, color: AppColors.primary, size: 58),
          const Positioned(
            right: 26,
            top: 28,
            child: Icon(Icons.restaurant, color: AppColors.success, size: 22),
          ),
        ],
      ),
    );
  }
}
