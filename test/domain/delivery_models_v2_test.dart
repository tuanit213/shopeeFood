import 'package:flutter_test/flutter_test.dart';
import 'package:shopeefood/domain/address/delivery_address_v2.dart';
import 'package:shopeefood/domain/catalog/restaurant_v2.dart';
import 'package:shopeefood/domain/menu/menu_models_v2.dart';
import 'package:shopeefood/domain/order/order_v2.dart';

void main() {
  final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
  final address = DeliveryAddressV2(
    id: 'a1',
    label: 'Home',
    receiverName: 'A',
    receiverPhone: '0900',
    formattedAddress: '1 Main St',
    addressComponents: const AddressComponents(street: 'Main St'),
    location: const AddressLocation(latitude: 10, longitude: 106),
    source: AddressSource.manual,
    verified: false,
    createdAt: now,
    updatedAt: now,
  );

  test('address round trips and legacy fields remain explicit', () {
    expect(
      DeliveryAddressV2.fromJson(address.toJson()).toJson(),
      address.toJson(),
    );
  });

  test('catalog and menu models round trip option deltas', () {
    final restaurant = RestaurantV2(
      id: 'r',
      name: 'R',
      description: '',
      logoUrl: '',
      coverUrl: '',
      categories: const ['food'],
      rating: 4.5,
      ratingCount: 2,
      verified: true,
      status: CatalogStatus.active,
      merchantIds: const ['m'],
      createdAt: now,
      updatedAt: now,
    );
    final item = MenuItemV2(
      id: 'm',
      restaurantId: 'r',
      branchId: 'b',
      sectionId: 's',
      name: 'N',
      description: '',
      price: 30000,
      imageUrl: '',
      thumbnailUrl: '',
      imageSource: MenuImageSource.asset,
      available: true,
      optionGroupIds: const ['g'],
      soldCount: 1,
      rating: 5,
      verified: true,
      createdAt: now,
      updatedAt: now,
    );
    final option = OptionGroupV2(
      id: 'g',
      name: 'Size',
      required: true,
      minSelections: 1,
      maxSelections: 1,
      items: const [
        OptionItemV2(id: 'o', name: 'Large', priceDelta: 7000, available: true),
      ],
    );
    expect(
      RestaurantV2.fromJson(restaurant.toJson()).toJson(),
      restaurant.toJson(),
    );
    expect(MenuItemV2.fromJson(item.toJson()).toJson(), item.toJson());
    expect(
      OptionGroupV2.fromJson(option.toJson()).items.single.priceDelta,
      7000,
    );
  });

  test('order status excludes rated and round trips snapshots', () {
    expect(OrderStatus.values.map((s) => s.name), isNot(contains('rated')));
    final order = OrderV2(
      id: 'o',
      customerId: 'c',
      restaurantId: 'r',
      branchId: 'b',
      status: OrderStatus.placed,
      statusVersion: 1,
      items: const [],
      deliveryAddressSnapshot: address,
      restaurantSnapshot: RestaurantV2(
        id: 'r',
        name: 'R',
        description: '',
        logoUrl: '',
        coverUrl: '',
        categories: [],
        rating: 0,
        ratingCount: 0,
        verified: false,
        status: CatalogStatus.active,
        merchantIds: [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      pricing: const PricingSnapshot(
        subtotal: 1,
        deliveryFee: 2,
        serviceFee: 3,
        driverTip: 0,
        discount: 0,
        total: 6,
      ),
      delivery: const DeliverySnapshot(),
      timeline: OrderTimeline(createdAt: now),
      createdAt: now,
      updatedAt: now,
    );
    expect(OrderV2.fromJson(order.toJson()).toJson(), order.toJson());
  });
}
