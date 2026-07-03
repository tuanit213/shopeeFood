import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';
import '../shared/primary_button.dart';

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
