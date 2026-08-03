/// Slug hoá tên món — CỐ TÌNH viết bằng Dart thuần, không import Flutter.
///
/// Nhờ vậy script kiểm tra ảnh (`dart run tools/audit_images.dart`) dùng chung
/// đúng một hàm slug với app, không sợ hai bên lệch nhau.
class DishSlug {
  const DishSlug._();

  /// "Bún bò Huế" -> "bun bo hue".
  static String ascii(String value) => removeDiacritics(value.toLowerCase());

  /// "Bún bò Huế" -> "bun-bo-hue".
  static String of(String dishName) {
    final normalized = removeDiacritics(dishName.toLowerCase());
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Số ổn định cho một tên món — còn giữ cho API cũ.
  static int seedOf(String value) {
    var hash = 0x811C9DC5;
    for (final unit in of(value).codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Nhóm ký tự có dấu theo từng chữ cái không dấu.
  ///
  /// Cố tình KHÔNG dùng cách ánh xạ hai chuỗi song song theo chỉ số: kiểu đó
  /// chỉ cần lệch một ký tự là sai toàn bộ (đã từng làm "bún" thành "bon").
  static const diacriticGroups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static String removeDiacritics(String value) {
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      var replaced = char;
      for (final entry in diacriticGroups.entries) {
        if (entry.value.contains(char)) {
          replaced = entry.key;
          break;
        }
      }
      buffer.write(replaced);
    }
    return buffer.toString();
  }
}
