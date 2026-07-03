import 'package:flutter/material.dart';

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
