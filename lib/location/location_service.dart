import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../address/address_repository.dart';

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

  /// Coi là "đủ tốt để dừng chờ ngay" — sai số bán kính (mét).
  static const _acceptableAccuracyMeters = 30.0;

  /// Ngưỡng tối đa vẫn chấp nhận một fix từ stream mà không cần đọc thêm.
  static const _coarseAccuracyMeters = 80.0;

  static Future<AppLocation> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] service disabled');
        final saved = await _savedDeliveryLocation();
        if (saved != null) return saved;
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
        final saved = await _savedDeliveryLocation();
        if (saved != null) return saved;
        return await _lastKnownLocation(maxAge: const Duration(minutes: 10)) ??
            AppLocation.fallback;
      }

      final position = await _readAccuratePosition();
      if (!_isWithinVietnamBounds(position.latitude, position.longitude)) {
        debugPrint(
          '[Location] ignored foreign coordinates: '
          '${position.latitude}, ${position.longitude}',
        );
        final saved = await _savedDeliveryLocation();
        return saved ?? AppLocation.fallback;
      }

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
      final saved = await _savedDeliveryLocation();
      if (saved != null) return saved;
      return await _lastKnownLocation(maxAge: const Duration(minutes: 10)) ??
          AppLocation.fallback;
    }
  }

  /// Lấy một điểm định vị CHÍNH XÁC khi mới mở app.
  ///
  /// Hai thay đổi quan trọng so với bản cũ:
  ///
  /// 1. `forceLocationManager: false` — dùng bộ định vị hợp nhất (fused) của
  ///    Google Play Services thay vì `LocationManager` thô của Android. Fused
  ///    kết hợp GPS + Wi-Fi + cảm biến nên ra toạ độ sát thực tế hơn nhiều;
  ///    `forceLocationManager: true` (bản cũ) bỏ qua lớp này nên điểm định vị
  ///    thường lệch vài trăm mét — đúng kiểu "định vị sai vị trí".
  ///
  /// 2. Không nhận ngay lần đọc đầu: lần fix GPS ĐẦU TIÊN sau khi mở app hay
  ///    còn "nguội" (accuracy hàng trăm mét). Hàm chờ tới khi có một điểm đủ
  ///    tốt (`accuracy <= _acceptableAccuracyMeters`) hoặc hết thời gian, rồi
  ///    lấy điểm tốt nhất đọc được — tránh ghim nhầm vào fix nguội đầu tiên.
  static Future<Position> _readAccuratePosition() async {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      forceLocationManager: false,
      intervalDuration: const Duration(seconds: 1),
      timeLimit: const Duration(seconds: 20),
    );

    Position? best;
    try {
      final stream = Geolocator.getPositionStream(locationSettings: settings);
      await for (final position in stream.timeout(
        const Duration(seconds: 12),
      )) {
        if (best == null || position.accuracy < best.accuracy) {
          best = position;
        }
        if (position.accuracy <= _acceptableAccuracyMeters) {
          break;
        }
      }
    } catch (error) {
      debugPrint('[Location] stream dừng sớm: $error');
    }

    if (best != null && best.accuracy <= _coarseAccuracyMeters) {
      debugPrint('[Location] fix tốt: ±${best.accuracy.toStringAsFixed(0)}m');
      return best;
    }

    // Chưa có fix đủ tốt trong thời gian chờ: đọc thêm một điểm dứt khoát và
    // giữ điểm nào chính xác hơn.
    final single = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    );
    if (best == null || single.accuracy < best.accuracy) {
      return single;
    }
    return best;
  }

  static Future<AppLocation?> _savedDeliveryLocation() async {
    try {
      final selected = await AddressRepository.loadSelectedAddress();
      if (selected == null ||
          selected.latitude == 0 ||
          selected.longitude == 0 ||
          selected.displayAddress.isEmpty) {
        return null;
      }
      return AppLocation(
        latitude: selected.latitude,
        longitude: selected.longitude,
        address: selected.displayAddress,
        isFallback: false,
      );
    } catch (error) {
      debugPrint('[Location] saved address fallback failed: $error');
      return null;
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
      if (!_isWithinVietnamBounds(position.latitude, position.longitude)) {
        debugPrint(
          '[Location] foreign last known ignored: '
          '${position.latitude}, ${position.longitude}',
        );
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

      final formatted = _sanitizeAddressLine(
        (properties?['formatted'] as String?)?.trim(),
      );
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

  /// Làm sạch một chuỗi địa chỉ đã ghép sẵn (VD `formatted` của Geoapify hay
  /// bất kỳ chuỗi nào tách được bằng dấu phẩy): tách theo dấu phẩy rồi chạy
  /// [_uniqueParts] để bỏ đoạn trùng/tập con, token quốc gia và mã bưu chính.
  static String? _sanitizeAddressLine(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(',');
    final cleaned = _uniqueParts(parts).join(', ');
    return cleaned.isEmpty ? null : cleaned;
  }

  @visibleForTesting
  static String? sanitizeAddressForTesting(String? raw) =>
      _sanitizeAddressLine(raw);

  @visibleForTesting
  static bool isWithinVietnamBoundsForTesting(
    double latitude,
    double longitude,
  ) {
    return _isWithinVietnamBounds(latitude, longitude);
  }

  static bool _isWithinVietnamBounds(double latitude, double longitude) {
    return latitude >= 8.0 &&
        latitude <= 23.5 &&
        longitude >= 102.0 &&
        longitude <= 110.5;
  }

  static List<String> _uniqueParts(Iterable<String> parts) {
    // Bước 1: lọc rỗng + bỏ token quốc gia và mã bưu chính (địa chỉ trong
    // nước không cần), vì `formatted` hay kèm cả hai.
    final cleaned = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      if (lower == 'vietnam' || lower == 'việt nam' || lower == 'viet nam') {
        continue;
      }
      if (RegExp(r'^\d{5,6}$').hasMatch(trimmed)) {
        continue;
      }
      cleaned.add(trimmed);
    }

    // Bước 2: bỏ phần con trùng lặp. Reverse geocoding hay trả cả "Đường 1B"
    // lẫn "18Y Đường 1B", cả "Hồ Chí Minh" lẫn "Thành phố Hồ Chí Minh" — giữ
    // lại đoạn ĐẦY ĐỦ hơn, bỏ đoạn ngắn nằm gọn trong đoạn kia (so khớp theo
    // ranh giới từ để "1B" không vô tình khớp "18Y").
    final compactParts = <String>[];
    for (final part in cleaned) {
      final lower = part.toLowerCase();
      final redundant = cleaned.any((other) {
        if (identical(other, part)) return false;
        final otherLower = other.toLowerCase();
        if (otherLower == lower) {
          // Trùng y hệt: chỉ giữ lần xuất hiện đầu tiên.
          return cleaned.indexOf(other) < cleaned.indexOf(part);
        }
        // `part` là tập con của `other` -> bỏ `part`, giữ `other` dài hơn.
        return otherLower.contains(lower) &&
            RegExp(
              r'(^|\s)' + RegExp.escape(lower) + r'($|\s)',
            ).hasMatch(otherLower);
      });
      if (!redundant) {
        compactParts.add(part);
      }
    }
    return compactParts;
  }
}
