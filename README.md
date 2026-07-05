# ShopeeFood

Ứng dụng Flutter mô phỏng ShopeeFood, dùng để nhóm phát triển các màn hình đặt món, tài khoản, hồ sơ và trang chính.

## Công nghệ sử dụng

- Flutter 3.x
- Dart SDK `^3.12.0`
- Material 3
- Flutter Lints
- Git/GitHub
- Figma cho thiết kế giao diện

## Cấu trúc hiện tại

```text
lib/
  app/           Cấu hình app, route, theme token
  splash/        Welcome/Splash page
  login/         Login page
  register/      Register page
  forgot_pass/   Forgot password page
  change_pass/   Change password page
  profile/       Profile page
  main_page/     Main page
```

## Màn hình

- Welcome/Splash
- Login
- Register
- Forgot Password
- Change Password
- Profile
- Main Page

## Hướng phát triển

- Hoàn thiện UI từng màn hình theo Figma.
- Tách component dùng chung như button, input, card, app bar.
- Thêm điều hướng hoàn chỉnh giữa các màn hình.
- Xây dựng form validation cho login, register, forgot password, change password.
- Tích hợp state management khi bắt đầu có dữ liệu thật.
- Kết nối API cho đăng nhập, đăng ký, hồ sơ người dùng, danh sách món ăn và đơn hàng.
- Thêm quản lý giỏ hàng, đặt món, theo dõi trạng thái đơn hàng.
- Viết unit test và widget test cho các luồng chính.
- Chuẩn hóa assets, icon, màu sắc, typography theo design system.

## Chạy project

```bash
flutter pub get
flutter run
```
