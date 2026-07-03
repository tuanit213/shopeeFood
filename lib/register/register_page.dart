import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../shared/app_text_field.dart';
import '../shared/auth_scaffold.dart';
import '../shared/primary_button.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đăng ký',
      subtitle: 'Tạo tài khoản ShopeeFood mới',
      children: [
        const AppTextField(
          label: 'Họ tên',
          hint: 'Nguyễn Văn A',
          icon: Icons.person_outline,
        ),
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
        ),
        const AppTextField(
          label: 'Số điện thoại',
          hint: '0901 234 567',
          icon: Icons.phone_outlined,
        ),
        const AppTextField(
          label: 'Mật khẩu',
          hint: 'Tối thiểu 8 ký tự',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const AppTextField(
          label: 'Nhập lại mật khẩu',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        PrimaryButton(
          label: 'Tạo tài khoản',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.main),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã có tài khoản? Đăng nhập'),
        ),
      ],
    );
  }
}
