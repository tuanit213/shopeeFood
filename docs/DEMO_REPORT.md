# Báo Cáo Demo ShopeeFood Flutter

## Mục Tiêu

Dự án mô phỏng trải nghiệm đặt đồ ăn trên ShopeeFood: người dùng đăng nhập, lấy vị trí, xem quán gần mình, chọn món, thêm giỏ hàng, thanh toán và theo dõi đơn hàng.

## Phạm Vi Đã Hoàn Thiện

- Luồng tài khoản: đăng ký, đăng nhập, ghi nhớ session 7 ngày, quên mật khẩu, OTP, đổi mật khẩu, đăng xuất.
- Trang chủ: loading vị trí, địa chỉ hiện tại, banner khuyến mãi, danh mục món, danh sách quán/món theo chủ đề.
- Dữ liệu quán: ưu tiên Firestore/API vị trí, có fallback offline để demo không bị trắng màn.
- Ảnh món: dùng asset thật theo slug tên món trong `assets/images/dishes/`; có audit chặn ảnh trùng, ảnh placeholder và nguồn ảnh cũ.
- Giỏ hàng: lưu bằng `OrderState` + `SharedPreferences`, hỗ trợ nhiều quán, tăng/giảm số lượng, hiển thị state ngoài trang chủ và tab Đơn hàng.
- Thanh toán: địa chỉ nhận hàng, voucher, phương thức thanh toán, tạo đơn đang giao.
- Theo dõi đơn: màn bản đồ, trạng thái tài xế, đường đi mô phỏng, thông báo trạng thái, đánh giá sau khi giao.
- Hồ sơ: đọc tên, số điện thoại, thống kê đơn/xu/đánh giá từ dữ liệu người dùng, không dùng dữ liệu giả.

## Công Nghệ Và Lưu Trữ

- UI: Flutter, Material 3, Roboto qua `google_fonts`.
- Backend: Firebase Core, Cloud Firestore.
- Local state: SharedPreferences cho session, cache ảnh cũ, giỏ hàng/đơn hàng.
- Vị trí/bản đồ: geolocator, geocoding, Geoapify, Google Maps API, flutter_map.
- Ảnh món: asset local trong `assets/images/dishes/`, có `ATTRIBUTIONS.md` và `ATTRIBUTIONS.json`.

## Luồng Demo Đề Xuất

1. Mở app, xem splash/loading tự chuyển vào login hoặc trang chủ nếu còn session.
2. Đăng ký tài khoản mới, kiểm tra dữ liệu user trên Firestore.
3. Đăng nhập với ghi nhớ đăng nhập, thoát app và mở lại để chứng minh session.
4. Cho app lấy vị trí, xem địa chỉ hiển thị trên header trang chủ.
5. Bấm banner/danh mục, xem danh sách món phù hợp chủ đề.
6. Vào một quán, xem menu ảnh món thật, thêm nhiều món vào giỏ.
7. Mở giỏ hàng ngoài trang chủ hoặc tab Đơn hàng, chỉnh số lượng.
8. Thanh toán, tạo đơn đang giao.
9. Mở chi tiết đơn, xem bản đồ tracking và trạng thái giao hàng.
10. Hoàn tất đơn, đánh giá quán và tài xế.

## Điểm Cần Nói Khi Báo Cáo

- App đã bỏ menu DEV và seeder UI, không còn thao tác nạp dữ liệu từ giao diện người dùng.
- Ảnh món được kiểm soát bằng slug: tên món quyết định file ảnh, tránh render sai món.
- Dữ liệu critical có fallback: Firestore/API lỗi thì app vẫn chạy được demo offline.
- Giỏ hàng/đơn hàng là state thật trong app, không phải text tĩnh.
- Profile lấy thông tin từ dữ liệu đăng ký và thống kê đơn hàng.

## Lệnh Kiểm Tra

```powershell
cd D:\ProjectCaNhan\ShopeeFood\shopeefood
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\dart.bat" run tools\audit_images.dart
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" analyze --no-pub
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" test --no-pub
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" build apk --debug --no-pub
```

## Rủi Ro Còn Lại

- Theo dõi tài xế là mô phỏng trên route, chưa phải GPS tài xế thật.
- Dữ liệu quán có thể phụ thuộc API key và quyền vị trí trên máy demo.
- Firestore cần rules/config đúng để đăng ký, đăng nhập và profile lưu/đọc ổn định.
