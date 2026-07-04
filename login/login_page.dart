import 'package:flutter/material.dart';
import '../register/register_page.dart';
import '../forgot_pass/forgot_password_page.dart'; // Chuyển hướng sang trang Quên mật khẩu

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề ShopeeFood
            const Text(
              'ShopeeFood',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập để đặt món ngon mỗi ngày',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Các nút Social Login
            _buildSocialButton(Colors.blue, 'Tiếp tục với Google'),
            const SizedBox(height: 12),
            _buildSocialButton(Colors.blue[700]!, 'Tiếp tục với Facebook'),
            const SizedBox(height: 12),
            _buildSocialButton(Colors.black, 'Tiếp tục với Apple'),
            const SizedBox(height: 32),

            // Nhãn Số điện thoại
            const Text('Số điện thoại', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            
            // Ô nhập Số điện thoại có +84
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepOrange, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('+84', style: TextStyle(fontSize: 16, color: Colors.black87)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0901 234 567',
                      ),
                      style: const TextStyle(fontSize: 16, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nhãn Mật khẩu
            const Text('Mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            
            // Ô nhập Mật khẩu
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu',
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.deepOrange, width: 1.5),
                ),
              ),
            ),

            // Nút Quên mật khẩu
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Chuyển hướng sang trang Quên mật khẩu
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                  );
                },
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Nút Đăng nhập
            ElevatedButton(
              onPressed: () {
                // Tạm thời chưa code logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 16),

            // Dòng chữ Điều khoản
            const Text(
              'Bằng cách đăng nhập, bạn đồng ý với Điều khoản dịch vụ và Chính sách bảo mật của ShopeeFood',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Chuyển sang Đăng ký
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Nếu chưa có tài khoản, ',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                GestureDetector(
                  onTap: () {
                    // Chuyển hướng sang trang đăng ký
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterPage()),
                    );
                  },
                  child: const Text(
                    'đăng kí',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.deepOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Hàm tạo giao diện nút Social (Google, FB, Apple)
  Widget _buildSocialButton(Color iconColor, String text) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 24),
          Text(text, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}