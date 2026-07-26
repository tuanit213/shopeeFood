import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../location/location_service.dart';
import 'nearby_restaurant_service.dart';

class RestaurantListing {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? userRatingCount;
  final String? photoUrl;
  final bool openNow;
  final String category;
  final String source;

  const RestaurantListing({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingCount,
    required this.photoUrl,
    required this.openNow,
    required this.category,
    required this.source,
  });

  double distanceFrom(AppLocation location) {
    return NearbyRestaurantService.distanceInKm(
      fromLat: location.latitude,
      fromLng: location.longitude,
      toLat: latitude,
      toLng: longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'userRatingCount': userRatingCount,
      'photoUrl': photoUrl,
      'openNow': openNow,
      'category': category,
      'source': source,
    };
  }

  factory RestaurantListing.fromJson(Map<String, dynamic> json) {
    return RestaurantListing(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Quán gần bạn',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
      photoUrl: json['photoUrl'] as String?,
      openNow: json['openNow'] as bool? ?? true,
      category: json['category'] as String? ?? 'restaurant',
      source: json['source'] as String? ?? 'cache',
    );
  }

  factory RestaurantListing.fromNearby(NearbyRestaurant restaurant) {
    return RestaurantListing(
      id: restaurant.id,
      name: restaurant.name,
      address: restaurant.address,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      rating: restaurant.rating,
      userRatingCount: restaurant.userRatingCount,
      photoUrl: restaurant.photoUrl,
      openNow: restaurant.openNow,
      category: restaurant.category,
      source: NearbyRestaurantService.providerName,
    );
  }
}

class RestaurantLoadResult {
  final List<RestaurantListing> restaurants;
  final bool fromCache;

  const RestaurantLoadResult({
    required this.restaurants,
    required this.fromCache,
  });
}

class RestaurantRepository {
  static const _cachePrefix = 'restaurant_cache_v1';
  static const _cacheMaxAge = Duration(hours: 24);

  static const _catalogCollection = 'restaurants';

  /// Dữ liệu seed offline. Dùng cho fallback khi không có mạng và cho việc
  /// nạp dữ liệu mẫu lên Firestore (xem `CatalogSeeder`).
  static List<RestaurantListing> localSeedFor(AppLocation location) {
    return _seededRestaurantsNear(location);
  }

  /// Đọc danh mục quán từ Firestore (nguồn dữ liệu chính).
  ///
  /// Trả về danh sách rỗng khi chưa seed dữ liệu, mất mạng, hoặc Firebase
  /// chưa khởi tạo (ví dụ trong unit test) — caller sẽ tự lùi về luồng cũ.
  static Future<List<RestaurantListing>> fetchCatalog() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_catalogCollection)
          .limit(60)
          .get()
          .timeout(const Duration(seconds: 5));

      final listings = snapshot.docs
          .map(
            (doc) => RestaurantListing.fromJson({
              ...doc.data(),
              'id': doc.id,
              'source': 'firestore',
            }),
          )
          .where(_hasUsefulName)
          .toList();

      debugPrint('[RestaurantRepository] firestore catalog: ${listings.length}');
      return listings;
    } catch (error) {
      debugPrint('[RestaurantRepository] firestore catalog failed: $error');
      return const <RestaurantListing>[];
    }
  }

  static Future<RestaurantLoadResult> loadNearby(AppLocation location) async {
    // Lớp 1: danh mục thật trên Firestore.
    final catalog = await fetchCatalog();
    if (catalog.isNotEmpty) {
      return RestaurantLoadResult(restaurants: catalog, fromCache: false);
    }

    if (location.isFallback) {
      return RestaurantLoadResult(
        restaurants: _seededRestaurantsNear(location),
        fromCache: false,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKeyFor(location);
    final cached = _readCache(prefs, cacheKey);
    if (cached != null && cached.isFresh) {
      debugPrint(
        '[RestaurantRepository] loaded ${cached.items.length} cached restaurants',
      );
      return RestaurantLoadResult(restaurants: cached.items, fromCache: true);
    }

    final remoteRestaurants =
        await NearbyRestaurantService.fetchNearbyRestaurants(location);
    if (remoteRestaurants.isNotEmpty) {
      final listings = remoteRestaurants
          .map(RestaurantListing.fromNearby)
          .where(_hasUsefulName)
          .toList();
      await _writeCache(prefs, cacheKey, listings);
      return RestaurantLoadResult(restaurants: listings, fromCache: false);
    }

    if (cached != null && cached.items.isNotEmpty) {
      debugPrint(
        '[RestaurantRepository] using stale cache ${cached.items.length}',
      );
      return RestaurantLoadResult(restaurants: cached.items, fromCache: true);
    }

    return RestaurantLoadResult(
      restaurants: _seededRestaurantsNear(location),
      fromCache: false,
    );
  }

  static String _cacheKeyFor(AppLocation location) {
    final lat = location.latitude.toStringAsFixed(3);
    final lng = location.longitude.toStringAsFixed(3);
    return '$_cachePrefix:$lat:$lng';
  }

  static _RestaurantCache? _readCache(
    SharedPreferences prefs,
    String cacheKey,
  ) {
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAtMs = payload['fetchedAt'] as int? ?? 0;
      final items = payload['items'] as List<dynamic>? ?? const [];
      return _RestaurantCache(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
        items: items
            .map(
              (item) =>
                  RestaurantListing.fromJson(item as Map<String, dynamic>),
            )
            .where(_hasUsefulName)
            .toList(),
      );
    } catch (error) {
      debugPrint('[RestaurantRepository] bad cache: $error');
      return null;
    }
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    String cacheKey,
    List<RestaurantListing> listings,
  ) async {
    final payload = {
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'items': listings.map((item) => item.toJson()).toList(),
    };
    await prefs.setString(cacheKey, jsonEncode(payload));
  }

  static bool _hasUsefulName(RestaurantListing item) {
    final name = item.name.trim();
    return item.id.isNotEmpty && name.isNotEmpty && name != 'Quán gần bạn';
  }
}

class _RestaurantCache {
  final DateTime fetchedAt;
  final List<RestaurantListing> items;

  const _RestaurantCache({required this.fetchedAt, required this.items});

  bool get isFresh =>
      DateTime.now().difference(fetchedAt) <= RestaurantRepository._cacheMaxAge;
}

List<RestaurantListing> _seededRestaurantsNear(AppLocation location) {
  return List<RestaurantListing>.generate(_seededRestaurantNames.length, (
    index,
  ) {
    final seed = _seededRestaurantNames[index];
    final offset = _offsetForIndex(index);
    final latitude = location.latitude + offset.$1;
    final longitude = location.longitude + offset.$2;
    return RestaurantListing(
      id: 'seed-${seed.$1}-$index',
      name: seed.$2,
      address: _addressNear(location, index),
      latitude: latitude,
      longitude: longitude,
      rating: 4.3 + (index % 7) * 0.08,
      userRatingCount: 80 + index * 37,
      photoUrl: _seededPhotoUrls[index % _seededPhotoUrls.length],
      openNow: index % 9 != 0,
      category: seed.$3,
      source: 'seed',
    );
  });
}

(double, double) _offsetForIndex(int index) {
  const offsets = <(double, double)>[
    (0.0012, 0.0018),
    (-0.0015, 0.0021),
    (0.0024, -0.0011),
    (-0.0022, -0.0017),
    (0.0030, 0.0006),
    (0.0007, -0.0031),
    (-0.0032, 0.0010),
    (0.0019, 0.0034),
    (-0.0028, -0.0027),
    (0.0040, -0.0015),
  ];
  return offsets[index % offsets.length];
}

String _addressNear(AppLocation location, int index) {
  final streets = <String>[
    'Nguyễn Trãi',
    'Lê Văn Sỹ',
    'Cách Mạng Tháng 8',
    'Phạm Văn Đồng',
    'Điện Biên Phủ',
    'Nguyễn Thị Minh Khai',
    'Võ Văn Tần',
    'Phan Xích Long',
    'Hoàng Sa',
    'Trường Sa',
  ];
  final ward = index % 3 == 0 ? 'Phường 1' : 'Phường ${index % 12 + 2}';
  final district = index % 4 == 0 ? 'Quận 1' : 'Quận ${index % 10 + 2}';
  final base = location.address.trim().isEmpty
      ? 'TP. Hồ Chí Minh'
      : location.address;
  return '${12 + index * 7} ${streets[index % streets.length]}, $ward, $district, $base';
}

const _seededRestaurantNames = <(String, String, String)>[
  ('com-ga', 'Cơm gà xối mỡ Minh Long', 'rice'),
  ('bun-bo', 'Bún bò Huế O Thương', 'noodle'),
  ('tra-sua', 'Trà sữa Maycha Nguyễn Trãi', 'milk_tea'),
  ('banh-mi', 'Bánh mì que Đà Nẵng', 'breakfast'),
  ('pho', 'Phở bò tái nạm Gia Truyền', 'noodle'),
  ('ga-ran', 'Gà rán sốt cay Seoul', 'korean'),
  ('kimbap', 'Kimbap & Tokbokki Hanuri', 'korean'),
  ('katinat', 'Katinat Coffee & Tea', 'coffee'),
  ('xien-que', 'Xiên que nướng Nha Trang', 'snack'),
  ('lau', 'Lẩu Thái Tomyum 199k', 'hotpot'),
  ('pizza', 'Pizza phô mai kéo sợi', 'western'),
  ('banh-cuon', 'Bánh cuốn nóng Bà Mười', 'breakfast'),
  ('hu-tieu', 'Hủ tiếu Nam Vang Cô Ba', 'noodle'),
  ('che', 'Chè Thái sầu riêng', 'dessert'),
  ('bep-chay', 'Bếp chay An Nhiên', 'vegetarian'),
  ('sushi', 'Sushi Bento Tokyo', 'japanese'),
  ('banh-trang', 'Bánh tráng trộn Long An', 'snack'),
  ('ca-phe', 'Cà phê sữa đá 24h', 'coffee'),
  ('com-tam', 'Cơm tấm sườn bì chả', 'rice'),
  ('mi-cay', 'Mì cay 7 cấp độ Sasin', 'korean'),
  ('goi-cuon', 'Gỏi cuốn tôm thịt', 'healthy'),
  ('bun-dau', 'Bún đậu mắm tôm Phố Cổ', 'vietnamese'),
  ('oc', 'Ốc đêm Sài Gòn', 'seafood'),
  ('burger', 'Burger bò phô mai', 'western'),
  ('matcha', 'Matcha latte & waffle', 'dessert'),
];

const _seededPhotoUrls = <String>[
  'assets/images/restaurants/food_01.jpg',
  'assets/images/restaurants/food_02.jpg',
  'assets/images/restaurants/food_03.jpg',
  'assets/images/restaurants/food_04.jpg',
  'assets/images/restaurants/food_05.jpg',
  'assets/images/restaurants/food_06.jpg',
  'assets/images/restaurants/food_07.jpg',
  'assets/images/restaurants/food_08.jpg',
  'assets/images/restaurants/food_09.jpg',
  'assets/images/restaurants/food_10.jpg',
  'assets/images/restaurants/food_11.jpg',
  'assets/images/restaurants/food_12.jpg',
];
