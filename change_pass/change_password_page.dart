import 'package:flutter/material.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  
  // Các biến để ẩn/hiện mật khẩu cho từng ô
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  void _handleChangePassword() {
    if (_formKey.currentState!.validate()) {
      // TODO: Logic gọi API backend để đổi mật khẩu
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công!')),
      );
      Navigator.pop(context); // Đổi xong thì tự động quay lại trang trước đó
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.deepOrange)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.deepOrange),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ô nhập mật khẩu hiện tại
              TextFormField(
                controller: _oldPassController,
                obscureText: _obscureOld,
                decoration: _buildInputDeco(
                  'Mật khẩu hiện tại', 
                  Icons.lock_outline,
                  _obscureOld,
                  () => setState(() => _obscureOld = !_obscureOld),
                ),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 16),

              // Ô nhập mật khẩu mới
              TextFormField(
                controller: _newPassController,
                obscureText: _obscureNew,
                decoration: _buildInputDeco(
                  'Mật khẩu mới', 
                  Icons.lock,
                  _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: (value) => value!.length < 6 ? 'Mật khẩu mới phải từ 6 ký tự' : null,
              ),
              const SizedBox(height: 16),

              // Ô nhập lại mật khẩu mới
              TextFormField(
                controller: _confirmPassController,
                obscureText: _obscureConfirm,
                decoration: _buildInputDeco(
                  'Nhập lại mật khẩu mới', 
                  Icons.lock_clock,
                  _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (value) {
                  if (value != _newPassController.text) return 'Mật khẩu mới không khớp';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Nút Xác nhận
              ElevatedButton(
                onPressed: _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Xác nhận', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hàm tạo giao diện cho ô nhập liệu để code ngắn gọn hơn, tránh lặp code
  InputDecoration _buildInputDeco(String label, IconData icon, bool isObscure, VoidCallback toggleVisibility) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
        onPressed: toggleVisibility,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}