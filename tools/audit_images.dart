// Kiểm tra toàn bộ ảnh món của app.
//
// Chạy:
//   dart run tools/audit_images.dart
//
// Script này KHÔNG cần Flutter engine (Dart thuần) nên chạy nhanh và có thể
// đưa vào CI. Nó trả lời 4 câu hỏi:
//   1. Món nào đã có ảnh thật trong `assets/images/dishes/`, món nào còn
//      thiếu ảnh thật và sẽ rơi về placeholder?
//   2. Có hai file ảnh nào trùng nội dung (cùng sha256) không?
//   3. Có nhiều tên món khác nhau nhưng ra cùng một slug không? (hai món sẽ
//      dùng chung một ảnh -> trùng hình)
//   4. Trong `lib/` còn sót tham chiếu ảnh bị cấm không
//      (loremflickr, kho dùng chung `assets/images/restaurants/food_01..12`),
//      và còn `Image.network` nào nằm ngoài widget `FoodImage` không?
//
// Kết quả ghi ra `output/image-audit-report.json` và
// `output/image-audit-report.md`. Thoát với mã 1 khi có lỗi nghiêm trọng.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shopeefood/common/dish_slug.dart';

const _dishAssetDir = 'assets/images/dishes';
const _allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

/// File được phép gọi thẳng `Image.network`.
///
/// Ảnh món bắt buộc đi qua `FoodImage`; avatar profile là ảnh người dùng nên
/// không thuộc audit ảnh món.
const _networkImageAllowlist = [
  'lib/common/food_image.dart',
  'lib/profile/profile_page.dart',
];

final _bannedPattern = RegExp(
  r'loremflickr\.com|picsum\.photos'
  r"|assets/images/restaurants/food_(0[1-9]|1[0-2])\.(jpg|png)",
  caseSensitive: false,
);

void main(List<String> args) {
  final root = Directory.current;
  stdout.writeln('[audit] thư mục dự án: ${root.path}');

  final dishes = _collectDishNames();
  final imageLabels = _collectImageLabels(dishes);
  final assets = _collectDishAssets();
  final aliases = _collectCuratedAliases();
  final duplicateAssets = _duplicateAssetHashes(assets);
  final slugCollisions = _slugCollisions(imageLabels);
  final bannedRefs = _scanBannedReferences();
  final strayNetworkImages = _scanStrayNetworkImages();

  final slugs = <String>{for (final name in imageLabels) DishSlug.of(name)};
  final withRealPhoto =
      slugs
          .where((slug) => _resolvedAssetSlug(slug, assets, aliases) != null)
          .toList()
        ..sort();
  final usingCard =
      slugs
          .where((slug) => _resolvedAssetSlug(slug, assets, aliases) == null)
          .toList()
        ..sort();
  final orphanAssets =
      assets.keys
          .where(
            (slug) => !slugs.contains(slug) && !aliases.values.contains(slug),
          )
          .toList()
        ..sort();

  final errors = <String>[
    for (final slug in usingCard) 'Label ảnh chưa có asset/alias thật: $slug',
    for (final entry in duplicateAssets.entries)
      'Hai ảnh trùng nội dung (${entry.key.substring(0, 12)}): '
          '${entry.value.join(", ")}',
    for (final entry in slugCollisions.entries)
      'Nhiều tên món cùng slug "${entry.key}": ${entry.value.join(" | ")}',
    for (final ref in bannedRefs) 'Còn tham chiếu ảnh bị cấm: $ref',
    for (final ref in strayNetworkImages)
      'Image.network nằm ngoài FoodImage: $ref',
  ];

  final report = <String, dynamic>{
    'generatedAt': DateTime.now().toIso8601String(),
    'dishNameCount': dishes.length,
    'imageLabelCount': imageLabels.length,
    'slugCount': slugs.length,
    'realPhotoCount': withRealPhoto.length,
    'generatedCardCount': usingCard.length,
    'assetFileCount': assets.length,
    'curatedAliasCount': aliases.length,
    'duplicateAssetHashes': duplicateAssets,
    'slugCollisions': slugCollisions,
    'bannedReferences': bannedRefs,
    'strayNetworkImages': strayNetworkImages,
    'orphanAssets': orphanAssets,
    'slugsWithRealPhoto': withRealPhoto,
    'slugsUsingGeneratedCard': usingCard,
    'errors': errors,
  };

  final outputDir = Directory('output');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }
  File(
    'output/image-audit-report.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  File('output/image-audit-report.md').writeAsStringSync(_markdown(report));

  stdout
    ..writeln('[audit] tên món thu được : ${dishes.length}')
    ..writeln('[audit] label ảnh thu được: ${imageLabels.length}')
    ..writeln('[audit] slug duy nhất    : ${slugs.length}')
    ..writeln('[audit] có ảnh thật      : ${withRealPhoto.length}')
    ..writeln('[audit] thiếu ảnh thật/placeholder: ${usingCard.length}')
    ..writeln('[audit] file ảnh trong bundle: ${assets.length}');

  if (errors.isEmpty) {
    stdout.writeln('[audit] OK — không phát hiện ảnh trùng hay tham chiếu cấm');
    return;
  }
  stderr.writeln('[audit] PHÁT HIỆN ${errors.length} vấn đề:');
  for (final error in errors) {
    stderr.writeln('  - $error');
  }
  exitCode = 1;
}

/// Gom tên món từ mọi nơi sinh dữ liệu: menu theo loại quán, menu sinh thêm,
/// danh sách món của trang khuyến mãi và tên quán seed.
List<String> _collectDishNames() {
  final names = <String>{};

  final catalog = _read('lib/restaurant/menu_catalog.dart');
  for (final match in RegExp(r"DishSpec\(\s*'([^']+)'").allMatches(catalog)) {
    names.add(match.group(1)!);
  }

  final detail = _read('lib/restaurant/restaurant_detail_page.dart');
  for (final match in RegExp(
    r"\(\s*'([^']+)',\s*'[^']*',\s*\d+\)",
  ).allMatches(detail)) {
    names.add(match.group(1)!);
  }

  final promo = _read('lib/home/promo_results_page.dart');
  for (final block in _listBlocks(promo, '_cleanDishes = {')) {
    names.addAll(_quoted(block));
  }
  for (final match in RegExp(
    r'dishes:\s*const\s*\[([^\]]*)\]',
  ).allMatches(promo)) {
    names.addAll(_quoted(match.group(1)!));
  }

  final repository = _read('lib/home/restaurant_repository.dart');
  for (final match in RegExp(
    r"\(\s*'[^']+',\s*'([^']+)',\s*'[^']+'\)",
  ).allMatches(repository)) {
    names.add(match.group(1)!);
  }

  final home = _read('lib/home/home_page.dart');
  for (final block in [
    ..._listBlocks(home, 'const _uiSeedImageLabels'),
    ..._listBlocks(home, 'const _restaurantSeedImageLabels'),
  ]) {
    names.addAll(_quoted(block));
  }
  for (final marker in [
    'const _dealCards',
    'const _collections',
    'const _flashItems',
    'const _recentItems',
  ]) {
    for (final block in _listBlocks(home, marker)) {
      names.addAll(_fieldValues(block, 'name'));
    }
  }

  final list = names.where((name) => name.trim().isNotEmpty).toList()..sort();
  return list;
}

List<String> _collectImageLabels(List<String> dishNames) {
  final labels = <String>{...dishNames};
  for (final file in _dartFiles(includeTests: false)) {
    final source = file.readAsStringSync();
    for (final match in RegExp(
      r"DishImages\.resolve\(\s*'([^']+)'",
    ).allMatches(source)) {
      labels.add(match.group(1)!);
    }
  }
  return labels.where((name) => name.trim().isNotEmpty).toList()..sort();
}

Map<String, String> _collectCuratedAliases() {
  final source = _read('lib/restaurant/dish_images.dart');
  final start = source.indexOf('_curatedAliasSlugs');
  if (start < 0) {
    return const <String, String>{};
  }
  final end = source.indexOf('\n  };', start);
  if (end < 0) {
    return const <String, String>{};
  }
  final block = source.substring(start, end);
  return {
    for (final match in RegExp(r"'([^']+)'\s*:\s*'([^']+)'").allMatches(block))
      match.group(1)!: match.group(2)!,
  };
}

String? _resolvedAssetSlug(
  String slug,
  Map<String, String> assets,
  Map<String, String> aliases,
) {
  if (assets.containsKey(slug)) {
    return slug;
  }
  final alias = aliases[slug];
  if (alias != null && assets.containsKey(alias)) {
    return alias;
  }
  return null;
}

/// Cắt khối `const Map<String, List<String>> <name> = { ... };`
List<String> _listBlocks(String source, String name) {
  final start = source.indexOf(name);
  if (start < 0) {
    return const [];
  }
  final mapEnd = source.indexOf('\n};', start);
  final listEnd = source.indexOf('\n];', start);
  final candidates = [mapEnd, listEnd].where((index) => index >= 0).toList()
    ..sort();
  final end = candidates.isEmpty ? -1 : candidates.first;
  if (end < 0) {
    return const [];
  }
  return [source.substring(start, end)];
}

List<String> _quoted(String block) {
  return RegExp(r"'([^'\n]+)'")
      .allMatches(block)
      .map((match) => match.group(1)!)
      .where(_looksLikeDishName)
      .toList();
}

List<String> _fieldValues(String block, String fieldName) {
  return RegExp("$fieldName:\\s*'([^'\\n]+)'")
      .allMatches(block)
      .map((match) => match.group(1)!)
      .where(_looksLikeDishName)
      .toList();
}

/// Loại chuỗi kỹ thuật (template `\$var`, id, nhãn khuyến mãi) khỏi danh sách
/// tên món để báo cáo không bị nhiễu.
bool _looksLikeDishName(String value) {
  if (value.length < 4 || value.contains(r'$') || value.contains('/')) {
    return false;
  }
  return value.contains(' ');
}

/// slug -> đường dẫn file ảnh thật.
Map<String, String> _collectDishAssets() {
  final directory = Directory(_dishAssetDir);
  if (!directory.existsSync()) {
    return <String, String>{};
  }
  final result = <String, String>{};
  for (final entity in directory.listSync()) {
    if (entity is! File) {
      continue;
    }
    final path = entity.path.replaceAll('\\', '/');
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) {
      continue;
    }
    final extension = name.substring(dot).toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      continue;
    }
    result[name.substring(0, dot).toLowerCase()] = path;
  }
  return result;
}

/// sha256 -> danh sách file trùng nội dung (chỉ giữ nhóm từ 2 file trở lên).
Map<String, List<String>> _duplicateAssetHashes(Map<String, String> assets) {
  final byHash = <String, List<String>>{};
  for (final path in assets.values) {
    final digest = sha256.convert(File(path).readAsBytesSync()).toString();
    byHash.putIfAbsent(digest, () => <String>[]).add(path);
  }
  byHash.removeWhere((_, files) => files.length < 2);
  return byHash;
}

/// Hai tên món KHÁC NHAU ra cùng slug -> chắc chắn dùng chung một ảnh.
///
/// Khác biệt chỉ ở hoa/thường ("Hủ tiếu Nam Vang" và "Hủ Tiếu Nam Vang") là
/// cùng một món nên không tính là lỗi.
Map<String, List<String>> _slugCollisions(List<String> names) {
  final bySlug = <String, Set<String>>{};
  for (final name in names) {
    bySlug
        .putIfAbsent(DishSlug.of(name), () => <String>{})
        .add(DishSlug.ascii(name).replaceAll(RegExp(r'\s+'), ' ').trim());
  }
  final collisions = <String, List<String>>{};
  bySlug.forEach((slug, group) {
    if (group.length > 1) {
      collisions[slug] = group.toList()..sort();
    }
  });
  return collisions;
}

/// Chỉ quét `lib/` — file test được phép chứa URL cũ làm dữ liệu đầu vào để
/// kiểm tra chính luồng chuẩn hoá ảnh.
List<String> _scanBannedReferences() {
  final hits = <String>[];
  for (final file in _dartFiles(includeTests: false)) {
    // Bỏ qua chính nơi khai báo danh sách cấm (DishImages) và script này.
    if (file.path.endsWith('dish_images.dart') ||
        file.path.endsWith('audit_images.dart')) {
      continue;
    }
    final lines = file.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (_bannedPattern.hasMatch(lines[i])) {
        hits.add('${_relative(file.path)}:${i + 1}');
      }
    }
  }
  return hits;
}

List<String> _scanStrayNetworkImages() {
  final hits = <String>[];
  for (final file in _dartFiles(includeTests: false)) {
    final relative = _relative(file.path);
    if (_networkImageAllowlist.contains(relative)) {
      continue;
    }
    final lines = file.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('Image.network(') ||
          lines[i].contains('NetworkImage(')) {
        hits.add('$relative:${i + 1}');
      }
    }
  }
  return hits;
}

Iterable<File> _dartFiles({bool includeTests = true}) sync* {
  final roots = <String>['lib', if (includeTests) 'test'];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield entity;
      }
    }
  }
}

String _relative(String path) => path.replaceAll('\\', '/');

String _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}

String _markdown(Map<String, dynamic> report) {
  final buffer = StringBuffer()
    ..writeln('# Báo cáo ảnh món ShopeeFood')
    ..writeln()
    ..writeln('Tạo lúc: ${report['generatedAt']}')
    ..writeln()
    ..writeln('| Chỉ số | Giá trị |')
    ..writeln('| --- | ---: |')
    ..writeln('| Tên món thu được | ${report['dishNameCount']} |')
    ..writeln('| Slug duy nhất | ${report['slugCount']} |')
    ..writeln('| Món có ảnh thật | ${report['realPhotoCount']} |')
    ..writeln(
      '| Món thiếu ảnh thật / placeholder | ${report['generatedCardCount']} |',
    )
    ..writeln('| File ảnh trong bundle | ${report['assetFileCount']} |')
    ..writeln();

  final errors = (report['errors'] as List).cast<String>();
  if (errors.isEmpty) {
    buffer
      ..writeln('## Kết quả')
      ..writeln()
      ..writeln('Không phát hiện ảnh trùng nội dung, slug trùng, tham chiếu')
      ..writeln('ảnh bị cấm hay `Image.network` nằm ngoài `FoodImage`.')
      ..writeln();
  } else {
    buffer
      ..writeln('## Vấn đề cần xử lý')
      ..writeln();
    for (final error in errors) {
      buffer.writeln('- $error');
    }
    buffer.writeln();
  }

  final usingCard = (report['slugsUsingGeneratedCard'] as List).cast<String>();
  buffer
    ..writeln('## Món đang thiếu ảnh thật')
    ..writeln()
    ..writeln('Thả file `assets/images/dishes/<slug>.jpg` là app tự thay ảnh.')
    ..writeln();
  for (final slug in usingCard) {
    buffer.writeln('- `$slug`');
  }
  return buffer.toString();
}
