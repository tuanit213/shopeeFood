import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../checkout/checkout_models.dart';

enum OrderStatus { cart, delivering, delivered, rated }

int _entrySequence = 0;

class OrderEntry {
  final String id;
  final CheckoutOrder order;
  final OrderStatus status;
  final DateTime updatedAt;
  final int? shopRating;
  final int? driverRating;

  const OrderEntry({
    this.id = '',
    required this.order,
    required this.status,
    required this.updatedAt,
    this.shopRating,
    this.driverRating,
  });

  OrderEntry copyWith({
    CheckoutOrder? order,
    OrderStatus? status,
    int? shopRating,
    int? driverRating,
  }) {
    return OrderEntry(
      id: id,
      order: order ?? this.order,
      status: status ?? this.status,
      updatedAt: DateTime.now(),
      shopRating: shopRating ?? this.shopRating,
      driverRating: driverRating ?? this.driverRating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order.toJson(),
      'status': status.name,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'shopRating': shopRating,
      'driverRating': driverRating,
    };
  }

  factory OrderEntry.fromJson(Map<String, dynamic> json) {
    final order = CheckoutOrder.fromJson(
      json['order'] as Map<String, dynamic>? ?? const {},
    );
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
    return OrderEntry(
      id: _entryIdFromJson(json, order, updatedAt),
      order: order,
      status: OrderStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => OrderStatus.cart,
      ),
      updatedAt: updatedAt,
      shopRating: (json['shopRating'] as num?)?.toInt(),
      driverRating: (json['driverRating'] as num?)?.toInt(),
    );
  }
}

class OrderState {
  static const _prefsKey = 'shopeefood_order_state_entries_v1';

  static final ValueNotifier<List<OrderEntry>> entries =
      ValueNotifier<List<OrderEntry>>(<OrderEntry>[]);

  static Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final payload = jsonDecode(raw) as List<dynamic>;
      entries.value = payload
          .whereType<Map<String, dynamic>>()
          .map(OrderEntry.fromJson)
          .where((entry) => entry.order.restaurant.id.isNotEmpty)
          .where((entry) => entry.order.items.isNotEmpty)
          .toList();
    } catch (error) {
      debugPrint('[OrderState] bad persisted state: $error');
      await prefs.remove(_prefsKey);
    }
  }

  static Future<void> persist() => _persistEntries(entries.value);

  static Future<void> clearPersisted() async {
    entries.value = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static OrderEntry? cartForRestaurant(String restaurantId) {
    for (final entry in entries.value) {
      if (entry.status == OrderStatus.cart &&
          entry.order.restaurant.id == restaurantId) {
        return entry;
      }
    }
    return null;
  }

  static void upsertCart(CheckoutOrder order) {
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) =>
          entry.status == OrderStatus.cart &&
          entry.order.restaurant.id == order.restaurant.id,
    );
    final next = OrderEntry(
      id: index >= 0 ? current[index].id : _newEntryId(order, OrderStatus.cart),
      order: order,
      status: OrderStatus.cart,
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      current[index] = next;
    } else {
      current.insert(0, next);
    }
    _setEntries(current);
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
        id: _newEntryId(order, OrderStatus.cart),
        order: order,
        status: OrderStatus.cart,
        updatedAt: DateTime.now(),
      );
      current.insert(0, next);
      _setEntries(current);
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
      id: existing.id,
      order: mergedOrder,
      status: OrderStatus.cart,
      updatedAt: DateTime.now(),
    );
    _setEntries(current);
    return mergedOrder;
  }

  static OrderEntry markDelivering(CheckoutOrder order) {
    final current = List<OrderEntry>.of(entries.value)
      ..removeWhere(
        (entry) =>
            entry.status == OrderStatus.cart &&
            entry.order.restaurant.id == order.restaurant.id,
      );
    final next = OrderEntry(
      id: _newEntryId(order, OrderStatus.delivering),
      order: order,
      status: OrderStatus.delivering,
      updatedAt: DateTime.now(),
    );
    current.insert(0, next);
    _setEntries(current);
    return next;
  }

  static void markDelivered(CheckoutOrder order) {
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) =>
          entry.status == OrderStatus.delivering &&
          entry.order.restaurant.id == order.restaurant.id,
    );
    final next = OrderEntry(
      id: index >= 0
          ? current[index].id
          : _newEntryId(order, OrderStatus.delivered),
      order: order,
      status: OrderStatus.delivered,
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      current[index] = next;
    } else {
      current.insert(0, next);
    }
    _setEntries(current);
  }

  static void markEntryDelivered(String entryId) {
    if (entryId.isEmpty) return;
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) => entry.id == entryId && entry.status == OrderStatus.delivering,
    );
    if (index < 0) return;

    current[index] = current[index].copyWith(status: OrderStatus.delivered);
    _setEntries(current);
  }

  static void rateOrder({
    required String restaurantId,
    required int shopRating,
    required int driverRating,
  }) {
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) =>
          (entry.status == OrderStatus.delivered ||
              entry.status == OrderStatus.rated) &&
          entry.order.restaurant.id == restaurantId,
    );
    if (index < 0) return;

    current[index] = current[index].copyWith(
      status: OrderStatus.rated,
      shopRating: shopRating,
      driverRating: driverRating,
    );
    _setEntries(current);
  }

  static void rateEntry({
    required String entryId,
    required int shopRating,
    required int driverRating,
  }) {
    if (entryId.isEmpty) return;
    final current = List<OrderEntry>.of(entries.value);
    final index = current.indexWhere(
      (entry) =>
          entry.id == entryId &&
          (entry.status == OrderStatus.delivered ||
              entry.status == OrderStatus.rated),
    );
    if (index < 0) return;

    current[index] = current[index].copyWith(
      status: OrderStatus.rated,
      shopRating: shopRating,
      driverRating: driverRating,
    );
    _setEntries(current);
  }

  static void removeCart(String restaurantId) {
    final current = List<OrderEntry>.of(entries.value)
      ..removeWhere(
        (entry) =>
            entry.status == OrderStatus.cart &&
            entry.order.restaurant.id == restaurantId,
      );
    _setEntries(current);
  }

  static void updateCartItemQuantity({
    required String restaurantId,
    required CartItem item,
    required int quantity,
  }) {
    final current = List<OrderEntry>.of(entries.value);
    final cartIndex = current.indexWhere(
      (entry) =>
          entry.status == OrderStatus.cart &&
          entry.order.restaurant.id == restaurantId,
    );
    if (cartIndex < 0) return;

    final cart = current[cartIndex];
    final items = List<CartItem>.of(cart.order.items);
    final itemIndex = items.indexWhere((line) => _sameCartLine(line, item));
    if (itemIndex < 0) return;

    if (quantity <= 0) {
      items.removeAt(itemIndex);
    } else {
      items[itemIndex] = items[itemIndex].copyWith(quantity: quantity);
    }

    if (items.isEmpty) {
      current.removeAt(cartIndex);
    } else {
      current[cartIndex] = cart.copyWith(
        order: cart.order.copyWith(items: items),
      );
    }
    _setEntries(current);
  }

  static void _setEntries(List<OrderEntry> next) {
    entries.value = List<OrderEntry>.unmodifiable(next);
    unawaited(_persistEntries(entries.value));
  }

  static Future<void> _persistEntries(List<OrderEntry> current) async {
    final prefs = await SharedPreferences.getInstance();
    if (current.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(
      _prefsKey,
      jsonEncode(current.map((entry) => entry.toJson()).toList()),
    );
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

String _newEntryId(CheckoutOrder order, OrderStatus status) {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final sequence = _entrySequence++;
  final restaurant = order.restaurant.id.replaceAll(
    RegExp(r'[^a-zA-Z0-9]'),
    '',
  );
  return '${status.name}-$restaurant-$timestamp-$sequence';
}

String _entryIdFromJson(
  Map<String, dynamic> json,
  CheckoutOrder order,
  DateTime updatedAt,
) {
  final raw = json['id'] as String?;
  if (raw != null && raw.isNotEmpty) return raw;
  final millis = updatedAt.millisecondsSinceEpoch;
  final restaurant = order.restaurant.id.replaceAll(
    RegExp(r'[^a-zA-Z0-9]'),
    '',
  );
  final itemSeed = order.items.map((item) => item.id).join('-');
  return 'legacy-$restaurant-$millis-${itemSeed.hashCode.abs()}';
}
