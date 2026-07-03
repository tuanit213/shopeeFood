import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../shared/app_text_field.dart';
import '../shared/auth_scaffold.dart';
import '../shared/primary_button.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Sử dụng email để tiếp tục đặt món',
      children: [
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
        ),
        const AppTextField(
          label: 'Mật khẩu',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.forgotPassword),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        PrimaryButton(
          label: 'Đăng nhập',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.main),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text('Chưa có tài khoản? Đăng ký'),
        ),
      ],
    );
  }
}
