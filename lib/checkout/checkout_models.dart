class CheckoutRestaurantInfo {
  final String id;
  final String name;
  final String address;
  final int deliveryMinutes;
  final double distanceKm;
  final double? latitude;
  final double? longitude;

  const CheckoutRestaurantInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.deliveryMinutes,
    required this.distanceKm,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'deliveryMinutes': deliveryMinutes,
      'distanceKm': distanceKm,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory CheckoutRestaurantInfo.fromJson(Map<String, dynamic> json) {
    return CheckoutRestaurantInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      deliveryMinutes: (json['deliveryMinutes'] as num?)?.toInt() ?? 20,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class CartItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int unitPrice;
  final int quantity;
  final List<String> toppings;
  final String note;

  const CartItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.toppings,
    required this.note,
  });

  int get toppingTotal => toppings.length * 5000;
  int get lineTotal => (unitPrice + toppingTotal) * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'toppings': toppings,
      'note': note,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      toppings:
          (json['toppings'] as List<dynamic>?)?.whereType<String>().toList() ??
          const <String>[],
      note: json['note'] as String? ?? '',
    );
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      toppings: toppings,
      note: note,
    );
  }
}

class CheckoutOrder {
  final CheckoutRestaurantInfo restaurant;
  final List<CartItem> items;
  final String address;
  final String receiverName;
  final String receiverPhone;
  final String paymentMethod;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String deliveryTimeLabel;
  final String orderNote;
  final bool useCutlery;
  final int driverTip;
  final int voucherDiscount;

  const CheckoutOrder({
    required this.restaurant,
    required this.items,
    required this.address,
    required this.receiverName,
    required this.receiverPhone,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryTimeLabel = '',
    this.paymentMethod = 'Tiền mặt',
    this.orderNote = '',
    this.useCutlery = false,
    this.driverTip = 0,
    this.voucherDiscount = 0,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  int get deliveryFee => subtotal >= 80000 ? 0 : 15000;
  int get serviceFee => 3000;
  int get automaticDiscount => subtotal >= 60000 ? 12000 : 0;
  int get discount => automaticDiscount + voucherDiscount;
  int get total => subtotal + deliveryFee + serviceFee + driverTip - discount;

  Map<String, dynamic> toJson() {
    return {
      'restaurant': restaurant.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'address': address,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'paymentMethod': paymentMethod,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryTimeLabel': deliveryTimeLabel,
      'orderNote': orderNote,
      'useCutlery': useCutlery,
      'driverTip': driverTip,
      'voucherDiscount': voucherDiscount,
    };
  }

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return CheckoutOrder(
      restaurant: CheckoutRestaurantInfo.fromJson(
        json['restaurant'] as Map<String, dynamic>? ?? const {},
      ),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(CartItem.fromJson)
          .toList(),
      address: json['address'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? '',
      receiverPhone: json['receiverPhone'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? 'Tiền mặt',
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      deliveryTimeLabel: json['deliveryTimeLabel'] as String? ?? '',
      orderNote: json['orderNote'] as String? ?? '',
      useCutlery: json['useCutlery'] as bool? ?? false,
      driverTip: (json['driverTip'] as num?)?.toInt() ?? 0,
      voucherDiscount: (json['voucherDiscount'] as num?)?.toInt() ?? 0,
    );
  }

  CheckoutOrder copyWith({
    String? paymentMethod,
    List<CartItem>? items,
    String? address,
    String? receiverName,
    String? receiverPhone,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryTimeLabel,
    String? orderNote,
    bool? useCutlery,
    int? driverTip,
    int? voucherDiscount,
  }) {
    return CheckoutOrder(
      restaurant: restaurant,
      items: items ?? this.items,
      address: address ?? this.address,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryTimeLabel: deliveryTimeLabel ?? this.deliveryTimeLabel,
      orderNote: orderNote ?? this.orderNote,
      useCutlery: useCutlery ?? this.useCutlery,
      driverTip: driverTip ?? this.driverTip,
      voucherDiscount: voucherDiscount ?? this.voucherDiscount,
    );
  }
}

String checkoutFormatPrice(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[i]);
  }
  return '${buffer.toString()}đ';
}
