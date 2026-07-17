import 'package:flutter/foundation.dart';

import '../checkout/checkout_models.dart';

enum OrderStatus { cart, delivering }

class OrderEntry {
  final CheckoutOrder order;
  final OrderStatus status;
  final DateTime updatedAt;

  const OrderEntry({
    required this.order,
    required this.status,
    required this.updatedAt,
  });

  OrderEntry copyWith({CheckoutOrder? order, OrderStatus? status}) {
    return OrderEntry(
      order: order ?? this.order,
      status: status ?? this.status,
      updatedAt: DateTime.now(),
    );
  }
}

class OrderState {
  static final ValueNotifier<List<OrderEntry>> entries =
      ValueNotifier<List<OrderEntry>>(<OrderEntry>[]);

  static void upsertCart(CheckoutOrder order) {
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) =>
          entry.status == OrderStatus.cart &&
          entry.order.restaurant.id == order.restaurant.id,
    );
    final next = OrderEntry(
      order: order,
      status: OrderStatus.cart,
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      current[index] = next;
    } else {
      current.insert(0, next);
    }
    entries.value = current;
  }

  static CheckoutOrder mergeCartItem(CheckoutOrder order) {
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) =>
          entry.status == OrderStatus.cart &&
          entry.order.restaurant.id == order.restaurant.id,
    );

    if (index < 0) {
      final next = OrderEntry(
        order: order,
        status: OrderStatus.cart,
        updatedAt: DateTime.now(),
      );
      current.insert(0, next);
      entries.value = current;
      return order;
    }

    final existing = current[index];
    final mergedItems = List<CartItem>.of(existing.order.items);
    for (final incoming in order.items) {
      final itemIndex = mergedItems.indexWhere(
        (item) => _sameCartLine(item, incoming),
      );
      if (itemIndex >= 0) {
        final oldItem = mergedItems[itemIndex];
        mergedItems[itemIndex] = oldItem.copyWith(
          quantity: oldItem.quantity + incoming.quantity,
        );
      } else {
        mergedItems.add(incoming);
      }
    }

    final mergedOrder = existing.order.copyWith(items: mergedItems);
    current[index] = OrderEntry(
      order: mergedOrder,
      status: OrderStatus.cart,
      updatedAt: DateTime.now(),
    );
    entries.value = current;
    return mergedOrder;
  }

  static void markDelivering(CheckoutOrder order) {
    final current = List<OrderEntry>.of(entries.value)
      ..removeWhere(
        (entry) =>
            entry.status == OrderStatus.cart &&
            entry.order.restaurant.id == order.restaurant.id,
      );
    current.insert(
      0,
      OrderEntry(
        order: order,
        status: OrderStatus.delivering,
        updatedAt: DateTime.now(),
      ),
    );
    entries.value = current;
  }

  static void removeCart(String restaurantId) {
    final current = List<OrderEntry>.of(entries.value)
      ..removeWhere(
        (entry) =>
            entry.status == OrderStatus.cart &&
            entry.order.restaurant.id == restaurantId,
      );
    entries.value = current;
  }

  static bool _sameCartLine(CartItem a, CartItem b) {
    return a.id == b.id &&
        a.note == b.note &&
        _sameStringList(a.toppings, b.toppings);
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
