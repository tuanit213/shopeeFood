import '../address/delivery_address_v2.dart';
import '../common/json_helpers.dart';
import '../catalog/restaurant_v2.dart';

enum OrderStatus {
  placed,
  restaurantConfirmed,
  preparing,
  searchingDriver,
  driverAssigned,
  driverToRestaurant,
  driverArrivedRestaurant,
  pickedUp,
  driverToCustomer,
  driverArrivedCustomer,
  delivered,
  cancelled,
}

extension OrderStatusWireName on OrderStatus {
  String get wireName => switch (this) {
    OrderStatus.placed => 'placed',
    OrderStatus.restaurantConfirmed => 'restaurant_confirmed',
    OrderStatus.preparing => 'preparing',
    OrderStatus.searchingDriver => 'searching_driver',
    OrderStatus.driverAssigned => 'driver_assigned',
    OrderStatus.driverToRestaurant => 'driver_to_restaurant',
    OrderStatus.driverArrivedRestaurant => 'driver_arrived_restaurant',
    OrderStatus.pickedUp => 'picked_up',
    OrderStatus.driverToCustomer => 'driver_to_customer',
    OrderStatus.driverArrivedCustomer => 'driver_arrived_customer',
    OrderStatus.delivered => 'delivered',
    OrderStatus.cancelled => 'cancelled',
  };

  static OrderStatus fromWireName(Object? value) =>
      OrderStatus.values.firstWhere(
        (status) => status.wireName == value,
        orElse: () => OrderStatus.placed,
      );
}

class OrderItemSnapshot {
  final String menuItemId;
  final String nameSnapshot;
  final int priceSnapshot;
  final String imageSnapshot;
  final List<Map<String, dynamic>> optionsSnapshot;
  final int quantity;
  final int lineTotalSnapshot;

  const OrderItemSnapshot({
    required this.menuItemId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.imageSnapshot,
    required this.optionsSnapshot,
    required this.quantity,
    required this.lineTotalSnapshot,
  });

  factory OrderItemSnapshot.fromJson(Map<String, dynamic> json) =>
      OrderItemSnapshot(
        menuItemId: readString(json['menuItemId']),
        nameSnapshot: readString(json['nameSnapshot']),
        priceSnapshot: readInt(json['priceSnapshot']),
        imageSnapshot: readString(json['imageSnapshot']),
        optionsSnapshot: readMapList(json['optionsSnapshot']),
        quantity: readInt(json['quantity'], fallback: 1),
        lineTotalSnapshot: readInt(json['lineTotalSnapshot']),
      );

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'nameSnapshot': nameSnapshot,
    'priceSnapshot': priceSnapshot,
    'imageSnapshot': imageSnapshot,
    'optionsSnapshot': optionsSnapshot,
    'quantity': quantity,
    'lineTotalSnapshot': lineTotalSnapshot,
  };
}

class PricingSnapshot {
  final int subtotal;
  final int deliveryFee;
  final int serviceFee;
  final int driverTip;
  final int discount;
  final int total;

  const PricingSnapshot({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.driverTip,
    required this.discount,
    required this.total,
  });

  factory PricingSnapshot.fromJson(Map<String, dynamic> json) =>
      PricingSnapshot(
        subtotal: readInt(json['subtotal']),
        deliveryFee: readInt(json['deliveryFee']),
        serviceFee: readInt(json['serviceFee']),
        driverTip: readInt(json['driverTip']),
        discount: readInt(json['discount']),
        total: readInt(json['total']),
      );

  Map<String, dynamic> toJson() => {
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'serviceFee': serviceFee,
    'driverTip': driverTip,
    'discount': discount,
    'total': total,
  };
}

class DeliverySnapshot {
  final int? distanceMeters;
  final int? estimatedDurationSeconds;
  final DateTime? pickupEta;
  final DateTime? deliveryEta;

  /// These values are nullable because ETA/distance are not authoritative in Phase 1.
  const DeliverySnapshot({
    this.distanceMeters,
    this.estimatedDurationSeconds,
    this.pickupEta,
    this.deliveryEta,
  });

  factory DeliverySnapshot.fromJson(Map<String, dynamic> json) =>
      DeliverySnapshot(
        distanceMeters: json['distanceMeters'] is num
            ? (json['distanceMeters'] as num).toInt()
            : null,
        estimatedDurationSeconds: json['estimatedDurationSeconds'] is num
            ? (json['estimatedDurationSeconds'] as num).toInt()
            : null,
        pickupEta: readNullableDateTime(json['pickupEta']),
        deliveryEta: readNullableDateTime(json['deliveryEta']),
      );

  Map<String, dynamic> toJson() => {
    'distanceMeters': distanceMeters,
    'estimatedDurationSeconds': estimatedDurationSeconds,
    'pickupEta': pickupEta?.toUtc().toIso8601String(),
    'deliveryEta': deliveryEta?.toUtc().toIso8601String(),
  };
}

class OrderTimeline {
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? driverAssignedAt;
  final DateTime? driverArrivedRestaurantAt;
  final DateTime? pickedUpAt;
  final DateTime? driverArrivedCustomerAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  const OrderTimeline({
    this.createdAt,
    this.confirmedAt,
    this.driverAssignedAt,
    this.driverArrivedRestaurantAt,
    this.pickedUpAt,
    this.driverArrivedCustomerAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  factory OrderTimeline.fromJson(Map<String, dynamic> json) => OrderTimeline(
    createdAt: readNullableDateTime(json['createdAt']),
    confirmedAt: readNullableDateTime(json['confirmedAt']),
    driverAssignedAt: readNullableDateTime(json['driverAssignedAt']),
    driverArrivedRestaurantAt: readNullableDateTime(
      json['driverArrivedRestaurantAt'],
    ),
    pickedUpAt: readNullableDateTime(json['pickedUpAt']),
    driverArrivedCustomerAt: readNullableDateTime(
      json['driverArrivedCustomerAt'],
    ),
    deliveredAt: readNullableDateTime(json['deliveredAt']),
    cancelledAt: readNullableDateTime(json['cancelledAt']),
  );

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'confirmedAt': confirmedAt?.toUtc().toIso8601String(),
    'driverAssignedAt': driverAssignedAt?.toUtc().toIso8601String(),
    'driverArrivedRestaurantAt': driverArrivedRestaurantAt
        ?.toUtc()
        .toIso8601String(),
    'pickedUpAt': pickedUpAt?.toUtc().toIso8601String(),
    'driverArrivedCustomerAt': driverArrivedCustomerAt
        ?.toUtc()
        .toIso8601String(),
    'deliveredAt': deliveredAt?.toUtc().toIso8601String(),
    'cancelledAt': cancelledAt?.toUtc().toIso8601String(),
  };
}

class OrderV2 {
  final String id;
  final String customerId;
  final String restaurantId;
  final String branchId;
  final String? driverId;
  final OrderStatus status;
  final int statusVersion;
  final List<OrderItemSnapshot> items;
  final DeliveryAddressV2 deliveryAddressSnapshot;
  final RestaurantV2 restaurantSnapshot;
  final PricingSnapshot pricing;
  final DeliverySnapshot delivery;
  final OrderTimeline timeline;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Driver assignment is nullable until a trusted backend assigns a driver.
  const OrderV2({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    required this.branchId,
    required this.status,
    required this.statusVersion,
    required this.items,
    required this.deliveryAddressSnapshot,
    required this.restaurantSnapshot,
    required this.pricing,
    required this.delivery,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    this.driverId,
  });

  factory OrderV2.fromJson(Map<String, dynamic> json) => OrderV2(
    id: readString(json['id']),
    customerId: readString(json['customerId']),
    restaurantId: readString(json['restaurantId']),
    branchId: readString(json['branchId']),
    driverId: json['driverId'] as String?,
    status: OrderStatusWireName.fromWireName(json['status']),
    statusVersion: readInt(json['statusVersion'], fallback: 1),
    items: readMapList(
      json['items'],
    ).map(OrderItemSnapshot.fromJson).toList(growable: false),
    deliveryAddressSnapshot: DeliveryAddressV2.fromJson(
      readMap(json['deliveryAddressSnapshot']),
    ),
    restaurantSnapshot: RestaurantV2.fromJson(
      readMap(json['restaurantSnapshot']),
    ),
    pricing: PricingSnapshot.fromJson(readMap(json['pricing'])),
    delivery: DeliverySnapshot.fromJson(readMap(json['delivery'])),
    timeline: OrderTimeline.fromJson(readMap(json['timeline'])),
    createdAt: readDateTime(json['createdAt']),
    updatedAt: readDateTime(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'restaurantId': restaurantId,
    'branchId': branchId,
    'driverId': driverId,
    'status': status.wireName,
    'statusVersion': statusVersion,
    'items': items.map((item) => item.toJson()).toList(),
    'deliveryAddressSnapshot': deliveryAddressSnapshot.toJson(),
    'restaurantSnapshot': restaurantSnapshot.toJson(),
    'pricing': pricing.toJson(),
    'delivery': delivery.toJson(),
    'timeline': timeline.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
