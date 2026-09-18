import '../common/json_helpers.dart';

enum AddressSource { manual, deviceLocation, placeProvider, legacy }

class AddressComponents {
  final String houseNumber;
  final String street;
  final String ward;
  final String district;
  final String city;

  const AddressComponents({
    this.houseNumber = '',
    this.street = '',
    this.ward = '',
    this.district = '',
    this.city = '',
  });

  factory AddressComponents.fromJson(Map<String, dynamic> json) =>
      AddressComponents(
        houseNumber: readString(json['houseNumber']),
        street: readString(json['street']),
        ward: readString(json['ward']),
        district: readString(json['district']),
        city: readString(json['city']),
      );

  Map<String, dynamic> toJson() => {
    'houseNumber': houseNumber,
    'street': street,
    'ward': ward,
    'district': district,
    'city': city,
  };
}

class AddressLocation {
  final double latitude;
  final double longitude;

  /// Nullable when the source did not expose device/provider accuracy.
  final double? accuracyMeters;

  /// Nullable until a server or geospatial service computes an index.
  final String? geohash;

  const AddressLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.geohash,
  });

  factory AddressLocation.fromJson(Map<String, dynamic> json) =>
      AddressLocation(
        latitude: readDouble(json['latitude']),
        longitude: readDouble(json['longitude']),
        accuracyMeters: json['accuracyMeters'] is num
            ? (json['accuracyMeters'] as num).toDouble()
            : null,
        geohash: json['geohash'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'geohash': geohash,
  };
}

class DeliveryAddressV2 {
  final String id;
  final String label;
  final String receiverName;
  final String receiverPhone;
  final String formattedAddress;
  final AddressComponents addressComponents;
  final AddressLocation location;

  /// Optional provider/building details are absent for manually entered data.
  final String? placeId;
  final String? building;
  final String? floor;
  final String? unit;
  final String? gate;
  final String? note;
  final AddressSource source;
  final bool verified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeliveryAddressV2({
    required this.id,
    required this.label,
    required this.receiverName,
    required this.receiverPhone,
    required this.formattedAddress,
    required this.addressComponents,
    required this.location,
    required this.source,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
    this.placeId,
    this.building,
    this.floor,
    this.unit,
    this.gate,
    this.note,
  });

  factory DeliveryAddressV2.fromJson(Map<String, dynamic> json) =>
      DeliveryAddressV2(
        id: readString(json['id']),
        label: readString(json['label']),
        receiverName: readString(json['receiverName']),
        receiverPhone: readString(json['receiverPhone']),
        formattedAddress: readString(json['formattedAddress']),
        addressComponents: AddressComponents.fromJson(
          readMap(json['addressComponents']),
        ),
        location: AddressLocation.fromJson(readMap(json['location'])),
        placeId: json['placeId'] as String?,
        building: json['building'] as String?,
        floor: json['floor'] as String?,
        unit: json['unit'] as String?,
        gate: json['gate'] as String?,
        note: json['note'] as String?,
        source: readEnum(
          json['source'],
          AddressSource.values,
          AddressSource.manual,
        ),
        verified: json['verified'] as bool? ?? false,
        createdAt: readDateTime(json['createdAt']),
        updatedAt: readDateTime(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'receiverName': receiverName,
    'receiverPhone': receiverPhone,
    'formattedAddress': formattedAddress,
    'addressComponents': addressComponents.toJson(),
    'location': location.toJson(),
    'placeId': placeId,
    'building': building,
    'floor': floor,
    'unit': unit,
    'gate': gate,
    'note': note,
    'source': source.name,
    'verified': verified,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  DeliveryAddressV2 copyWith({
    String? label,
    String? receiverName,
    String? receiverPhone,
    String? formattedAddress,
    AddressComponents? addressComponents,
    AddressLocation? location,
    String? placeId,
    String? building,
    String? floor,
    String? unit,
    String? gate,
    String? note,
    AddressSource? source,
    bool? verified,
    DateTime? updatedAt,
  }) {
    return DeliveryAddressV2(
      id: id,
      label: label ?? this.label,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      addressComponents: addressComponents ?? this.addressComponents,
      location: location ?? this.location,
      placeId: placeId ?? this.placeId,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      unit: unit ?? this.unit,
      gate: gate ?? this.gate,
      note: note ?? this.note,
      source: source ?? this.source,
      verified: verified ?? this.verified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
