import '../checkout/checkout_models.dart';
import '../domain/order/order_v2.dart';
import '../domain/address/delivery_address_v2.dart';
import '../domain/catalog/restaurant_v2.dart';

abstract final class LegacyOrderAdapter {
  static PricingSnapshot pricingFromLegacy(CheckoutOrder order) =>
      PricingSnapshot(
        subtotal: order.subtotal,
        deliveryFee: order.deliveryFee,
        serviceFee: order.serviceFee,
        driverTip: order.driverTip,
        discount: order.discount,
        total: order.total,
      );

  static OrderItemSnapshot itemFromLegacy(CartItem item) => OrderItemSnapshot(
    menuItemId: item.id,
    nameSnapshot: item.name,
    priceSnapshot: item.unitPrice,
    imageSnapshot: item.imageUrl,
    optionsSnapshot: item.toppings
        .map((name) => {'name': name, 'priceDelta': 0})
        .toList(growable: false),
    quantity: item.quantity,
    lineTotalSnapshot: item.lineTotal,
  );

  static OrderV2 fromLegacy({
    required String id,
    required String customerId,
    required CheckoutOrder order,
    required DeliveryAddressV2 deliveryAddress,
    required RestaurantV2 restaurant,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now().toUtc();
    return OrderV2(
      id: id,
      customerId: customerId,
      restaurantId: order.restaurant.id,
      branchId: order.restaurant.id,
      status: OrderStatus.placed,
      statusVersion: 1,
      items: order.items.map(itemFromLegacy).toList(growable: false),
      deliveryAddressSnapshot: deliveryAddress,
      restaurantSnapshot: restaurant,
      pricing: pricingFromLegacy(order),
      delivery: DeliverySnapshot(
        estimatedDurationSeconds: order.restaurant.deliveryMinutes * 60,
        distanceMeters: (order.restaurant.distanceKm * 1000).round(),
      ),
      timeline: OrderTimeline(createdAt: timestamp),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
