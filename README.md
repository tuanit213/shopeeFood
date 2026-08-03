# ShopeeFood Flutter Demo

Ứng dụng Flutter mô phỏng luồng đặt đồ ăn theo phong cách ShopeeFood: đăng nhập, trang chủ, danh mục món, chi tiết quán, giỏ hàng, thanh toán, đơn hàng, định vị và theo dõi giao hàng.

## Công Nghệ

- Flutter 3.44.0 stable
- Dart SDK `^3.12.0`
- Material 3
- Firebase Core + Cloud Firestore
- SharedPreferences cho session, giỏ hàng và cache cục bộ
- Geoapify / Google Maps API cho định vị, reverse geocoding và dữ liệu quán gần vị trí người dùng
- `flutter_map` + `latlong2` cho bản đồ
- `geolocator` + `geocoding` cho quyền vị trí và địa chỉ
- `google_fonts` với Roboto để đồng bộ typography toàn app

## Chức Năng Chính

- Splash/loading tự chuyển đến đăng nhập hoặc trang chủ theo session.
- Đăng ký, đăng nhập, quên mật khẩu, OTP, đổi mật khẩu.
- Ghi nhớ đăng nhập 7 ngày; đăng xuất giữ lại số điện thoại, bỏ mật khẩu.
- Trang chủ có định vị, banner khuyến mãi, danh mục, món/nhà hàng theo chủ đề.
- Dữ liệu quán gần vị trí người dùng, có fallback offline khi API hoặc Firestore chưa sẵn sàng.
- Ảnh món ăn dùng asset thật trong `assets/images/dishes/`, kiểm soát không trùng ảnh trong menu.
- Chi tiết quán, menu món, thêm giỏ hàng, đặt ngay.
- Giỏ hàng hiển thị ngoài trang chủ và trong tab Đơn hàng.
- Thanh toán, chọn địa chỉ, phương thức thanh toán, voucher demo.
- Theo dõi đơn hàng trên bản đồ, trạng thái giao hàng, đánh giá quán và tài xế.
- Hồ sơ người dùng đọc dữ liệu thật từ Firestore, không dùng số liệu giả.

## Cấu Trúc

```text
lib/
  address/       Dịch vụ địa chỉ, Geoapify helper
  app/           App shell, route, theme, user repository/session
  checkout/      Model và màn thanh toán
  common/        Widget/helper dùng chung, xử lý ảnh món
  forgot_pass/   Quên mật khẩu và OTP
  home/          Trang chủ, banner, danh mục, kết quả ưu đãi, dữ liệu quán
  location/      Lấy vị trí hiện tại và reverse geocoding
  login/         Đăng nhập
  main_page/     3 tab chính: Trang chủ, Đơn hàng, Tôi
  orders/        Giỏ hàng, đơn hàng, theo dõi giao hàng
  profile/       Hồ sơ, avatar, đăng xuất
  register/      Đăng ký
  restaurant/    Chi tiết quán, menu, ảnh món
  splash/        Loading đầu app
```

## Chạy Local

Tạo file API key nếu cần dùng định vị/API ngoài:

```text
secrets/geoapify_api_key.txt
secrets/google_maps_api_key.txt
```

Chạy emulator:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_36.1 -gpu host -no-snapshot-load -no-boot-anim
```

Chạy app kèm API key:

```powershell
cd D:\ProjectCaNhan\ShopeeFood\shopeefood
& .\tools\run_app_with_maps_key.ps1
```

Hoặc chạy mặc định:

```powershell
cd D:\ProjectCaNhan\ShopeeFood\shopeefood
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" pub get
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" run
```

## Kiểm Tra Trước Demo

```powershell
cd D:\ProjectCaNhan\ShopeeFood\shopeefood
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\dart.bat" run tools\audit_images.dart
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" analyze --no-pub
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" test --no-pub
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" build apk --debug --no-pub
```
