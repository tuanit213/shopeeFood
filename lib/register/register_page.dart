import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';
import '../app/user_session.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color _textPrimary = Color(0xFF212121);
  static const Color _labelColor = Color(0xFF9E9E9E);
  static const Color _borderColor = Color(0xFFE0E0E0);
  static const Color _disabledColor = Color(0xFFFFCCBB);
  static const Color _hoverColor = Color(0xFFD94429);
  static const Color _errorColor = Color(0xFFE53935);
  static const Color _successColor = Color(0xFF43A047);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  bool _buttonHovered = false;
  bool _confirmTouched = false;

  bool get _confirmHasValue => _confirmPasswordController.text.isNotEmpty;

  bool get _confirmMatches =>
      _confirmHasValue &&
      _confirmPasswordController.text == _passwordController.text;

  bool get _confirmHasError =>
      _confirmTouched && _confirmHasValue && !_confirmMatches;

  bool get _canSubmit =>
      !_isLoading &&
      _acceptedTerms &&
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmMatches;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _nameController,
      _phoneController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      controller.addListener(() => setState(() {}));
    }

    for (final focusNode in [
      _nameFocus,
      _phoneFocus,
      _emailFocus,
      _passwordFocus,
      _confirmPasswordFocus,
    ]) {
      focusNode.addListener(() => setState(() {}));
    }

    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus) {
        setState(() => _confirmTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_canSubmit) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
      final userRef = await FirebaseFirestore.instance.collection('users').add({
        'fullName': _nameController.text.trim(),
        'phone': phone,
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'acceptedTerms': _acceptedTerms,
        'provider': 'email_password_form',
        'orderCount': 0,
        'shopeeXu': 0,
        'ratingCount': 0,
        'ratingAverage': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await UserSession.saveUserId(userRef.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể lưu tài khoản: ${error.message ?? error.code}',
          ),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  const SizedBox(height: 24),
                  _FloatingTextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    label: 'Họ và tên',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _phoneFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _FloatingTextField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    label: 'Số điện thoại',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    ],
                    onSubmitted: (_) => _emailFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _FloatingTextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _FloatingTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    label: 'Mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Hiện mật khẩu'
                          : 'Ẩn mật khẩu',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _labelColor,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                  ),
                  _PasswordStrengthMeter(password: _passwordController.text),
                  const SizedBox(height: 16),
                  _FloatingTextField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    label: 'Nhập lại mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPassword,
                    borderColor: _confirmHasError
                        ? _errorColor
                        : _confirmMatches
                        ? _successColor
                        : null,
                    suffixIcon: _confirmMatches
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: _successColor,
                          )
                        : IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _labelColor,
                            ),
                          ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleRegister(),
                  ),
                  if (_confirmHasError) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Mật khẩu không khớp',
                      style: TextStyle(fontSize: 12, color: _errorColor),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _buildTermsCheckbox(),
                  const SizedBox(height: 24),
                  _buildRegisterButton(),
                  const SizedBox(height: 18),
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
          'Đăng ký',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _acceptedTerms ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _acceptedTerms
                    ? AppColors.primary
                    : const Color(0xFFBDBDBD),
                width: 1.5,
              ),
            ),
            child: _acceptedTerms
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: Color(0xFF616161),
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: 'Tôi đồng ý với '),
                  TextSpan(
                    text: 'Điều khoản dịch vụ',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(text: ' và '),
                  TextSpan(
                    text: 'Chính sách bảo mật',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    final backgroundColor = !_canSubmit
        ? _disabledColor
        : _buttonHovered
        ? _hoverColor
        : AppColors.primary;

    return MouseRegion(
      cursor: _canSubmit ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _buttonHovered = true),
      onExit: (_) => setState(() => _buttonHovered = false),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _canSubmit ? _handleRegister : null,
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _isLoading
                ? const Row(
                    key: ValueKey('loading'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Đang tạo tài khoản...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Đăng ký tài khoản',
                    key: ValueKey('label'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Đã có tài khoản? ',
          style: TextStyle(fontSize: 14, color: Color(0xFF424242)),
        ),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: const Text(
            'Đăng nhập',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final Color? borderColor;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const _FloatingTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.borderColor,
    this.onSubmitted,
    this.inputFormatters,
  });

  bool get _isFloating => focusNode.hasFocus || controller.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        borderColor ??
        (focusNode.hasFocus
            ? AppColors.primary
            : _RegisterPageState._borderColor);
    final borderWidth = focusNode.hasFocus || borderColor != null ? 2.0 : 1.5;
    final labelColor = _isFloating
        ? AppColors.primary
        : _RegisterPageState._labelColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveBorder, width: borderWidth),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Icon(icon, color: _RegisterPageState._labelColor, size: 22),
          ),
          Positioned(
            left: 48,
            right: suffixIcon == null ? 16 : 50,
            top: _isFloating ? 6 : 0,
            bottom: _isFloating ? null : 0,
            child: IgnorePointer(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: labelColor,
                  fontSize: _isFloating ? 11 : 15,
                  fontWeight: _isFloating ? FontWeight.w500 : FontWeight.w400,
                ),
                child: Align(
                  alignment: _isFloating
                      ? Alignment.topLeft
                      : Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            left: 44,
            right: suffixIcon == null ? 8 : 42,
            top: _isFloating ? 12 : 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              onSubmitted: onSubmitted,
              inputFormatters: inputFormatters,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.only(top: 17, left: 4, right: 4),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: _RegisterPageState._textPrimary,
              ),
            ),
          ),
          if (suffixIcon != null)
            Positioned(right: 0, top: 0, bottom: 0, child: suffixIcon!),
        ],
      ),
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const _PasswordStrengthMeter({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final strength = _PasswordStrength.from(password);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(4, (index) {
                final active = index < strength.level;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: active ? strength.color : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            strength.label,
            style: TextStyle(
              color: strength.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrength {
  final int level;
  final String label;
  final Color color;

  const _PasswordStrength({
    required this.level,
    required this.label,
    required this.color,
  });

  factory _PasswordStrength.from(String value) {
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
    final mixed = hasLetter && hasDigit && hasSpecial;

    if (value.length >= 10 && mixed) {
      return const _PasswordStrength(
        level: 4,
        label: 'Rất mạnh',
        color: Color(0xFF2E7D32),
      );
    }

    if (value.length >= 8 && hasSpecial) {
      return const _PasswordStrength(
        level: 3,
        label: 'Mạnh',
        color: Color(0xFF43A047),
      );
    }

    if (value.length >= 6 && value.length <= 8 && (hasLetter || hasDigit)) {
      return const _PasswordStrength(
        level: 2,
        label: 'Trung bình',
        color: Color(0xFFFFB300),
      );
    }

    return const _PasswordStrength(
      level: 1,
      label: 'Yếu',
      color: Color(0xFFE53935),
    );
  }
}
