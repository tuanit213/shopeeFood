import 'package:flutter/material.dart';

class CardSurface extends StatelessWidget {
  const CardSurface({
    required this.child,
    this.color = Colors.white,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
