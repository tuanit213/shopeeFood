import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeefood/checkout/checkout_models.dart';
import 'package:shopeefood/orders/order_state.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OrderState.clearPersisted();
  });

  tearDown(() async {
    await OrderState.clearPersisted();
  });

  test('mergeCartItem keeps existing items for the same restaurant', () {
    OrderState.mergeCartItem(_orderWith(_cartItem(id: 'tea', name: 'Tra sua')));
    OrderState.mergeCartItem(_orderWith(_cartItem(id: 'rice', name: 'Com ga')));

    final cart = OrderState.cartForRestaurant('store-1');

    expect(cart, isNotNull);
    expect(cart!.order.items.map((item) => item.id), ['tea', 'rice']);
    expect(cart.order.itemCount, 2);
  });

  test('mergeCartItem increments matching cart lines', () {
    OrderState.mergeCartItem(_orderWith(_cartItem(id: 'tea', name: 'Tra sua')));
    OrderState.mergeCartItem(_orderWith(_cartItem(id: 'tea', name: 'Tra sua')));

    final cart = OrderState.cartForRestaurant('store-1')!;

    expect(cart.order.items, hasLength(1));
    expect(cart.order.items.single.quantity, 2);
  });

  test('updateCartItemQuantity changes a cart line quantity', () {
    final item = _cartItem(id: 'tea', name: 'Tra sua');
    OrderState.mergeCartItem(_orderWith(item));

    OrderState.updateCartItemQuantity(
      restaurantId: 'store-1',
      item: item,
      quantity: 3,
    );

    final cart = OrderState.cartForRestaurant('store-1')!;
    expect(cart.order.items.single.quantity, 3);
    expect(cart.order.itemCount, 3);
  });

  test(
    'updateCartItemQuantity removes item and cart when quantity is zero',
    () {
      final item = _cartItem(id: 'tea', name: 'Tra sua');
      OrderState.mergeCartItem(_orderWith(item));

      OrderState.updateCartItemQuantity(
        restaurantId: 'store-1',
        item: item,
        quantity: 0,
      );

      expect(OrderState.cartForRestaurant('store-1'), isNull);
      expect(OrderState.entries.value, isEmpty);
    },
  );

  test('hydrate restores cart entries from local storage', () async {
    OrderState.mergeCartItem(_orderWith(_cartItem(id: 'tea', name: 'Tra sua')));
    await OrderState.persist();

    OrderState.entries.value = const [];
    await OrderState.hydrate();

    final cart = OrderState.cartForRestaurant('store-1');
    expect(cart, isNotNull);
    expect(cart!.status, OrderStatus.cart);
    expect(cart.order.items.single.id, 'tea');
  });

  test('hydrate restores checkout note voucher tip and cutlery', () async {
    final order = _orderWith(_cartItem(id: 'tea', name: 'Tra sua')).copyWith(
      deliveryTimeLabel: 'Hen gio - Hom nay 18:00 - 19:00',
      orderNote: 'Khong cay',
      useCutlery: true,
      driverTip: 10000,
      voucherDiscount: 10000,
    );
    OrderState.mergeCartItem(order);
    await OrderState.persist();

    OrderState.entries.value = const [];
    await OrderState.hydrate();

    final restored = OrderState.cartForRestaurant('store-1')!.order;
    expect(restored.deliveryTimeLabel, 'Hen gio - Hom nay 18:00 - 19:00');
    expect(restored.orderNote, 'Khong cay');
    expect(restored.useCutlery, isTrue);
    expect(restored.driverTip, 10000);
    expect(restored.voucherDiscount, 10000);
  });

  test('upsertCart replaces checkout options without losing cart items', () {
    final tea = _cartItem(id: 'tea', name: 'Tra sua');
    final rice = _cartItem(id: 'rice', name: 'Com ga');
    OrderState.mergeCartItem(_orderWith(tea));
    final mergedOrder = OrderState.mergeCartItem(_orderWith(rice));

    final updatedOrder = mergedOrder.copyWith(
      paymentMethod: 'Vi ShopeePay',
      deliveryTimeLabel: 'Giao ngay',
      orderNote: 'Lay nhieu tuong ot',
      useCutlery: true,
      driverTip: 15000,
      voucherDiscount: 20000,
    );
    OrderState.upsertCart(updatedOrder);

    final cart = OrderState.cartForRestaurant('store-1')!.order;
    expect(cart.items.map((item) => item.id), ['tea', 'rice']);
    expect(cart.paymentMethod, 'Vi ShopeePay');
    expect(cart.deliveryTimeLabel, 'Giao ngay');
    expect(cart.orderNote, 'Lay nhieu tuong ot');
    expect(cart.useCutlery, isTrue);
    expect(cart.driverTip, 15000);
    expect(cart.voucherDiscount, 20000);
  });

  test('markDelivering keeps carts from other restaurants', () {
    final firstStoreOrder = _orderWith(_cartItem(id: 'tea', name: 'Tra sua'));
    final secondStoreOrder = _orderWith(
      _cartItem(id: 'noodle', name: 'Mi cay'),
      restaurantId: 'store-2',
      restaurantName: 'Quan mi cay',
    );

    OrderState.mergeCartItem(firstStoreOrder);
    OrderState.mergeCartItem(secondStoreOrder);

    final deliveringEntry = OrderState.markDelivering(firstStoreOrder);

    expect(deliveringEntry.status, OrderStatus.delivering);
    expect(OrderState.cartForRestaurant('store-1'), isNull);
    expect(OrderState.cartForRestaurant('store-2'), isNotNull);
    expect(OrderState.entries.value, hasLength(2));
  });

  test('supports multiple active deliveries from different restaurants', () {
    final first = OrderState.markDelivering(
      _orderWith(_cartItem(id: 'tea', name: 'Tra sua')),
    );
    final second = OrderState.markDelivering(
      _orderWith(
        _cartItem(id: 'rice', name: 'Com ga'),
        restaurantId: 'store-2',
        restaurantName: 'Quan com ga',
      ),
    );

    expect(first.id, isNot(second.id));
    expect(
      OrderState.entries.value.where(
        (entry) => entry.status == OrderStatus.delivering,
      ),
      hasLength(2),
    );

    OrderState.markEntryDelivered(second.id);

    final entries = OrderState.entries.value;
    expect(
      entries.singleWhere((entry) => entry.id == first.id).status,
      OrderStatus.delivering,
    );
    expect(
      entries.singleWhere((entry) => entry.id == second.id).status,
      OrderStatus.delivered,
    );
  });

  test('hydrate restores delivering entries from local storage', () async {
    final order = _orderWith(_cartItem(id: 'rice', name: 'Com ga'));
    OrderState.markDelivering(order);
    await OrderState.persist();

    OrderState.entries.value = const [];
    await OrderState.hydrate();

    expect(OrderState.entries.value, hasLength(1));
    expect(OrderState.entries.value.single.status, OrderStatus.delivering);
    expect(OrderState.entries.value.single.order.items.single.id, 'rice');
  });

  test('markDelivered moves delivering order to history state', () {
    final order = _orderWith(_cartItem(id: 'rice', name: 'Com ga'));
    OrderState.markDelivering(order);

    OrderState.markDelivered(order);

    expect(OrderState.entries.value, hasLength(1));
    expect(OrderState.entries.value.single.status, OrderStatus.delivered);
    expect(OrderState.entries.value.single.order.items.single.id, 'rice');
  });

  test('markEntryDelivered only updates the targeted active order', () {
    final first = OrderState.markDelivering(
      _orderWith(_cartItem(id: 'rice', name: 'Com ga')),
    );
    final second = OrderState.markDelivering(
      _orderWith(_cartItem(id: 'tea', name: 'Tra sua')),
    );

    OrderState.markEntryDelivered(second.id);

    final entries = OrderState.entries.value;
    final firstEntry = entries.singleWhere((entry) => entry.id == first.id);
    final secondEntry = entries.singleWhere((entry) => entry.id == second.id);

    expect(firstEntry.status, OrderStatus.delivering);
    expect(secondEntry.status, OrderStatus.delivered);
    expect(secondEntry.order.items.single.id, 'tea');
  });

  test('rateOrder stores ratings and persists rated state', () async {
    final order = _orderWith(_cartItem(id: 'rice', name: 'Com ga'));
    OrderState.markDelivering(order);
    OrderState.markDelivered(order);

    OrderState.rateOrder(
      restaurantId: 'store-1',
      shopRating: 5,
      driverRating: 4,
    );
    await OrderState.persist();

    OrderState.entries.value = const [];
    await OrderState.hydrate();

    final entry = OrderState.entries.value.single;
    expect(entry.status, OrderStatus.rated);
    expect(entry.shopRating, 5);
    expect(entry.driverRating, 4);
  });

  test('rateEntry only updates the targeted delivered order', () {
    final first = OrderState.markDelivering(
      _orderWith(_cartItem(id: 'rice', name: 'Com ga')),
    );
    final second = OrderState.markDelivering(
      _orderWith(_cartItem(id: 'tea', name: 'Tra sua')),
    );
    OrderState.markEntryDelivered(first.id);
    OrderState.markEntryDelivered(second.id);

    OrderState.rateEntry(entryId: second.id, shopRating: 4, driverRating: 5);

    final entries = OrderState.entries.value;
    final firstEntry = entries.singleWhere((entry) => entry.id == first.id);
    final secondEntry = entries.singleWhere((entry) => entry.id == second.id);

    expect(firstEntry.status, OrderStatus.delivered);
    expect(firstEntry.shopRating, isNull);
    expect(secondEntry.status, OrderStatus.rated);
    expect(secondEntry.shopRating, 4);
    expect(secondEntry.driverRating, 5);
  });
}

CheckoutOrder _orderWith(
  CartItem item, {
  String restaurantId = 'store-1',
  String restaurantName = 'Quan demo',
}) {
  return CheckoutOrder(
    restaurant: CheckoutRestaurantInfo(
      id: restaurantId,
      name: restaurantName,
      address: '12 Le Loi, Quan 1, TP.HCM',
      deliveryMinutes: 20,
      distanceKm: 1.2,
    ),
    items: [item],
    address: '99 Nguyen Hue, Quan 1, TP.HCM',
    receiverName: 'Khach hang',
    receiverPhone: '0901234567',
  );
}

CartItem _cartItem({required String id, required String name}) {
  return CartItem(
    id: id,
    name: name,
    description: 'Mon dang giam',
    imageUrl: 'assets/images/restaurants/food_01.jpg',
    unitPrice: 25000,
    quantity: 1,
    toppings: const [],
    note: '',
  );
}
