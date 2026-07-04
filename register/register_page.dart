import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final bool _obscureText = true;

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      // TODO: Logic gọi API đăng ký tài khoản
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công!')),
      );
      Navigator.pop(context); // Quay lại trang đăng nhập
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đăng ký', style: TextStyle(color: Colors.deepOrange)),
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
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDeco('Họ và tên', Icons.person),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập họ tên' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _buildInputDeco('Số điện thoại', Icons.phone),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập số điện thoại' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDeco('Tuổi', Icons.cake),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập tuổi';
                  int? age = int.tryParse(value);
                  if (age == null) return 'Tuổi không hợp lệ';
                  if (age <= 6) return 'Bạn phải lớn hơn 6 tuổi để đăng ký';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passController,
                obscureText: _obscureText,
                decoration: _buildInputDeco('Mật khẩu', Icons.lock),
                validator: (value) => value!.length < 6 ? 'Mật khẩu phải từ 6 ký tự' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPassController,
                obscureText: _obscureText,
                decoration: _buildInputDeco('Nhập lại mật khẩu', Icons.lock_clock),
                validator: (value) {
                  if (value != _passController.text) return 'Mật khẩu không khớp';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Đăng ký tài khoản', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}