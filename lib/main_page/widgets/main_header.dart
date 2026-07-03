import 'package:flutter/material.dart';

import '../../app/app_colors.dart';

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
