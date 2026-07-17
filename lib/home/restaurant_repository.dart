import 'dart:convert';

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

  static Future<RestaurantLoadResult> loadNearby(AppLocation location) async {
    if (location.isFallback) {
      return const RestaurantLoadResult(restaurants: [], fromCache: false);
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

    return const RestaurantLoadResult(restaurants: [], fromCache: false);
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
