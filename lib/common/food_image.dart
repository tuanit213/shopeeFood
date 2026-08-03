import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../restaurant/dish_images.dart';

/// Widget ảnh món ăn dùng chung cho toàn app.
///
/// Quy tắc mới: chỉ hiển thị ảnh thật từ asset hoặc URL đã duyệt. Khi thiếu/hỏng
/// ảnh, hiện placeholder trung tính để lỗi không bị che bởi ảnh render giả.
class FoodImage extends StatelessWidget {
  final String source;
  final String label;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final bool showLabel;
  final Alignment alignment;
  final bool allowRemote;

  const FoodImage({
    super.key,
    required this.source,
    required this.label,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 8,
    this.showLabel = true,
    this.alignment = Alignment.center,
    this.allowRemote = false,
  });

  static final Set<String> _loggedFailures = <String>{};

  static void _logFailure(String source, Object error) {
    if (!kDebugMode || !_loggedFailures.add(source)) {
      return;
    }
    debugPrint('[FoodImage] tải ảnh lỗi: $source ($error)');
  }

  @override
  Widget build(BuildContext context) {
    final value = DishImages.normalize(
      label: label,
      imageUrl: source,
      imageVersion: allowRemote ? DishImages.approvedImageVersion : 0,
    );
    final placeholder = _MissingFoodImage(label: label, showLabel: showLabel);
    Widget child;

    if (DishImages.isLocalDishAsset(value)) {
      child = Image.asset(
        value,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, error, _) {
          _logFailure(value, error);
          return placeholder;
        },
      );
    } else if (DishImages.isApprovedRemote(value)) {
      child = Image.network(
        value,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        loadingBuilder: (context, image, loadingProgress) {
          if (loadingProgress == null) {
            return image;
          }
          return const _LoadingFoodImage();
        },
        errorBuilder: (_, error, _) {
          _logFailure(value, error);
          return placeholder;
        },
      );
    } else {
      child = placeholder;
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFF4F4F4)),
          child: child,
        ),
      ),
    );
  }
}

class _LoadingFoodImage extends StatelessWidget {
  const _LoadingFoodImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFEE4D2D),
        ),
      ),
    );
  }
}

class _MissingFoodImage extends StatelessWidget {
  final String label;
  final bool showLabel;

  const _MissingFoodImage({required this.label, required this.showLabel});

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 88 || constraints.maxHeight < 64;
        return Container(
          color: const Color(0xFFF4F4F4),
          padding: EdgeInsets.all(compact ? 4 : 8),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: compact ? 18 : 26,
                color: const Color(0xFFBDBDBD),
              ),
              if (showLabel && !compact && trimmed.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  trimmed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
