# Ảnh thật của từng món

Thả ảnh vào đây là app tự dùng, **không cần sửa code**.

## Quy tắc đặt tên

Tên file = slug của tên món: bỏ dấu, viết thường, thay khoảng trắng bằng `-`.

| Tên món trong app        | Tên file                  |
| ------------------------ | ------------------------- |
| Bún bò Huế               | `bun-bo-hue.jpg`          |
| Cơm tấm sườn bì chả      | `com-tam-suon-bi-cha.jpg` |
| Trà sữa trân châu đường đen | `tra-sua-tran-chau-duong-den.jpg` |

Đuôi file chấp nhận: `.jpg`, `.jpeg`, `.png`, `.webp` (ưu tiên theo thứ tự đó).

## Món chưa có ảnh thì sao?

App vẽ sẵn một **thẻ ảnh riêng** cho từng tên món (gradient + hoạ tiết theo
nhóm món + tên món). Mỗi tên món ra một hình khác nhau, luôn có sẵn khi
offline, nên không bao giờ còn ô xám "thiếu ảnh" và không có hai món trùng
hình. Xem `lib/common/food_image.dart`.

## Kiểm tra nhanh

```powershell
dart run tools/audit_images.dart
```

Lệnh này liệt kê món nào đã có ảnh thật, món nào đang dùng thẻ sinh sẵn, và
cảnh báo nếu có hai file ảnh trùng nội dung.
