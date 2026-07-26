import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../home/restaurant_repository.dart';
import '../location/location_service.dart';
import '../restaurant/restaurant_detail_page.dart';
import 'dish_image_service.dart';

/// Kết quả của một lần nạp dữ liệu mẫu lên Firestore.
class CatalogSeedReport {
  final int restaurantCount;
  final int menuItemCount;
  final int remoteImageCount;
  final int skippedCount;
  final String? error;

  const CatalogSeedReport({
    required this.restaurantCount,
    required this.menuItemCount,
    this.remoteImageCount = 0,
    this.skippedCount = 0,
    this.error,
  });

  bool get isSuccess => error == null;

  String get message {
    if (!isSuccess) {
      return 'Nạp dữ liệu thất bại: $error';
    }
    final imageNote = remoteImageCount > 0
        ? ', $remoteImageCount món có ảnh thật'
        : ' (chưa có PEXELS_API_KEY nên dùng ảnh sẵn có)';
    return 'Đã nạp $restaurantCount quán và $menuItemCount món$imageNote';
  }
}

/// Nạp danh mục quán + menu từ dữ liệu seed offline lên Firestore.
///
/// Chỉ cần chạy MỘT LẦN. Sau khi chạy xong nên sửa `firestore.rules` để khoá
/// quyền ghi (`allow write: if false`) — lúc đó app chỉ còn đọc dữ liệu.
///
/// Toạ độ quán được sinh quanh [location] tại thời điểm seed, nên hãy chạy
/// khi app đã lấy được vị trí thật để khoảng cách hiển thị hợp lý.
class CatalogSeeder {
  static const _catalogCollection = 'restaurants';
  static const _menuCollection = 'menuItems';

  /// Firestore cho tối đa 500 thao tác mỗi batch — chừa biên an toàn.
  static const _batchLimit = 400;

  static Future<CatalogSeedReport> seed(AppLocation location) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final listings = RestaurantRepository.localSeedFor(location);

      DishImageService.resetCache();

      var batch = firestore.batch();
      var pendingOps = 0;
      var menuItemCount = 0;
      var remoteImageCount = 0;
      var done = 0;
      var skippedCount = 0;

      Future<void> flush() async {
        if (pendingOps == 0) {
          return;
        }
        await batch.commit();
        batch = firestore.batch();
        pendingOps = 0;
      }

      for (final listing in listings) {
        // Bắt đầu đếm lại ảnh đã dùng -> trong một quán không lặp ảnh.
        DishImageService.beginRestaurant();

        final restaurantRef = firestore
            .collection(_catalogCollection)
            .doc(_safeDocId(listing.id));

        batch.set(restaurantRef, <String, dynamic>{
          ...listing.toJson(),
          'source': 'firestore',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        pendingOps++;
        if (pendingOps >= _batchLimit) {
          await flush();
        }

        final sections = MenuFactory.sectionsFor(_detailInputFor(listing));

        // Dọn món của lần seed trước. Chỉ xoá những doc KHÔNG có trong menu
        // mới, để không bao giờ vừa delete vừa set cùng một document.
        final newItemIds = sections
            .expand((section) => section.items)
            .map((item) => _safeDocId(item.id))
            .toSet();
        final staleItems = await restaurantRef.collection(_menuCollection).get();

        // Bo qua quan da co menu day du va toan bo anh la anh that.
        // Nho vay chay lai sau khi bi ngat khong ton them luot goi Pexels
        // (goi free chi 200 luot/gio), van cap nhat lai doc quan o tren.
        final expectedItems = sections.fold<int>(
          0,
          (total, section) => total + section.items.length,
        );
        final existingUrls = staleItems.docs
            .map((doc) => doc.data()['imageUrl'] as String?)
            .whereType<String>()
            .toList();
        final menuAlreadyDone =
            staleItems.docs.length == expectedItems &&
            existingUrls.length == expectedItems &&
            existingUrls.every((url) => url.startsWith('http')) &&
            // Bo qua CHI KHI khong con anh trung trong cung mot menu.
            existingUrls.toSet().length == expectedItems;
        if (menuAlreadyDone) {
          await flush();
          done++;
          skippedCount++;
          menuItemCount += expectedItems;
          debugPrint(
            '[CatalogSeeder] $done/${listings.length} ${listing.name} '
            '- da co anh that, bo qua',
          );
          continue;
        }

        for (final stale in staleItems.docs) {
          if (newItemIds.contains(stale.id)) {
            continue;
          }
          batch.delete(stale.reference);
          pendingOps++;
          if (pendingOps >= _batchLimit) {
            await flush();
          }
        }

        for (var sectionIndex = 0;
            sectionIndex < sections.length;
            sectionIndex++) {
          final section = sections[sectionIndex];
          for (var itemIndex = 0;
              itemIndex < section.items.length;
              itemIndex++) {
            final item = section.items[itemIndex];
            final itemRef = restaurantRef
                .collection(_menuCollection)
                .doc(_safeDocId(item.id));

            // Ảnh thật theo tên món (Pexels). Nếu không có key hoặc lỗi mạng
            // thì giữ ảnh asset -> không bao giờ để món thiếu ảnh.
            final remoteImage = await DishImageService.imageUrlFor(item.name);
            if (remoteImage != null) {
              remoteImageCount++;
            }

            batch.set(itemRef, <String, dynamic>{
              'name': item.name,
              'description': item.description,
              'price': item.price,
              'sold': item.sold,
              'likes': item.likes,
              'imageUrl': remoteImage ?? item.imageUrl,
              'section': section.title,
              'sectionOrder': sectionIndex,
              'itemOrder': itemIndex,
              'available': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            pendingOps++;
            menuItemCount++;
            if (pendingOps >= _batchLimit) {
              await flush();
            }
          }
        }

        // Commit ngay sau mỗi quán (khoảng 23 thao tác) thay vì dồn 400.
        // Nhờ vậy nếu app bị kill giữa đường thì các quán đã xong vẫn ĐẦY ĐỦ,
        // và chạy lại chỉ ghi đè - không để lại menu thiếu món.
        await flush();
        debugPrint(
          '[CatalogSeeder] ${done + 1}/${listings.length} '
          '${listing.name} — $menuItemCount món, $remoteImageCount ảnh thật',
        );
        done++;
      }

      await flush();

      debugPrint(
        '[CatalogSeeder] xong: ${listings.length} quan / $menuItemCount mon '
        '($skippedCount quan bo qua vi da co anh that)',
      );
      return CatalogSeedReport(
        restaurantCount: listings.length,
        menuItemCount: menuItemCount,
        remoteImageCount: remoteImageCount,
        skippedCount: skippedCount,
      );
    } catch (error) {
      debugPrint('[CatalogSeeder] lỗi: $error');
      return CatalogSeedReport(
        restaurantCount: 0,
        menuItemCount: 0,
        error: error.toString(),
      );
    }
  }

  /// Doc id của Firestore không được chứa '/' và không được là '.' hoặc '..'.
  static String _safeDocId(String raw) {
    final cleaned = raw.replaceAll('/', '-').trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'item-${raw.hashCode.abs()}';
    }
    return cleaned;
  }

  static RestaurantDetailInput _detailInputFor(RestaurantListing listing) {
    return RestaurantDetailInput(
      id: listing.id,
      name: listing.name,
      address: listing.address,
      seed: listing.id,
      category: listing.category,
      rating: listing.rating,
      distance: 0,
      time: 20,
      sold: listing.userRatingCount ?? 0,
      imageUrl: listing.photoUrl,
      openNow: listing.openNow,
      latitude: listing.latitude,
      longitude: listing.longitude,
    );
  }
}
