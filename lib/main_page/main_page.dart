import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../home/home_page.dart';
import '../orders/orders_page.dart';
import '../profile/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navWidth = screenWidth <= 600
        ? screenWidth
        : math.min(screenWidth, 390.0);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(onProfileTap: () => _onItemTapped(2)),
          OrdersPage(onBack: () => _onItemTapped(0)),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 58 + bottomInset,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: navWidth,
            height: 58,
            child: MediaQuery.withNoTextScaling(
              child: Row(
                children: [
                  _BottomNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Trang chủ',
                    selected: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _BottomNavItem(
                    icon: Icons.assignment_outlined,
                    activeIcon: Icons.assignment,
                    label: 'Đơn hàng',
                    selected: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  _BottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Tôi',
                    selected: _selectedIndex == 2,
                    onTap: () => _onItemTapped(2),
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

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.gray500;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
