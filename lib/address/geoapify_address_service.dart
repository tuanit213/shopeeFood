import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../location/location_service.dart';

class AddressSuggestion {
  final String title;
  final String address;
  final double latitude;
  final double longitude;

  const AddressSuggestion({
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class GeoapifyAddressService {
  static const _apiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

  static bool get hasApiKey => _apiKey.trim().isNotEmpty;

  static Future<AddressSuggestion> reverse(
    double latitude,
    double longitude,
  ) async {
    if (!hasApiKey) {
      return AddressSuggestion(
        title: 'Vị trí đã chọn',
        address: AppLocation.fallback.address,
        latitude: latitude,
        longitude: longitude,
      );
    }

    try {
      final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'lang': 'vi',
        'apiKey': _apiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[Address] reverse failed ${response.statusCode}');
        return _fallback(latitude, longitude);
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      if (features.isEmpty) {
        return _fallback(latitude, longitude);
      }

      return _suggestionFromFeature(features.first as Map<String, dynamic>);
    } catch (error) {
      debugPrint('[Address] reverse fallback: $error');
      return _fallback(latitude, longitude);
    }
  }

  static Future<List<AddressSuggestion>> nearby(
    double latitude,
    double longitude, {
    int radiusMeters = 200,
  }) async {
    if (!hasApiKey) {
      return const [];
    }

    try {
      final uri = Uri.https('api.geoapify.com', '/v2/places', {
        'categories': 'education,commercial,office,building,public_transport',
        'filter': 'circle:$longitude,$latitude,$radiusMeters',
        'bias': 'proximity:$longitude,$latitude',
        'limit': '12',
        'apiKey': _apiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[Address] nearby failed ${response.statusCode}');
        return const [];
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      return features
          .map((raw) => _suggestionFromFeature(raw as Map<String, dynamic>))
          .where(
            (item) =>
                item.address.isNotEmpty && !_looksLikeHouseNumber(item.title),
          )
          .toList();
    } catch (error) {
      debugPrint('[Address] nearby fallback: $error');
      return const [];
    }
  }

  static AddressSuggestion _suggestionFromFeature(
    Map<String, dynamic> feature,
  ) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
    final longitude =
        (properties['lon'] as num?)?.toDouble() ??
        (coordinates.isNotEmpty ? (coordinates[0] as num).toDouble() : 0);
    final latitude =
        (properties['lat'] as num?)?.toDouble() ??
        (coordinates.length > 1 ? (coordinates[1] as num).toDouble() : 0);
    final name = _text(properties['name']);
    final address =
        _text(properties['formatted']) ??
        _text(properties['address_line2']) ??
        '';

    return AddressSuggestion(
      title: name == null || name.isEmpty ? 'Vị trí đã chọn' : name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _looksLikeHouseNumber(String value) {
    return RegExp(r'^\d+[a-zA-Z]?$').hasMatch(value.trim());
  }

  static AddressSuggestion _fallback(double latitude, double longitude) {
    return AddressSuggestion(
      title: 'Vị trí đã chọn',
      address: AppLocation.fallback.address,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
