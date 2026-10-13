# BÁO CÁO ĐỒ ÁN

## Tên Đề Tài

**Xây dựng ứng dụng đặt đồ ăn ShopeeFood bằng Flutter**

Ứng dụng mô phỏng quy trình đặt đồ ăn trên thiết bị di động, bao gồm đăng ký tài khoản, đăng nhập, lấy vị trí người dùng, xem quán gần vị trí hiện tại, xem menu món ăn, thêm món vào giỏ hàng, thanh toán, theo dõi đơn hàng và quản lý hồ sơ cá nhân.

## Mục Lục

1. Tên đề tài
2. Phân công công việc
3. Lời nói đầu
4. Mô tả đề tài
5. Các chức năng chính của ứng dụng
6. Công nghệ sử dụng
7. Kỹ thuật xử lý trong ứng dụng
8. Cấu trúc project
9. Link Figma và hình ảnh thiết kế
10. Hình ảnh app và hướng dẫn sử dụng
11. Hình ảnh project
12. Kiểm thử và kết quả đạt được
13. Hạn chế và hướng phát triển
14. Kết luận

## Phân Công Công Việc

| STT | Thành viên | Công việc thực hiện | Tỉ lệ đóng góp |
| --- | --- | --- | ---: |
| 1 | **Trần Hoàng Anh Tuấn** | Trưởng nhóm; kiến trúc, tích hợp Firebase, quản lý GitHub/Jira, hợp nhất code, kiểm thử tích hợp và chuẩn bị báo cáo. | 30% |
| 2 | **Lê Công Tuấn** | Firebase Functions, Firestore rules/indexes, catalog seed, kiểm thử backend và triển khai staging. | 20% |
| 3 | **Thiều Trung Kiên** | Flutter UI phía khách hàng, catalog, giỏ hàng, checkout và luồng tạo đơn. | 20% |
| 4 | **Nguyễn Trường Khải** | Address V2, bản đồ, GPS/route, theo dõi đơn và tích hợp luồng tài xế. | 15% |
| 5 | **Văn Công Tín** | Kiểm thử, tài liệu SRS/README, bằng chứng demo và triển khai Flutter Web lên VPS. | 15% |
|  | **Tổng** |  | **100%** |

Ghi chú: phạm vi và tỉ lệ phải được đối chiếu lần cuối với commit GitHub và work item Jira trước khi nộp.

## Lời Nói Đầu

Ngày nay, nhu cầu đặt đồ ăn trực tuyến ngày càng phổ biến vì sự tiện lợi, nhanh chóng và phù hợp với nhịp sống hiện đại. Các ứng dụng như ShopeeFood, GrabFood, Baemin đã trở thành công cụ quen thuộc giúp người dùng tìm quán ăn, xem thực đơn, đặt món và theo dõi quá trình giao hàng.

Vì vậy, nhóm chọn đề tài **xây dựng ứng dụng đặt đồ ăn ShopeeFood bằng Flutter** nhằm mô phỏng lại các chức năng cơ bản của một ứng dụng giao đồ ăn thực tế. Thông qua đề tài này, nhóm có thể vận dụng kiến thức về thiết kế giao diện mobile, quản lý trạng thái, kết nối Firebase, xử lý vị trí người dùng, hiển thị bản đồ và tổ chức dữ liệu món ăn.

Đồ án không chỉ tập trung vào giao diện, mà còn xây dựng các luồng thao tác có tính thực tế như đăng nhập, ghi nhớ phiên đăng nhập, lấy địa chỉ hiện tại, thêm món vào giỏ hàng, thanh toán và theo dõi trạng thái đơn hàng.

## Mô Tả Đề Tài

### Mục Tiêu

Mục tiêu của đề tài là xây dựng một ứng dụng Flutter mô phỏng ShopeeFood với trải nghiệm gần giống app thật ở mức demo:

- Người dùng có thể đăng ký, đăng nhập và ghi nhớ phiên đăng nhập.
- Ứng dụng tự lấy vị trí hiện tại và hiển thị địa chỉ người nhận.
- Trang chủ hiển thị banner khuyến mãi, danh mục món ăn và quán gần vị trí người dùng.
- Người dùng có thể xem chi tiết quán, xem menu và thêm món vào giỏ hàng.
- Người dùng có thể thanh toán, tạo đơn hàng và theo dõi trạng thái giao hàng.
- Hồ sơ cá nhân hiển thị thông tin thật theo tài khoản đã đăng ký.

### Đối Tượng Sử Dụng

Ứng dụng hướng đến người dùng có nhu cầu đặt đồ ăn nhanh qua điện thoại. Đối tượng sử dụng gồm sinh viên, nhân viên văn phòng, người sống ở khu vực đô thị và người muốn tìm quán ăn gần vị trí hiện tại.

### Phạm Vi Đề Tài

Project tập trung vào phía người dùng đặt đồ ăn. Các chức năng dành cho chủ quán, shipper thật, thanh toán online thật và hệ thống quản trị chưa được triển khai đầy đủ. Phần theo dõi tài xế hiện là mô phỏng dựa trên route và trạng thái đơn hàng trong app.

## Các Chức Năng Chính Của Ứng Dụng

### 1. Splash/Loading Page

Khi mở app, màn hình loading sẽ hiển thị hiệu ứng khởi động. Sau đó app kiểm tra session đăng nhập:

- Nếu còn session hợp lệ, app chuyển thẳng vào trang chủ.
- Nếu chưa đăng nhập hoặc session hết hạn, app chuyển đến màn hình đăng nhập.

### 2. Đăng Ký Tài Khoản

Màn hình đăng ký cho phép người dùng nhập họ tên, số điện thoại, email, mật khẩu và xác nhận mật khẩu. Dữ liệu tài khoản được lưu lên Cloud Firestore. Mật khẩu được hash trước khi lưu để tránh lưu plain text.

### 3. Đăng Nhập Và Ghi Nhớ Đăng Nhập

Người dùng đăng nhập bằng số điện thoại/mật khẩu. Khi tick vào ô ghi nhớ đăng nhập, app lưu session trong 7 ngày. Nếu người dùng đăng xuất, app giữ lại số điện thoại để lần sau nhập nhanh hơn, nhưng không lưu mật khẩu.

### 4. Quên Mật Khẩu, OTP, Đổi Mật Khẩu

App có các màn hình hỗ trợ quên mật khẩu, nhập OTP và đổi mật khẩu. Đây là luồng giao diện mô phỏng để hoàn thiện trải nghiệm tài khoản.

### 5. Trang Chủ

Trang chủ là màn hình chính của app, gồm:

- Header hiển thị địa chỉ hiện tại.
- Banner carousel khuyến mãi.
- Danh mục món ăn.
- Danh sách quán/món theo chủ đề.
- State giỏ hàng và đơn hàng đang giao.
- Bottom navigation gồm 3 tab: Trang chủ, Đơn hàng, Tôi.

### 6. Định Vị Và Địa Chỉ Người Dùng

Khi vào app, hệ thống yêu cầu quyền vị trí, lấy tọa độ hiện tại bằng `geolocator`, sau đó reverse geocoding bằng Geoapify để hiển thị địa chỉ cụ thể hơn. Người dùng có thể vào màn hình bản đồ để chọn lại địa chỉ bằng ghim.

### 7. Danh Mục, Banner Và Món Khuyến Mãi

Banner và danh mục có thể bấm để mở trang kết quả tương ứng, ví dụ món Hàn, trà sữa, xiên que, deal giảm giá hoặc combo khuyến mãi. Mỗi nhóm có nhiều món đúng chủ đề, ảnh món không bị trùng trong cùng menu/trang.

### 8. Chi Tiết Quán Và Menu Món Ăn

Khi bấm vào quán, app mở màn hình chi tiết quán. Màn hình này hiển thị thông tin quán, địa chỉ, khoảng cách, rating, danh sách món ăn, giá tiền, lượt bán và nút thêm vào giỏ hàng.

### 9. Giỏ Hàng

Giỏ hàng được quản lý bằng `OrderState`. Người dùng có thể thêm nhiều món, thêm món từ nhiều quán khác nhau, tăng/giảm số lượng và mở giỏ hàng từ trang chủ hoặc tab Đơn hàng.

### 10. Thanh Toán

Màn hình thanh toán hiển thị danh sách món, địa chỉ giao hàng, phí giao hàng, voucher, phương thức thanh toán và tổng tiền. Khi đặt đơn, app chuyển trạng thái đơn sang đang giao.

### 11. Theo Dõi Đơn Hàng

Màn hình theo dõi đơn hàng dùng bản đồ để mô phỏng lộ trình tài xế:

- Tài xế di chuyển từ vị trí gần quán đến quán.
- Sau khi lấy món, tài xế chuyển sang lộ trình từ quán đến địa chỉ khách.
- App hiển thị trạng thái đơn và thông báo theo từng giai đoạn.
- Khi đơn hoàn tất, người dùng có thể đánh giá quán và tài xế.

### 12. Hồ Sơ Cá Nhân

Màn hình hồ sơ hiển thị tên, số điện thoại, email, số đơn, Shopee Xu và đánh giá từ dữ liệu tài khoản. Người dùng có thể đổi avatar và đăng xuất.

## Công Nghệ Sử Dụng

### Flutter

Flutter được dùng để xây dựng giao diện đa nền tảng. Project dùng Material 3, widget tree, layout responsive và animation để tạo trải nghiệm mobile.

### Dart

Dart là ngôn ngữ chính của project. Các model, repository, service và logic xử lý trạng thái đều được viết bằng Dart.

### Firebase Core Và Cloud Firestore

Firebase được dùng làm backend cho dữ liệu người dùng và dữ liệu quán/menu khi có kết nối. Cloud Firestore lưu thông tin tài khoản, thống kê người dùng và dữ liệu liên quan.

### SharedPreferences

SharedPreferences dùng để lưu dữ liệu cục bộ như session đăng nhập, số điện thoại đã lưu, giỏ hàng, đơn hàng, cache địa chỉ và avatar local.

### Geoapify Và Google Maps API

Geoapify/Google Maps API dùng cho các chức năng vị trí:

- Reverse geocoding từ tọa độ sang địa chỉ.
- Tìm quán gần vị trí người dùng.
- Hỗ trợ dữ liệu bản đồ và tuyến đường khi demo.

### Flutter Map Và LatLong2

`flutter_map` dùng để hiển thị bản đồ trong app. `latlong2` dùng để xử lý tọa độ, đo khoảng cách, tính tuyến đường và tính hướng di chuyển.

### Geolocator Và Geocoding

`geolocator` dùng để xin quyền vị trí và lấy tọa độ thiết bị. `geocoding` hỗ trợ chuyển đổi tọa độ/địa chỉ khi cần fallback.

### Google Fonts

Project dùng font Roboto qua `google_fonts` để đồng bộ typography toàn app, giúp giao diện gần với phong cách Android/ShopeeFood hơn.

### HTTP

Thư viện `http` dùng để gọi API ngoài như Geoapify và Google Maps.

### Crypto

Thư viện `crypto` dùng để hash mật khẩu trước khi lưu vào Firestore.

### Image Picker

`image_picker` dùng để chọn hoặc chụp avatar trong màn hình hồ sơ.

### State Management

Project không dùng Provider/GetX/BLoC. State chính được quản lý bằng:

- `StatefulWidget` cho state cục bộ của màn hình.
- `ValueNotifier` trong `OrderState` để đồng bộ giỏ hàng/đơn hàng giữa các màn hình.
- `SharedPreferences` để persist dữ liệu sau khi thoát app.

## Kỹ Thuật Xử Lý Trong Ứng Dụng

### Routing

App dùng `MaterialApp.routes` với các route chính:

- `/`: Splash
- `/login`: Login
- `/register`: Register
- `/forgot-password`: Forgot Password
- `/otp`: OTP
- `/change-password`: Change Password
- `/profile`: Profile
- `/main`: Main Page

### Session 7 Ngày

Khi người dùng chọn ghi nhớ đăng nhập, app lưu `userId` và thời gian hết hạn. Khi mở app lại, splash kiểm tra session còn hạn hay không để chuyển thẳng vào trang chủ.

### Xử Lý Ảnh Món Không Trùng

Ảnh món được đặt trong `assets/images/dishes/` theo slug tên món. App ưu tiên ảnh thật trong asset, sau đó mới dùng nguồn khác đã được duyệt. Script audit kiểm tra:

- Món thiếu ảnh.
- Ảnh trùng nội dung.
- Slug trùng gây dùng chung ảnh.
- Nguồn ảnh cũ hoặc placeholder.
- `Image.network` dùng sai chỗ cho ảnh món.

### Fallback Dữ Liệu

Nếu Firestore/API lỗi hoặc chưa có dữ liệu, app vẫn có dữ liệu offline để không bị trắng màn. Đây là điểm quan trọng để demo ổn định.

### Tracking Đơn Hàng

Màn hình tracking mô phỏng tài xế bằng route, progress và animation. Tài xế có vị trí, hướng xoay, trạng thái giao hàng và đường còn lại giảm dần theo tiến độ.

## Cấu Trúc Project

```text
lib/
  address/       Địa chỉ, bản đồ chọn vị trí, Geoapify helper
  app/           Route, theme, màu sắc, user repository, session
  checkout/      Model và màn hình thanh toán
  common/        Widget/helper dùng chung, xử lý ảnh món
  forgot_pass/   Quên mật khẩu, OTP
  home/          Trang chủ, banner, danh mục, dữ liệu quán gần đây
  location/      Lấy vị trí hiện tại và reverse geocoding
  login/         Đăng nhập
  main_page/     Main page với 3 tab chính
  orders/        Giỏ hàng, đơn hàng, tracking
  profile/       Hồ sơ người dùng, avatar, đăng xuất
  register/      Đăng ký
  restaurant/    Chi tiết quán, menu, ảnh món
  splash/        Splash/loading đầu app

assets/
  icons/         Icon app và icon danh mục
  images/        Banner, ảnh nhà hàng, ảnh món ăn

test/
  app/           Test user/session
  common/        Test ảnh và migration
  home/          Test trang chủ, dữ liệu quán
  orders/        Test giỏ hàng, đơn hàng, route tracking
  restaurant/    Test ảnh món và menu
```

## Link Figma Và Hình Ảnh Thiết Kế

**Link Figma:** nhóm bổ sung link Figma vào dòng này khi nộp báo cáo.

Các màn hình thiết kế/chức năng chính cần chụp từ Figma hoặc app:

1. Splash/loading page
2. Login page
3. Register page
4. Forgot password/OTP
5. Home page
6. Restaurant detail/menu page
7. Cart/checkout page
8. Order tracking map page
9. Profile page

## Hình Ảnh App Và Hướng Dẫn Sử Dụng

### Hình Ảnh App Cần Chèn

| Hình | Nội dung ảnh | Ghi chú |
| --- | --- | --- |
| Hình 1 | Splash/loading | App tự kiểm tra session |
| Hình 2 | Login/Register | Luồng tài khoản |
| Hình 3 | Trang chủ | Địa chỉ, banner, danh mục, món/quán |
| Hình 4 | Chi tiết quán | Menu món, giá, thêm giỏ hàng |
| Hình 5 | Giỏ hàng/Đơn hàng | State giỏ hàng và đơn đang giao |
| Hình 6 | Thanh toán | Địa chỉ, voucher, tổng tiền |
| Hình 7 | Theo dõi đơn hàng | Bản đồ, tài xế, route, trạng thái |
| Hình 8 | Profile | Thông tin user, thống kê, đăng xuất |

### Hướng Dẫn Sử Dụng

1. Mở ứng dụng ShopeeFood Flutter Demo.
2. Nếu chưa có tài khoản, chọn đăng ký và nhập họ tên, số điện thoại, email, mật khẩu.
3. Đăng nhập bằng số điện thoại và mật khẩu đã đăng ký.
4. Tick ghi nhớ đăng nhập nếu muốn app tự vào trang chủ trong 7 ngày.
5. Cho phép quyền vị trí để app lấy địa chỉ hiện tại.
6. Tại trang chủ, xem banner khuyến mãi, danh mục món ăn và quán gần vị trí hiện tại.
7. Bấm vào quán hoặc banner/danh mục để xem danh sách món phù hợp.
8. Chọn món, thêm vào giỏ hàng hoặc đặt ngay.
9. Mở giỏ hàng để kiểm tra món, số lượng, tổng tiền.
10. Vào thanh toán, chọn địa chỉ, voucher và phương thức thanh toán.
11. Bấm đặt đơn để tạo đơn đang giao.
12. Mở tab Đơn hàng để xem trạng thái và theo dõi lộ trình trên bản đồ.
13. Khi đơn hoàn tất, đánh giá quán và tài xế.
14. Vào tab Tôi để xem hồ sơ, đổi avatar hoặc đăng xuất.

## Hình Ảnh Project

Phần này dùng để minh họa cấu trúc và cách project được tổ chức. Nên chèn 4-5 hình sau vào báo cáo:

| Hình | Nội dung ảnh project | Ý nghĩa |
| --- | --- | --- |
| Hình project 1 | Cây thư mục `lib/` | Chứng minh project đã tách module theo màn hình/chức năng |
| Hình project 2 | File `pubspec.yaml` | Chứng minh các package/công nghệ sử dụng |
| Hình project 3 | File `lib/app/shopee_food_app.dart` | Chứng minh route và theme toàn app |
| Hình project 4 | File `lib/orders/order_state.dart` | Chứng minh state giỏ hàng/đơn hàng |
| Hình project 5 | File `lib/orders/order_tracking_detail_page.dart` | Chứng minh logic map/tracking đơn hàng |

## Kiểm Thử Và Kết Quả Đạt Được

Trước khi demo, project đã được kiểm tra bằng các lệnh:

```powershell
cd D:\ProjectCaNhan\ShopeeFood\shopeefood
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\dart.bat" run tools\audit_images.dart
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" analyze --no-pub
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" test --no-pub
& "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" build apk --debug --no-pub
```

Kết quả kiểm tra gần nhất:

- `audit_images.dart`: OK, ảnh món không trùng và không thiếu ảnh thật.
- `flutter analyze --no-pub`: không có lỗi.
- `flutter test --no-pub`: 85 test pass.
- `flutter build apk --debug --no-pub`: build thành công file APK debug.

File APK demo:

```text
D:\ProjectCaNhan\ShopeeFood\shopeefood\build\app\outputs\flutter-apk\app-debug.apk
```

## Hạn Chế Và Hướng Phát Triển

### Hạn Chế

- Theo dõi tài xế hiện là mô phỏng, chưa dùng GPS tài xế thật.
- Thanh toán mới ở mức demo, chưa tích hợp cổng thanh toán thật.
- Chưa có app riêng cho tài xế và chủ quán.
- Một số dữ liệu quán/món vẫn dùng dữ liệu demo hoặc fallback offline.
- Chưa có chat giữa người dùng và tài xế/chủ quán.
- Chưa có hệ thống quản trị để duyệt quán, món và đơn hàng.

### Hướng Phát Triển

- Xây dựng app/role riêng cho tài xế.
- Xây dựng dashboard quản trị cho chủ quán.
- Tích hợp thanh toán online thật.
- Lưu đơn hàng thật lên Firestore theo từng user.
- Tích hợp notification khi đơn thay đổi trạng thái.
- Bổ sung chat giữa khách hàng và tài xế.
- Tối ưu route tracking bằng dữ liệu chỉ đường thật.
- Hoàn thiện đánh giá quán/tài xế và lịch sử đơn hàng.
- Viết thêm widget test cho các màn hình quan trọng.

## Kết Luận

Đồ án đã xây dựng được một ứng dụng đặt đồ ăn bằng Flutter với các chức năng quan trọng như tài khoản, định vị, trang chủ, menu món, giỏ hàng, thanh toán, đơn hàng, tracking và hồ sơ cá nhân. Project có cấu trúc thư mục rõ ràng, sử dụng Firebase/Firestore cho dữ liệu người dùng, SharedPreferences cho dữ liệu cục bộ, Geoapify/Google Maps cho vị trí và `flutter_map` cho bản đồ.

Thông qua đề tài này, nhóm đã hiểu rõ hơn về quá trình xây dựng một ứng dụng mobile thực tế: từ thiết kế giao diện, tổ chức code, quản lý trạng thái, xử lý API, lưu dữ liệu, kiểm thử đến chuẩn bị bản demo. Tuy vẫn còn một số hạn chế so với app ShopeeFood thật, project đã đáp ứng được mục tiêu mô phỏng trải nghiệm đặt đồ ăn cơ bản và có thể tiếp tục mở rộng trong tương lai.
