import 'package:flutter/material.dart';

import '../shared/app_text_field.dart';
import '../shared/auth_scaffold.dart';
import '../shared/otp_preview_card.dart';
import '../shared/primary_button.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Quên mật khẩu',
      subtitle: 'Nhập email để nhận mã xác minh',
      children: [
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
        ),
        PrimaryButton(label: 'Gửi mã xác minh', onPressed: () {}),
        const OtpPreviewCard(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại đăng nhập'),
        ),
      ],
    );
  }
}
