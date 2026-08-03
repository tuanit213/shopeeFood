import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/profile/avatar_store.dart';

void main() {
  group('AvatarStore.bytesFromDataUri', () {
    test('giải mã đúng bytes từ một data URI base64', () {
      final original = Uint8List.fromList([1, 2, 3, 250, 128, 0]);
      final dataUri = 'data:image/jpeg;base64,${base64Encode(original)}';

      final decoded = AvatarStore.bytesFromDataUri(dataUri);

      expect(decoded, isNotNull);
      expect(decoded, equals(original));
    });

    test('trả về null cho URL http (để tầng trên dùng Image.network)', () {
      expect(AvatarStore.bytesFromDataUri('https://example.com/a.jpg'), isNull);
    });

    test('trả về null cho chuỗi rỗng/null/không phải ảnh', () {
      expect(AvatarStore.bytesFromDataUri(null), isNull);
      expect(AvatarStore.bytesFromDataUri(''), isNull);
      expect(
        AvatarStore.bytesFromDataUri('data:text/plain;base64,QQ=='),
        isNull,
      );
    });

    test('trả về null khi base64 hỏng thay vì ném lỗi', () {
      expect(
        AvatarStore.bytesFromDataUri('data:image/png;base64,@@@not-base64@@@'),
        isNull,
      );
    });
  });
}
