import 'package:flutter/material.dart';

import '../shared/app_text_field.dart';
import '../shared/auth_scaffold.dart';
import '../shared/info_card.dart';
import '../shared/primary_button.dart';

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đổi mật khẩu',
      subtitle: 'Cập nhật mật khẩu để bảo vệ tài khoản',
      children: [
        const AppTextField(
          label: 'Mật khẩu hiện tại',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const AppTextField(
          label: 'Mật khẩu mới',
          hint: 'Tối thiểu 8 ký tự',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const AppTextField(
          label: 'Nhập lại mật khẩu mới',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const InfoCard(
          title: 'Yêu cầu mật khẩu',
          body:
              '✓ Ít nhất 8 ký tự\n✓ Có chữ hoa, chữ thường\n✓ Có số hoặc ký tự đặc biệt',
        ),
        PrimaryButton(
          label: 'Cập nhật mật khẩu',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
