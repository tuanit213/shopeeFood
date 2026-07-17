import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../location/location_service.dart';

class NearbyRestaurant {
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

  const NearbyRestaurant({
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
  });

  double distanceFrom(AppLocation location) {
    return NearbyRestaurantService.distanceInKm(
      fromLat: location.latitude,
      fromLng: location.longitude,
      toLat: latitude,
      toLng: longitude,
    );
  }
}

class NearbyRestaurantService {
  static const _geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');
  static const _googleApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _googleNearbySearchUrl =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const _geoapifyPlacesUrl = 'https://api.geoapify.com/v2/places';

  static bool get hasRemoteApiKey =>
      _geoapifyApiKey.trim().isNotEmpty || _googleApiKey.trim().isNotEmpty;

  static String get providerName =>
      _geoapifyApiKey.trim().isNotEmpty ? 'Geoapify' : 'Google Maps';

  static Future<List<NearbyRestaurant>> fetchNearbyRestaurants(
    AppLocation location,
  ) async {
    if (!hasRemoteApiKey || location.isFallback) {
      return const [];
    }

    if (_geoapifyApiKey.trim().isNotEmpty) {
      return _fetchGeoapifyRestaurants(location);
    }

    return _fetchGoogleRestaurants(location);
  }

  static Future<List<NearbyRestaurant>> _fetchGeoapifyRestaurants(
    AppLocation location,
  ) async {
    final uri = Uri.parse(_geoapifyPlacesUrl).replace(
      queryParameters: {
        'categories':
            'catering.restaurant,catering.cafe,catering.fast_food,catering.food_court',
        'filter': 'circle:${location.longitude},${location.latitude},3500',
        'bias': 'proximity:${location.longitude},${location.latitude}',
        'limit': '20',
        'apiKey': _geoapifyApiKey,
      },
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[Geoapify] failed ${response.statusCode}: ${response.body}',
        );
        return const [];
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      final restaurants = features
          .map((raw) => _restaurantFromGeoapify(raw as Map<String, dynamic>))
          .whereType<NearbyRestaurant>()
          .toList();
      debugPrint('[Geoapify] loaded ${restaurants.length} nearby restaurants');
      return restaurants;
    } catch (error) {
      debugPrint('[Geoapify] fallback: $error');
      return const [];
    }
  }

  static Future<List<NearbyRestaurant>> _fetchGoogleRestaurants(
    AppLocation location,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(_googleNearbySearchUrl),
            headers: const {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _googleApiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.photos,places.currentOpeningHours.openNow,places.types',
            },
            body: jsonEncode({
              'includedTypes': ['restaurant', 'cafe', 'meal_takeaway'],
              'maxResultCount': 12,
              'rankPreference': 'DISTANCE',
              'locationRestriction': {
                'circle': {
                  'center': {
                    'latitude': location.latitude,
                    'longitude': location.longitude,
                  },
                  'radius': 3500.0,
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[Places] failed ${response.statusCode}: ${response.body}');
        return const [];
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final places = payload['places'] as List<dynamic>? ?? const [];
      final restaurants = places
          .map((raw) => _restaurantFromPlace(raw as Map<String, dynamic>))
          .whereType<NearbyRestaurant>()
          .toList();
      debugPrint('[Places] loaded ${restaurants.length} nearby restaurants');
      return restaurants;
    } catch (error) {
      debugPrint('[Places] fallback: $error');
      return const [];
    }
  }

  static NearbyRestaurant? _restaurantFromPlace(Map<String, dynamic> place) {
    final location = place['location'] as Map<String, dynamic>?;
    final latitude = (location?['latitude'] as num?)?.toDouble();
    final longitude = (location?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }

    final photos = place['photos'] as List<dynamic>?;
    final firstPhoto = photos == null || photos.isEmpty
        ? null
        : photos.first as Map<String, dynamic>?;
    final photoName = firstPhoto?['name'] as String?;
    return NearbyRestaurant(
      id: place['id'] as String? ?? '${place['displayName']}',
      name:
          (place['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
          'Quán gần bạn',
      address: place['formattedAddress'] as String? ?? '',
      latitude: latitude,
      longitude: longitude,
      rating: (place['rating'] as num?)?.toDouble(),
      userRatingCount: (place['userRatingCount'] as num?)?.toInt(),
      photoUrl: photoName == null
          ? null
          : 'https://places.googleapis.com/v1/$photoName/media'
                '?maxWidthPx=500&maxHeightPx=500&key=$_googleApiKey',
      openNow:
          (place['currentOpeningHours'] as Map<String, dynamic>?)?['openNow']
              as bool? ??
          true,
      category: _googleCategory(place),
    );
  }

  static NearbyRestaurant? _restaurantFromGeoapify(
    Map<String, dynamic> feature,
  ) {
    final properties = feature['properties'] as Map<String, dynamic>?;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    final longitude =
        (properties?['lon'] as num?)?.toDouble() ??
        (coordinates != null && coordinates.isNotEmpty
            ? (coordinates[0] as num?)?.toDouble()
            : null);
    final latitude =
        (properties?['lat'] as num?)?.toDouble() ??
        (coordinates != null && coordinates.length > 1
            ? (coordinates[1] as num?)?.toDouble()
            : null);
    if (properties == null || latitude == null || longitude == null) {
      return null;
    }

    final name = (properties['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    final address =
        (properties['formatted'] as String?)?.trim() ??
        (properties['address_line2'] as String?)?.trim() ??
        '';
    final categories = (properties['categories'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();

    return NearbyRestaurant(
      id: properties['place_id'] as String? ?? '$latitude,$longitude,$name',
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      rating: null,
      userRatingCount: null,
      photoUrl: null,
      openNow: true,
      category: _geoapifyCategory(categories),
    );
  }

  static String _googleCategory(Map<String, dynamic> place) {
    final types = (place['types'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    if (types.any((item) => item.contains('cafe'))) {
      return 'cafe';
    }
    if (types.any((item) => item.contains('bakery'))) {
      return 'bakery';
    }
    if (types.any((item) => item.contains('meal_takeaway'))) {
      return 'fast_food';
    }
    return 'restaurant';
  }

  static String _geoapifyCategory(List<String> categories) {
    if (categories.any((item) => item.contains('cafe'))) {
      return 'cafe';
    }
    if (categories.any((item) => item.contains('fast_food'))) {
      return 'fast_food';
    }
    if (categories.any((item) => item.contains('food_court'))) {
      return 'food_court';
    }
    return 'restaurant';
  }

  static double distanceInKm({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(toLat - fromLat);
    final dLng = _toRadians(toLng - fromLng);
    final lat1 = _toRadians(fromLat);
    final lat2 = _toRadians(toLat);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;
}
