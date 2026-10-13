# Kịch bản báo cáo ngày 2026-10-13

## Bản nói ngắn 3-5 phút

Nhóm em xây dựng hệ thống đặt và giao đồ ăn gồm ứng dụng khách hàng Flutter, ứng dụng tài xế Flutter và backend Firebase. Phạm vi hiện tại tập trung vào định danh người dùng, catalog nhà hàng và món ăn, giỏ hàng, địa chỉ giao hàng, tạo đơn có kiểm tra phía server, theo dõi giao hàng và nền tảng cho tài xế.

Về backlog và Jira, nhóm đã chia theo epic và ba sprint cho nền tảng, catalog/checkout/createOrder, sau đó là Address V2, tracking và release. Tuy nhiên trạng thái Jira hiện chưa đồng bộ hoàn toàn với code: Sprint 0 đã quá hạn nhưng chưa có item Done và còn nhiều task chưa gán người. Nhóm xác định đây là việc P0 và sẽ chỉ cập nhật Done khi có commit cùng bằng chứng kiểm thử.

Về GitHub, source khách hàng ở repository `tuanit213/shopeeFood`. Nhánh chính trên remote đang ở commit `4abd47e`; phần backend server-order đã commit local ở `b5d8f5b`, còn Phase 2.5 catalog đang được kiểm tra trước khi commit và push. App tài xế nằm ở repository riêng và nhánh demo `codex/demo-delivery-mvp` đã có trên remote ở commit `e720fba`.

Về SRS, nhóm đã mô tả actor Customer, Driver, Administrator và Firebase backend; yêu cầu chính là auth, catalog, cart, Address V2, tạo đơn server-side, chống tạo đơn trùng, lưu snapshot bất biến và tracking. Trust boundary quan trọng là client không được tự ghi đơn hoặc gửi giá tiền làm nguồn sự thật; callable `createOrder` đọc catalog server, tính lại giá và ghi transaction.

Về frontend, `flutter analyze` đã PASS và 98 test đã PASS. Bản Flutter Web release cũng build thành công. Về backend, TypeScript build PASS, ba unit test PASS và bài test tích hợp Auth + Firestore + Functions emulator PASS cho idempotency, snapshot, pricing và event `ORDER_PLACED`.

Về deploy, nhóm đã chuẩn bị Docker/Nginx để đưa Flutter Web lên VPS. Backend đang dùng Firebase Functions nên triển khai backend qua Firebase CLI, không chạy chung trong Nginx. Hiện chưa thể chứng minh deploy production vì chưa có VPS URL/credential, chưa có Firebase staging riêng và catalog thật vẫn rỗng. Vì vậy trạng thái đúng là local/emulator ready, staging/VPS chưa hoàn tất.

## Nếu trợ giáo hỏi từng mục

### Backlog

Mở Jira `DeliveryApp -> Backlog`, chỉ ba sprint và các epic. Nói rõ bảng đang cần reconcile, không nói tất cả đã hoàn thành.

### GitHub

Mở hai repository và chỉ commit cụ thể. Giải thích code chưa push không được tính là bằng chứng GitHub.

### SRS

Mở `docs/SRS.md`, tập trung vào FR-05, FR-06, NFR-01 và phần known gaps.

### Backend

Mở `functions/src/orders/create_order.ts`, `functions/src/orders/pricing_policy.ts` và test emulator. Giải thích client chỉ gửi ID/số lượng; server quyết định giá và snapshot.

### Frontend

Demo: đăng nhập -> catalog -> món/tùy chọn -> giỏ -> địa chỉ -> checkout -> tracking. Sau đó cho xem kết quả analyze/test.

### VPS

Mở `deploy/web/README.md` và URL thật nếu đã deploy. Nếu chưa có URL, nói đúng là cấu hình đã sẵn sàng nhưng remote deployment chưa được xác minh.

## Không được nói quá

- Không nói catalog staging đã seed khi số record vẫn bằng 0.
- Không nói Firebase staging đã deploy khi chưa có project staging riêng.
- Không nói GPS/driver production đã tích hợp end-to-end nếu mới chạy demo/local.
- Không nói Jira hoàn tất khi board còn 0 Done.
- Không nói VPS đã xong nếu chưa có URL public và health check.
