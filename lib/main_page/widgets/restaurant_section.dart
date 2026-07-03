import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../shared/card_surface.dart';

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
