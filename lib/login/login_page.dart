import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_colors.dart';
import '../app/app_routes.dart';
import '../app/user_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _textPrimary = Color(0xFF212121);
  static const Color _textSecondary = Color(0xFF757575);
  static const Color _borderDefault = Color(0xFFE0E0E0);
  static const Color _inputFill = Color(0xFFF5F5F5);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _error = Color(0xFFE53935);
  static const Color _primaryHover = Color(0xFFD94429);
  static const Color _primaryActive = Color(0xFFC03D26);
  static const Color _primaryDisabled = Color(0xFFFFCCBB);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscureText = true;
  bool _rememberLogin = false;
  bool _phoneTouched = false;
  bool _passwordTouched = false;
  bool _isLoading = false;
  bool _showApiError = false;
  bool _loginHovered = false;
  bool _loginPressed = false;

  String? _phoneError;
  String? _passwordError;

  bool get _hasInput =>
      _phoneController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  bool get _canSubmit => _hasInput && !_isLoading;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_handleInputChanged);
    _passwordController.addListener(_handleInputChanged);
    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) {
        _validatePhone();
      } else {
        setState(() => _showApiError = false);
      }
    });
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        _validatePassword();
      } else {
        setState(() => _showApiError = false);
      }
    });
    _loadSavedLoginPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    setState(() {
      _showApiError = false;
      if (_phoneTouched) {
        _phoneError = null;
      }
      if (_passwordTouched) {
        _passwordError = null;
      }
    });
  }

  Future<void> _loadSavedLoginPhone() async {
    final savedPhone = await UserSession.getSavedPhone();
    if (!mounted || savedPhone == null) {
      return;
    }

    _phoneController.text = savedPhone;
    _passwordController.clear();
    setState(() {
      _phoneTouched = false;
      _passwordTouched = false;
      _phoneError = null;
      _passwordError = null;
      _showApiError = false;
    });
  }

  bool _validatePhone() {
    final phone = _phoneController.text.trim();
    final hasError = !RegExp(r'^\d{9,10}$').hasMatch(phone);
    setState(() {
      _phoneTouched = true;
      _phoneError = hasError ? 'Số điện thoại không hợp lệ' : null;
    });
    return !hasError;
  }

  bool _validatePassword() {
    final hasError = _passwordController.text.length < 6;
    setState(() {
      _passwordTouched = true;
      _passwordError = hasError ? 'Mật khẩu tối thiểu 6 ký tự' : null;
    });
    return !hasError;
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    final validPhone = _validatePhone();
    final validPassword = _validatePassword();
    if (!validPhone || !validPassword) {
      return;
    }

    setState(() {
      _isLoading = true;
      _showApiError = false;
    });

    try {
      final phone = _phoneController.text.trim();
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (!mounted) {
        return;
      }

      if (users.docs.isEmpty) {
        setState(() {
          _showApiError = true;
          _isLoading = false;
        });
        return;
      }

      await UserSession.saveLogin(
        userId: users.docs.first.id,
        phone: phone,
        remember: _rememberLogin,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } on FirebaseException {
      if (!mounted) {
        return;
      }

      setState(() {
        _showApiError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: _textPrimary),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Quay lại',
              )
            : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 520;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 12 : 24,
                isMobile ? 16 : 24,
                24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isMobile ? 36 : 48),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 24,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 32,
                          vertical: isMobile ? 24 : 40,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 28),
                            if (_showApiError) ...[
                              _buildApiError(),
                              const SizedBox(height: 16),
                            ],
                            _buildPhoneField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            const SizedBox(height: 12),
                            _buildRememberRow(),
                            const SizedBox(height: 24),
                            _buildLoginButton(),
                            const SizedBox(height: 24),
                            _buildDivider(),
                            const SizedBox(height: 16),
                            _buildSocialRow(),
                            const SizedBox(height: 16),
                            _buildLegalText(),
                            const SizedBox(height: 16),
                            _buildRegisterRow(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Đăng nhập',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Chào mừng bạn quay lại',
          style: TextStyle(fontSize: 14, color: _textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildApiError() {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: _error, width: 4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: _error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Số điện thoại hoặc mật khẩu không đúng',
                style: TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    final hasError = _phoneError != null;
    final borderColor = hasError
        ? _error
        : _phoneFocusNode.hasFocus
        ? AppColors.primary
        : _borderDefault;
    final borderWidth = hasError || _phoneFocusNode.hasFocus ? 2.0 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Số điện thoại',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 88,
                height: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: _inputFill,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(7),
                  ),
                  border: Border(right: BorderSide(color: _borderDefault)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🇻🇳', style: TextStyle(fontSize: 15)),
                    Text(
                      '+84',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onSubmitted: (_) {
                    _passwordFocusNode.requestFocus();
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Số điện thoại',
                    hintStyle: TextStyle(color: _hint, fontSize: 15),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: hasError ? _error : _textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildErrorText(_phoneError),
      ],
    );
  }

  Widget _buildPasswordField() {
    final hasError = _passwordError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mật khẩu',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF424242),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.forgotPassword),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscureText,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Nhập mật khẩu',
            hintStyle: const TextStyle(color: _hint, fontSize: 15),
            suffixIcon: IconButton(
              tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              icon: Icon(
                _obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _hint,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? _error : _borderDefault,
                width: hasError ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? _error : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _error, width: 2),
            ),
          ),
          style: TextStyle(
            fontSize: 15,
            color: hasError ? _error : _textPrimary,
          ),
        ),
        _buildErrorText(_passwordError),
      ],
    );
  }

  Widget _buildErrorText(String? message) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: _error),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, color: _error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberRow() {
    return InkWell(
      onTap: () => setState(() => _rememberLogin = !_rememberLogin),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _rememberLogin ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _rememberLogin
                    ? AppColors.primary
                    : const Color(0xFFBDBDBD),
                width: 1.5,
              ),
            ),
            child: _rememberLogin
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          const Text(
            'Ghi nhớ đăng nhập',
            style: TextStyle(fontSize: 13, color: Color(0xFF616161)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    final backgroundColor = !_canSubmit
        ? _primaryDisabled
        : _loginPressed
        ? _primaryActive
        : _loginHovered
        ? _primaryHover
        : AppColors.primary;
    final scale = _loginPressed
        ? 0.998
        : _loginHovered && _canSubmit
        ? 1.005
        : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _loginHovered = true),
      onExit: (_) => setState(() {
        _loginHovered = false;
        _loginPressed = false;
      }),
      child: GestureDetector(
        onTapDown: _canSubmit
            ? (_) => setState(() => _loginPressed = true)
            : null,
        onTapCancel: () => setState(() => _loginPressed = false),
        onTapUp: (_) => setState(() => _loginPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                disabledBackgroundColor: _primaryDisabled,
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
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Đăng nhập',
                        key: ValueKey('label'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(height: 1, color: _borderDefault)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Hoặc đăng nhập bằng',
            style: TextStyle(fontSize: 12, color: _hint),
          ),
        ),
        Expanded(child: Divider(height: 1, color: _borderDefault)),
      ],
    );
  }

  Widget _buildSocialRow() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            iconPath: 'assets/icons/google_logo.jpg',
            text: 'Google',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            iconPath: 'assets/icons/facebook_logo.jpg',
            text: 'Facebook',
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({required String iconPath, required String text}) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: _borderDefault),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF424242),
        ).copyWith(overlayColor: WidgetStateProperty.all(_inputFill)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Image.asset(iconPath, fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424242),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalText() {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(fontSize: 12, color: _hint, height: 1.45),
        children: [
          TextSpan(text: 'Bằng cách đăng nhập, bạn đồng ý với '),
          TextSpan(
            text: 'Điều khoản dịch vụ',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: ' và '),
          TextSpan(
            text: 'Chính sách bảo mật',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: ' của ShopeeFood'),
        ],
      ),
    );
  }

  Widget _buildRegisterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Flexible(
          child: Text(
            'Nếu chưa có tài khoản, ',
            style: TextStyle(fontSize: 14, color: Color(0xFF424242)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text(
            'đăng ký',
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
