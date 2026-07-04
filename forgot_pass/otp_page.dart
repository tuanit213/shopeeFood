import 'package:flutter/material.dart';
import '../login/login_page.dart'; // Đảm bảo đường dẫn này trỏ đúng tới file đăng nhập của bạn

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepOrange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Xác nhận OTP',
          style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vui lòng nhập mã xác nhận (OTP) gồm 6 chữ số vừa được gửi đến số điện thoại / email của bạn.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // 6 Ô nhập mã OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _buildOtpBox()),
            ),
            const SizedBox(height: 32),

            // Nút Xác nhận
            ElevatedButton(
              onPressed: () {
                // Lệnh pushAndRemoveUntil giúp xóa sạch lịch sử trang trước đó 
                // và đẩy thẳng người dùng về màn hình Đăng nhập
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false, 
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Xác nhận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm vẽ ô vuông nhập OTP
  Widget _buildOtpBox() {
    return SizedBox(
      width: 45,
      height: 50,
      child: TextField(
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '', 
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
          ),
        ),
      ),
    );
  }
}