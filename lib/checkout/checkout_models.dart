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

  const CheckoutOrder({
    required this.restaurant,
    required this.items,
    required this.address,
    required this.receiverName,
    required this.receiverPhone,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.paymentMethod = 'Tiền mặt',
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  int get deliveryFee => subtotal >= 80000 ? 0 : 15000;
  int get serviceFee => 3000;
  int get discount => subtotal >= 60000 ? 12000 : 0;
  int get total => subtotal + deliveryFee + serviceFee - discount;

  CheckoutOrder copyWith({String? paymentMethod, List<CartItem>? items}) {
    return CheckoutOrder(
      restaurant: restaurant,
      items: items ?? this.items,
      address: address,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
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
