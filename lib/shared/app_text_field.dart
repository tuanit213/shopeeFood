import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    super.key,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
