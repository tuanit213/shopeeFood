import 'package:flutter/material.dart';

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
