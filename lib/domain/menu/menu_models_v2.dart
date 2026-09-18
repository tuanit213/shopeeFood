import '../common/json_helpers.dart';

enum MenuImageSource { asset, merchant, provider, generated, unknown }

class MenuSectionV2 {
  final String id;
  final String branchId;
  final String name;
  final int sortOrder;
  final bool available;

  const MenuSectionV2({
    required this.id,
    required this.branchId,
    required this.name,
    required this.sortOrder,
    required this.available,
  });

  factory MenuSectionV2.fromJson(Map<String, dynamic> json) => MenuSectionV2(
    id: readString(json['id']),
    branchId: readString(json['branchId']),
    name: readString(json['name']),
    sortOrder: readInt(json['sortOrder']),
    available: json['available'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'name': name,
    'sortOrder': sortOrder,
    'available': available,
  };
}

class MenuItemV2 {
  final String id;
  final String restaurantId;
  final String branchId;
  final String sectionId;
  final String name;
  final String description;
  final int price;
  final String imageUrl;
  final String thumbnailUrl;
  final MenuImageSource imageSource;
  final bool available;
  final List<String> optionGroupIds;
  final int soldCount;
  final double rating;
  final bool verified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuItemV2({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.sectionId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.imageSource,
    required this.available,
    required this.optionGroupIds,
    required this.soldCount,
    required this.rating,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuItemV2.fromJson(Map<String, dynamic> json) => MenuItemV2(
    id: readString(json['id']),
    restaurantId: readString(json['restaurantId']),
    branchId: readString(json['branchId']),
    sectionId: readString(json['sectionId']),
    name: readString(json['name']),
    description: readString(json['description']),
    price: readInt(json['price']),
    imageUrl: readString(json['imageUrl']),
    thumbnailUrl: readString(json['thumbnailUrl']),
    imageSource: readEnum(
      json['imageSource'],
      MenuImageSource.values,
      MenuImageSource.unknown,
    ),
    available: json['available'] as bool? ?? false,
    optionGroupIds: readStringList(json['optionGroupIds']),
    soldCount: readInt(json['soldCount']),
    rating: readDouble(json['rating']),
    verified: json['verified'] as bool? ?? false,
    createdAt: readDateTime(json['createdAt']),
    updatedAt: readDateTime(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurantId': restaurantId,
    'branchId': branchId,
    'sectionId': sectionId,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'thumbnailUrl': thumbnailUrl,
    'imageSource': imageSource.name,
    'available': available,
    'optionGroupIds': optionGroupIds,
    'soldCount': soldCount,
    'rating': rating,
    'verified': verified,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class OptionItemV2 {
  final String id;
  final String name;
  final int priceDelta;
  final bool available;

  const OptionItemV2({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.available,
  });

  factory OptionItemV2.fromJson(Map<String, dynamic> json) => OptionItemV2(
    id: readString(json['id']),
    name: readString(json['name']),
    priceDelta: readInt(json['priceDelta']),
    available: json['available'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceDelta': priceDelta,
    'available': available,
  };
}

class OptionGroupV2 {
  final String id;
  final String name;
  final bool required;
  final int minSelections;
  final int maxSelections;
  final List<OptionItemV2> items;

  const OptionGroupV2({
    required this.id,
    required this.name,
    required this.required,
    required this.minSelections,
    required this.maxSelections,
    required this.items,
  });

  factory OptionGroupV2.fromJson(Map<String, dynamic> json) => OptionGroupV2(
    id: readString(json['id']),
    name: readString(json['name']),
    required: json['required'] as bool? ?? false,
    minSelections: readInt(json['minSelections']),
    maxSelections: readInt(json['maxSelections']),
    items: readMapList(
      json['items'],
    ).map(OptionItemV2.fromJson).toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'required': required,
    'minSelections': minSelections,
    'maxSelections': maxSelections,
    'items': items.map((item) => item.toJson()).toList(),
  };
}
