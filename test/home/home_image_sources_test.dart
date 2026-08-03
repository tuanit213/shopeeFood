import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/home/home_page.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    DishImages.debugSetAvailableAssets(_allDishAssets());
  });

  test('home image seeds resolve to real dish assets', () {
    final sources = homeImageSourcesForTesting();
    final empty = sources.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList();

    expect(empty, isEmpty);
    expect(
      sources.values.every(
        (source) => source.startsWith('assets/images/dishes/'),
      ),
      isTrue,
    );
  });
}

Set<String> _allDishAssets() {
  return Directory('assets/images/dishes')
      .listSync()
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .where((path) => RegExp(r'\.(jpg|jpeg|png|webp)$').hasMatch(path))
      .toSet();
}
