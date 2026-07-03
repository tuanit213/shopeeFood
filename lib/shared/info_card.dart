import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'card_surface.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      color: AppColors.primaryTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: AppColors.text, height: 1.5),
          ),
        ],
      ),
    );
  }
}
