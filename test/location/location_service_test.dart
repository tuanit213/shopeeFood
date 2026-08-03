import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/location/location_service.dart';

void main() {
  group('làm sạch địa chỉ reverse geocoding', () {
    test('bỏ đoạn trùng, tập con, token quốc gia và mã bưu chính', () {
      const raw =
          '18Y Đường 1B, ấp 1, Tân Vĩnh Lộc, Hồ Chí Minh, Vietnam, '
          'Đường 1B, Thành phố Hồ Chí Minh';

      final cleaned = LocationService.sanitizeAddressForTesting(raw);

      expect(
        cleaned,
        '18Y Đường 1B, ấp 1, Tân Vĩnh Lộc, Thành phố Hồ Chí Minh',
      );
    });

    test('giữ đoạn đầy đủ hơn khi một đoạn là tập con của đoạn khác', () {
      expect(
        LocationService.sanitizeAddressForTesting(
          'Hồ Chí Minh, Thành phố Hồ Chí Minh',
        ),
        'Thành phố Hồ Chí Minh',
      );
      expect(
        LocationService.sanitizeAddressForTesting('Đường 1B, 18Y Đường 1B'),
        '18Y Đường 1B',
      );
    });

    test('không nhầm 1B thành tập con của 18Y (khớp theo ranh giới từ)', () {
      // "1B" KHÔNG được coi là trùng với "18Y" dù ký tự "1" nằm trong "18Y".
      final cleaned = LocationService.sanitizeAddressForTesting(
        '1B, 18Y Nguyễn Văn A',
      );
      expect(cleaned, '1B, 18Y Nguyễn Văn A');
    });

    test('chuỗi rỗng/null trả về null', () {
      expect(LocationService.sanitizeAddressForTesting(null), isNull);
      expect(LocationService.sanitizeAddressForTesting('   '), isNull);
    });
  });
}
