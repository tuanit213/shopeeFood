import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'dish_images.dart';
import 'restaurant_detail_page.dart';

/// Đọc menu của một quán từ Firestore.
///
/// Kiến trúc 2 lớp:
/// 1. Firestore `restaurants/{id}/menuItems` là nguồn dữ liệu chính.
/// 2. Nếu quán chưa có menu trên server, mất mạng, hoặc Firebase chưa khởi
///    tạo thì trả về `null` để màn hình giữ nguyên menu offline do
///    [MenuFactory] sinh ra — app không bao giờ hiện danh sách trống.
class MenuRepository {
  static const _catalogCollection = 'restaurants';
  static const _menuCollection = 'menuItems';
  static const _timeout = Duration(seconds: 6);
  static const _fallbackSectionTitle = 'Món chính';
  static const _fallbackImage = '';

  static CollectionReference<Map<String, dynamic>> _menuRef(
    String restaurantId,
  ) {
    return FirebaseFirestore.instance
        .collection(_catalogCollection)
        .doc(restaurantId)
        .collection(_menuCollection);
  }

  /// `null` = không lấy được dữ liệu -> caller giữ menu offline.
  static Future<List<MenuSection>?> fetchSections(String restaurantId) async {
    if (restaurantId.trim().isEmpty) {
      return null;
    }

    try {
      final snapshot = await _menuRef(restaurantId).get().timeout(_timeout);
      if (snapshot.docs.isEmpty) {
        debugPrint(
          '[MenuRepository] $restaurantId chưa có menu trên Firestore',
        );
        return null;
      }

      final sections = _groupIntoSections(snapshot.docs);
      return sections.isEmpty ? null : sections;
    } catch (error) {
      debugPrint('[MenuRepository] fetchSections($restaurantId) lỗi: $error');
      return null;
    }
  }

  /// Nhóm các món theo `section`, giữ thứ tự `sectionOrder` / `itemOrder`.
  /// Sắp xếp ở client để không cần tạo composite index trên Firestore.
  static List<MenuSection> _groupIntoSections(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final entries = docs.map(_MenuEntry.fromDoc).toList()
      ..sort((a, b) {
        final bySection = a.sectionOrder.compareTo(b.sectionOrder);
        return bySection != 0 ? bySection : a.itemOrder.compareTo(b.itemOrder);
      });

    final grouped = <String, List<MenuItemData>>{};
    final titles = <String>[];
    // Khoá "hình nhìn thấy được", không phải chuỗi URL.
    final usedImages = <String>{};
    for (final entry in entries) {
      if (!entry.available) {
        continue;
      }
      final items = grouped.putIfAbsent(entry.section, () {
        titles.add(entry.section);
        return <MenuItemData>[];
      });
      items.add(_withUniqueImage(entry.item, usedImages));
    }

    return titles
        .map(
          (title) =>
              MenuSection(title: title, items: grouped[title] ?? const []),
        )
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  /// Đảm bảo trong CÙNG một menu không có hai món hiện cùng một hình.
  ///
  /// Ảnh remote cũ (chưa seed lại) hoặc ảnh dùng chung bị loại ngay trong
  /// [DishImages.normalize]. Nếu vẫn còn trùng — thường do hai món khác id
  /// nhưng cùng URL ảnh cũ — thì bỏ ảnh remote để tránh ảnh sai món.
  static MenuItemData _withUniqueImage(
    MenuItemData item,
    Set<String> usedImages,
  ) {
    var imageUrl = DishImages.normalize(
      label: item.name,
      imageUrl: item.imageUrl,
      imageVersion: item.imageVersion,
    );
    var key = imageUrl.isEmpty
        ? 'missing:${DishImages.slugFor(item.name)}'
        : imageUrl;
    if (!usedImages.add(key)) {
      imageUrl = '';
      key = 'missing:${DishImages.slugFor(item.name)}-${usedImages.length}';
      usedImages.add(key);
    }
    return MenuItemData(
      id: item.id,
      name: item.name,
      description: item.description,
      price: item.price,
      sold: item.sold,
      likes: item.likes,
      imageUrl: imageUrl,
      imageVersion: item.imageVersion,
    );
  }
}

class _MenuEntry {
  final MenuItemData item;
  final String section;
  final int sectionOrder;
  final int itemOrder;
  final bool available;

  const _MenuEntry({
    required this.item,
    required this.section,
    required this.sectionOrder,
    required this.itemOrder,
    required this.available,
  });

  factory _MenuEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawSection = (data['section'] as String?)?.trim() ?? '';
    final rawImage = (data['imageUrl'] as String?)?.trim() ?? '';
    final rawName = (data['name'] as String?)?.trim() ?? '';

    return _MenuEntry(
      section: rawSection.isEmpty
          ? MenuRepository._fallbackSectionTitle
          : rawSection,
      sectionOrder: (data['sectionOrder'] as num?)?.toInt() ?? 0,
      itemOrder: (data['itemOrder'] as num?)?.toInt() ?? 0,
      available: data['available'] as bool? ?? true,
      item: MenuItemData(
        id: doc.id,
        name: rawName.isEmpty ? 'Món ăn' : rawName,
        description: (data['description'] as String?)?.trim() ?? '',
        price: (data['price'] as num?)?.toInt() ?? 0,
        sold: (data['sold'] as num?)?.toInt() ?? 0,
        likes: (data['likes'] as num?)?.toInt() ?? 0,
        imageUrl: rawImage.isEmpty ? MenuRepository._fallbackImage : rawImage,
        imageVersion: (data['imageVersion'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
