import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const Color _textPrimary = Color(0xFF212121);
  static const Color _textSecondary = Color(0xFF616161);
  static const Color _labelColor = Color(0xFF424242);
  static const Color _hintColor = Color(0xFF9E9E9E);
  static const Color _borderColor = Color(0xFFE0E0E0);
  static const Color _disabledColor = Color(0xFFFFCCBB);
  static const Color _hoverColor = Color(0xFFD94429);
  static const Color _successColor = Color(0xFF43A047);

  final TextEditingController _contactController = TextEditingController();
  final FocusNode _contactFocusNode = FocusNode();

  bool _sentOtp = false;
  bool _buttonHovered = false;
  String _sentContact = '';

  bool get _hasContact => _contactController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _contactController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contactController.dispose();
    _contactFocusNode.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    if (!_hasContact) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _sentContact = _contactController.text.trim();
      _sentOtp = true;
    });
  }

  void _handleResendOtp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi lại mã OTP đến $_sentContact'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _sentOtp ? _buildSuccessState() : _buildForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: 'Quay lại',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          const SizedBox(width: 12),
          const Text(
            'Quên mật khẩu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('forgot-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LockIllustration(),
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: _textSecondary, height: 1.6),
            children: [
              TextSpan(
                text:
                    'Vui lòng nhập số điện thoại hoặc email đã đăng ký. Chúng tôi sẽ gửi mã xác nhận ',
              ),
              TextSpan(
                text: '(OTP)',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: ' để bạn đặt lại mật khẩu.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Số điện thoại hoặc Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _labelColor,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _contactController,
            focusNode: _contactFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSendOtp(),
            decoration: InputDecoration(
              hintText: 'Nhập số điện thoại hoặc email...',
              hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            style: const TextStyle(fontSize: 15, color: _textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ví dụ: 0901 234 567 hoặc email@example.com',
          style: TextStyle(fontSize: 12, color: _hintColor),
        ),
        const SizedBox(height: 28),
        _buildSendButton(),
      ],
    );
  }

  Widget _buildSendButton() {
    final backgroundColor = !_hasContact
        ? _disabledColor
        : _buttonHovered
        ? _hoverColor
        : AppColors.primary;

    return MouseRegion(
      cursor: _hasContact ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _buttonHovered = true),
      onExit: (_) => setState(() => _buttonHovered = false),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _hasContact ? _handleSendOtp : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            disabledBackgroundColor: _disabledColor,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Gửi mã xác nhận',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      key: const ValueKey('forgot-success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        const Icon(Icons.check_circle_rounded, color: _successColor, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Đã gửi mã xác nhận!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Mã OTP đã được gửi đến $_sentContact. Vui lòng kiểm tra và nhập mã trong 5 phút.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: _textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.otp),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Nhập mã OTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _handleResendOtp,
          child: const Text(
            'Gửi lại mã',
            style: TextStyle(
              fontSize: 13,
              color: _hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockIllustration extends StatelessWidget {
  const _LockIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(left: 0, right: 0),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF5F3),
        shape: BoxShape.circle,
      ),
      child: const Text('🔐', style: TextStyle(fontSize: 36)),
    );
  }
}
