import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'card_surface.dart';

class OtpPreviewCard extends StatelessWidget {
  const OtpPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mã OTP',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (_) => Container(
                width: 40,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mã có hiệu lực trong 5 phút',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
