import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AppLocation {
  final double latitude;
  final double longitude;
  final String address;
  final bool isFallback;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isFallback,
  });

  static const fallback = AppLocation(
    latitude: 10.7843,
    longitude: 106.5682,
    address: 'Vĩnh Lộc A, Bình Chánh',
    isFallback: true,
  );
}

class LocationService {
  static const _geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

  static Future<AppLocation> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] service disabled');
        return await _lastKnownLocation(maxAge: const Duration(minutes: 10)) ??
            AppLocation.fallback;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[Location] permission denied');
        return await _lastKnownLocation(maxAge: const Duration(minutes: 10)) ??
            AppLocation.fallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: true,
          intervalDuration: Duration(seconds: 1),
          timeLimit: Duration(seconds: 15),
        ),
      );

      final address = await _reverseAddress(
        position.latitude,
        position.longitude,
      );

      debugPrint(
        '[Location] ${position.latitude}, ${position.longitude} - $address',
      );
      return AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        isFallback: false,
      );
    } catch (error) {
      debugPrint('[Location] fallback: $error');
      return await _lastKnownLocation(maxAge: const Duration(minutes: 10)) ??
          AppLocation.fallback;
    }
  }

  static Future<AppLocation?> _lastKnownLocation({Duration? maxAge}) async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      final timestamp = position.timestamp;
      if (maxAge != null && DateTime.now().difference(timestamp) > maxAge) {
        debugPrint('[Location] stale last known ignored: $timestamp');
        return null;
      }
      final address = await _reverseAddress(
        position.latitude,
        position.longitude,
      );
      debugPrint(
        '[Location] last known ${position.latitude}, ${position.longitude} - $address',
      );
      return AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        isFallback: false,
      );
    } catch (error) {
      debugPrint('[Location] last known failed: $error');
      return null;
    }
  }

  static Future<String> _reverseAddress(
    double latitude,
    double longitude,
  ) async {
    if (_geoapifyApiKey.trim().isNotEmpty) {
      final geoapifyAddress = await _reverseAddressWithGeoapify(
        latitude,
        longitude,
      );
      if (geoapifyAddress != null) {
        return geoapifyAddress;
      }
    }

    try {
      final places = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (places.isEmpty) {
        return AppLocation.fallback.address;
      }

      final place = places.first;
      final parts = <String?>[
        _joinStreet(place),
        place.name,
        place.street,
        place.thoroughfare,
        place.subLocality,
        place.subAdministrativeArea,
        place.locality,
        place.administrativeArea,
      ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
      final address = _uniqueParts(parts).join(', ');
      return address.isEmpty ? AppLocation.fallback.address : address;
    } catch (error) {
      debugPrint('[Location] reverse geocoding failed: $error');
      return AppLocation.fallback.address;
    }
  }

  static String? _joinStreet(Placemark place) {
    final houseNumber = place.subThoroughfare?.trim();
    final street = place.thoroughfare?.trim();
    if (houseNumber == null ||
        houseNumber.isEmpty ||
        street == null ||
        street.isEmpty) {
      return null;
    }
    return '$houseNumber $street';
  }

  static Future<String?> _reverseAddressWithGeoapify(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'lang': 'vi',
        'apiKey': _geoapifyApiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[Location] Geoapify reverse failed ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      if (features.isEmpty) {
        return null;
      }

      final properties =
          (features.first as Map<String, dynamic>)['properties']
              as Map<String, dynamic>?;
      final fallbackParts = <String?>[
        _joinGeoapifyStreet(properties),
        properties?['suburb'] as String?,
        properties?['district'] as String?,
        properties?['city'] as String?,
        properties?['state'] as String?,
      ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
      final detailedAddress = _uniqueParts(fallbackParts).join(', ');
      if (detailedAddress.isNotEmpty) {
        return detailedAddress;
      }

      final formatted = (properties?['formatted'] as String?)?.trim();
      if (formatted != null && formatted.isNotEmpty) {
        return formatted;
      }

      final addressLineParts = <String?>[
        properties?['address_line1'] as String?,
        properties?['address_line2'] as String?,
      ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
      final address = _uniqueParts(addressLineParts).join(', ');
      return address.isEmpty ? null : address;
    } catch (error) {
      debugPrint('[Location] Geoapify reverse fallback: $error');
      return null;
    }
  }

  static String? _joinGeoapifyStreet(Map<String, dynamic>? properties) {
    if (properties == null) return null;
    final houseNumber = (properties['housenumber'] as String?)?.trim();
    final street = (properties['street'] as String?)?.trim();
    if (houseNumber != null &&
        houseNumber.isNotEmpty &&
        street != null &&
        street.isNotEmpty) {
      return '$houseNumber $street';
    }
    return street?.isEmpty == true ? null : street;
  }

  static List<String> _uniqueParts(Iterable<String> parts) {
    final seen = <String>{};
    final compactParts = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.isNotEmpty && seen.add(normalized)) {
        compactParts.add(trimmed);
      }
    }
    return compactParts;
  }
}
