import '../address/delivery_address_v2.dart';
import '../common/json_helpers.dart';

enum CatalogStatus { draft, active, inactive, suspended }

class RestaurantV2 {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final String coverUrl;
  final List<String> categories;
  final double rating;
  final int ratingCount;
  final bool verified;
  final CatalogStatus status;
  final List<String> merchantIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantV2({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.coverUrl,
    required this.categories,
    required this.rating,
    required this.ratingCount,
    required this.verified,
    required this.status,
    required this.merchantIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RestaurantV2.fromJson(Map<String, dynamic> json) => RestaurantV2(
    id: readString(json['id']),
    name: readString(json['name']),
    description: readString(json['description']),
    logoUrl: readString(json['logoUrl']),
    coverUrl: readString(json['coverUrl']),
    categories: readStringList(json['categories']),
    rating: readDouble(json['rating']),
    ratingCount: readInt(json['ratingCount']),
    verified: json['verified'] as bool? ?? false,
    status: readEnum(json['status'], CatalogStatus.values, CatalogStatus.draft),
    merchantIds: readStringList(json['merchantIds']),
    createdAt: readDateTime(json['createdAt']),
    updatedAt: readDateTime(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'logoUrl': logoUrl,
    'coverUrl': coverUrl,
    'categories': categories,
    'rating': rating,
    'ratingCount': ratingCount,
    'verified': verified,
    'status': status.name,
    'merchantIds': merchantIds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class OpeningHours {
  final String day;
  final String opensAt;
  final String closesAt;
  final bool closed;

  const OpeningHours({
    required this.day,
    required this.opensAt,
    required this.closesAt,
    this.closed = false,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
    day: readString(json['day']),
    opensAt: readString(json['opensAt']),
    closesAt: readString(json['closesAt']),
    closed: json['closed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'opensAt': opensAt,
    'closesAt': closesAt,
    'closed': closed,
  };
}

class RestaurantBranch {
  final String id;
  final String restaurantId;
  final String name;
  final String formattedAddress;
  final AddressComponents addressComponents;
  final double latitude;
  final double longitude;

  /// Nullable until a geospatial service computes an index.
  final String? geohash;

  /// Nullable when the branch was entered without an external place provider.
  final String? externalPlaceId;
  final String phone;
  final List<OpeningHours> openingHours;
  final bool deliveryEnabled;
  final double maxDeliveryRadiusKm;
  final int preparationMinutes;
  final CatalogStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantBranch({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.formattedAddress,
    required this.addressComponents,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.openingHours,
    required this.deliveryEnabled,
    required this.maxDeliveryRadiusKm,
    required this.preparationMinutes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.geohash,
    this.externalPlaceId,
  });

  factory RestaurantBranch.fromJson(Map<String, dynamic> json) =>
      RestaurantBranch(
        id: readString(json['id']),
        restaurantId: readString(json['restaurantId']),
        name: readString(json['name']),
        formattedAddress: readString(json['formattedAddress']),
        addressComponents: AddressComponents.fromJson(
          readMap(json['addressComponents']),
        ),
        latitude: readDouble(json['latitude']),
        longitude: readDouble(json['longitude']),
        geohash: json['geohash'] as String?,
        externalPlaceId: json['externalPlaceId'] as String?,
        phone: readString(json['phone']),
        openingHours: readMapList(
          json['openingHours'],
        ).map(OpeningHours.fromJson).toList(growable: false),
        deliveryEnabled: json['deliveryEnabled'] as bool? ?? false,
        maxDeliveryRadiusKm: readDouble(json['maxDeliveryRadiusKm']),
        preparationMinutes: readInt(json['preparationMinutes']),
        status: readEnum(
          json['status'],
          CatalogStatus.values,
          CatalogStatus.draft,
        ),
        createdAt: readDateTime(json['createdAt']),
        updatedAt: readDateTime(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurantId': restaurantId,
    'name': name,
    'formattedAddress': formattedAddress,
    'addressComponents': addressComponents.toJson(),
    'latitude': latitude,
    'longitude': longitude,
    'geohash': geohash,
    'externalPlaceId': externalPlaceId,
    'phone': phone,
    'openingHours': openingHours.map((item) => item.toJson()).toList(),
    'deliveryEnabled': deliveryEnabled,
    'maxDeliveryRadiusKm': maxDeliveryRadiusKm,
    'preparationMinutes': preparationMinutes,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
