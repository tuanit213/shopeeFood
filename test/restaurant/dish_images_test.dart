import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/restaurant/dish_images.dart';

void main() {
  setUp(() {
    // Giả lập bundle chưa có ảnh thật nào -> món thiếu ảnh rơi về placeholder.
    DishImages.debugSetAvailableAssets(const <String>{});
  });

  test('slug bỏ dấu tiếng Việt đúng từng chữ', () {
    expect(DishImages.slugFor('Bún bò Huế'), 'bun-bo-hue');
    expect(DishImages.slugFor('Cơm tấm sườn bì chả'), 'com-tam-suon-bi-cha');
    expect(DishImages.slugFor('Trà sữa trân châu'), 'tra-sua-tran-chau');
    expect(DishImages.slugFor('  Phở  bò  '), 'pho-bo');
  });

  test('resolve trả về ảnh thật khi có file đúng slug', () {
    DishImages.debugSetAvailableAssets(const {
      'assets/images/dishes/bun-bo-hue.jpg',
      'assets/images/dishes/tra-sua-tran-chau.png',
    });

    expect(
      DishImages.resolve('Bún bò Huế'),
      'assets/images/dishes/bun-bo-hue.jpg',
    );
    expect(
      DishImages.resolve('Trà sữa trân châu'),
      'assets/images/dishes/tra-sua-tran-chau.png',
    );
    expect(DishImages.resolve('Món chưa có ảnh'), isEmpty);
  });

  test('ảnh không phụ thuộc salt nên một món luôn ra một hình', () {
    DishImages.debugSetAvailableAssets(const {
      'assets/images/dishes/bun-bo-hue.jpg',
    });

    expect(
      DishImages.resolve('Bún bò Huế', salt: 'quan-a'),
      DishImages.resolve('Bún bò Huế', salt: 'quan-b'),
    );
  });

  test('resolve chỉ dùng exact asset hoặc alias UI đã duyệt', () {
    DishImages.debugSetAvailableAssets(const {
      'assets/images/dishes/banh-mi-chao-dac-biet.jpg',
      'assets/images/dishes/bo-luc-lac-khoai-tay.jpg',
      'assets/images/dishes/deal-no-bung-50k.jpg',
      'assets/images/dishes/mi-ly-hai-san-xuc-xich.jpg',
      'assets/images/dishes/mi-tuoi-nhung-lau.jpg',
      'assets/images/dishes/pha-lau-bo.jpg',
      'assets/images/dishes/xuc-xich-quay.jpg',
      'assets/images/dishes/khoai-tay-chien.jpg',
      'assets/images/dishes/sua-tuoi-tran-chau.jpg',
      'assets/images/dishes/xoi-ga-xe.jpg',
      'assets/images/dishes/xoi-man-day-du.jpg',
      'assets/images/dishes/chao-suon-non.jpg',
      'assets/images/dishes/chao-ga-la-chanh.jpg',
    });

    expect(
      DishImages.resolve('Bánh Mì Chảo Cô Ba - CN 23'),
      'assets/images/dishes/banh-mi-chao-dac-biet.jpg',
    );
    expect(
      DishImages.resolve('Bánh Mì Chảo Cô Ba'),
      'assets/images/dishes/banh-mi-chao-dac-biet.jpg',
    );
    expect(
      DishImages.resolve('Bò Lúc Lắc Khoai Tây'),
      'assets/images/dishes/bo-luc-lac-khoai-tay.jpg',
    );
    expect(
      DishImages.resolve('Ưu đãi chỉ có hôm nay'),
      'assets/images/dishes/deal-no-bung-50k.jpg',
    );
    expect(
      DishImages.resolve('Mì thêm'),
      'assets/images/dishes/mi-tuoi-nhung-lau.jpg',
    );
    expect(DishImages.resolve('Phá lấu bò phần nhỏ'), isEmpty);
    expect(DishImages.resolve('Xúc xích quay x2'), isEmpty);
    expect(DishImages.resolve('Khoai tây chiên lớn'), isEmpty);
    expect(DishImages.resolve('Sâm dứa sữa size L'), isEmpty);
    expect(
      DishImages.resolve('Xôi gà xé'),
      'assets/images/dishes/xoi-ga-xe.jpg',
    );
    expect(
      DishImages.resolve('Xôi mặn đầy đủ'),
      'assets/images/dishes/xoi-man-day-du.jpg',
    );
    expect(
      DishImages.resolve('Cháo sườn non'),
      'assets/images/dishes/chao-suon-non.jpg',
    );
    expect(
      DishImages.resolve('Cháo gà lá chanh'),
      'assets/images/dishes/chao-ga-la-chanh.jpg',
    );
  });

  test('normalize loại ảnh ngẫu nhiên và kho ảnh dùng chung cũ', () {
    expect(
      DishImages.normalize(
        label: 'Bún bò Huế',
        imageUrl: 'https://loremflickr.com/640/480/pho?lock=123',
      ),
      isEmpty,
    );
    expect(
      DishImages.normalize(
        label: 'Bún bò Huế',
        imageUrl: 'assets/images/restaurants/food_03.jpg',
      ),
      isEmpty,
    );
  });

  test(
    'normalize bỏ asset path không có trong manifest rồi dùng alias hợp lệ',
    () {
      DishImages.debugSetAvailableAssets(const {
        'assets/images/dishes/banh-mi-chao-dac-biet.jpg',
      });

      expect(
        DishImages.normalize(
          label: 'Bánh Mì Chảo Cô Ba',
          imageUrl: 'assets/images/dishes/file-khong-ton-tai.jpg',
        ),
        'assets/images/dishes/banh-mi-chao-dac-biet.jpg',
      );
    },
  );

  test('normalize chỉ tin ảnh remote đã seed lại ở phiên bản mới', () {
    const url = 'https://images.pexels.com/photos/1/bun-bo.jpg';

    expect(DishImages.normalize(label: 'Bún bò Huế', imageUrl: url), isEmpty);
    expect(
      DishImages.normalize(
        label: 'Bún bò Huế',
        imageUrl: url,
        imageVersion: DishImages.approvedImageVersion,
      ),
      url,
    );
  });

  test('normalize ưu tiên ảnh local đúng tên món hơn URL đã seed', () {
    const oldRemoteCard = 'https://example.com/rendered/xoi-card.jpg';
    DishImages.debugSetAvailableAssets(const {
      'assets/images/dishes/xoi-ga-xe.jpg',
      'assets/images/dishes/xoi-man-day-du.jpg',
      'assets/images/dishes/chao-suon-non.jpg',
      'assets/images/dishes/chao-ga-la-chanh.jpg',
    });

    expect(
      DishImages.normalize(
        label: 'Xôi gà xé',
        imageUrl: oldRemoteCard,
        imageVersion: DishImages.approvedImageVersion,
      ),
      'assets/images/dishes/xoi-ga-xe.jpg',
    );
    expect(
      DishImages.normalize(
        label: 'Cháo sườn non',
        imageUrl: oldRemoteCard,
        imageVersion: DishImages.approvedImageVersion,
      ),
      'assets/images/dishes/chao-suon-non.jpg',
    );
  });

  test('visualKey phân biệt các món chưa có ảnh thật', () {
    final keys = <String>{
      for (final name in const [
        'Bún bò Huế',
        'Cơm tấm sườn bì chả',
        'Trà sữa trân châu',
        'Gà rán sốt cay',
        'Bánh mì thịt nướng',
      ])
        DishImages.visualKey(label: name),
    };

    expect(keys, hasLength(5));
    expect(keys.every((key) => key.startsWith('missing:')), isTrue);
  });

  test('categoryFor đoán đúng nhóm món để chọn màu thẻ', () {
    expect(DishImages.categoryFor('Bún bò Huế'), DishCategory.noodleSoup);
    expect(DishImages.categoryFor('Cơm tấm sườn'), DishCategory.rice);
    expect(DishImages.categoryFor('Trà sữa trân châu'), DishCategory.milkTea);
    expect(DishImages.categoryFor('Cà phê sữa đá'), DishCategory.coffee);
    expect(DishImages.categoryFor('Gà rán sốt cay'), DishCategory.friedChicken);
    expect(DishImages.categoryFor('Pizza hải sản'), DishCategory.western);
  });

  test('source code không còn tham chiếu kho ảnh dùng chung cũ', () {
    final banned = RegExp(
      r'assets/images/restaurants/food_(0[1-9]|1[0-2])\.jpg',
    );
    final matches = <String>[];

    for (final root in [Directory('lib'), Directory('test')]) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        // Hai file này khai báo chính biểu thức cấm nên bỏ qua.
        if (entity.path.endsWith('dish_images.dart') ||
            entity.path.endsWith('dish_images_test.dart')) {
          continue;
        }
        if (banned.hasMatch(entity.readAsStringSync())) {
          matches.add(entity.path);
        }
      }
    }

    expect(matches, isEmpty);
  });

  test('source code không còn gọi dịch vụ ảnh ngẫu nhiên', () {
    final matches = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('dish_images.dart')) {
        continue;
      }
      if (entity.readAsStringSync().contains('loremflickr')) {
        matches.add(entity.path);
      }
    }

    expect(matches, isEmpty);
  });

  test('chỉ FoodImage được gọi thẳng Image.network', () {
    final matches = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll('\\', '/');
      if (path.endsWith('lib/common/food_image.dart') ||
          path.endsWith('lib/profile/profile_page.dart')) {
        continue;
      }
      final content = entity.readAsStringSync();
      if (content.contains('Image.network(') ||
          content.contains('NetworkImage(')) {
        matches.add(path);
      }
    }

    expect(matches, isEmpty);
  });
}
