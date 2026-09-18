DateTime readDateTime(Object? value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? readNullableDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int readInt(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : fallback;

double readDouble(Object? value, {double fallback = 0}) =>
    value is num ? value.toDouble() : fallback;

String readString(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

Map<String, dynamic> readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> readMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(readMap).toList(growable: false);
}

List<String> readStringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];

T readEnum<T extends Enum>(Object? value, List<T> values, T fallback) {
  return values.cast<T>().firstWhere(
    (item) => item.name == value,
    orElse: () => fallback,
  );
}
