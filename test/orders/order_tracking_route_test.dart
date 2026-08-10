import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shopeefood/checkout/checkout_models.dart';
import 'package:shopeefood/orders/order_state.dart';
import 'package:shopeefood/orders/order_tracking_detail_page.dart';

void main() {
  group('fallback route (không có mạng / API lỗi)', () {
    test('không phải đường thẳng và không có bước nhảy lớn', () {
      const start = LatLng(10.7769, 106.7009);
      const end = LatLng(10.8231, 106.6297);

      final route = fallbackRoadRouteForTesting(start, end);

      expect(route.length, greaterThan(2));
      expect(route.first, start);
      expect(route.last, end);

      // "Không phải đường thẳng": ít nhất một điểm giữa route phải lệch khỏi
      // trục nối start-end quá một khoảng đáng kể (đường thẳng thì mọi điểm
      // đều nằm sát trục này).
      final straightLineKm = routeDistanceKmForTesting([start, end]);
      final actualRouteKm = routeDistanceKmForTesting(route);
      expect(actualRouteKm, greaterThan(straightLineKm));

      // "Không nhảy cóc": khoảng cách giữa hai điểm liên tiếp phải nhỏ, mượt.
      for (var i = 0; i < route.length - 1; i++) {
        final segmentKm = routeDistanceKmForTesting([route[i], route[i + 1]]);
        expect(
          segmentKm,
          lessThan(actualRouteKm * 0.25),
          reason:
              'đoạn thứ $i dài bất thường so với cả tuyến -> giống teleport',
        );
      }
    });

    test(
      'route rất ngắn vẫn được kéo dài hợp lý, không suy biến về 1 điểm',
      () {
        const start = LatLng(10.7843, 106.5682);
        const end = LatLng(10.7845, 106.5684); // cách nhau vài trăm mét
        final route = fallbackRoadRouteForTesting(start, end);
        expect(route.length, greaterThan(2));
        expect(routeDistanceKmForTesting(route), greaterThan(0));
      },
    );
  });

  group('vị trí tài xế dọc theo route (pointAt / remainingRoute)', () {
    final route = [
      const LatLng(10.70, 106.60),
      const LatLng(10.71, 106.61),
      const LatLng(10.73, 106.63),
      const LatLng(10.76, 106.66),
      const LatLng(10.80, 106.70),
    ];

    test('tiến 0% ở đầu route, 100% ở cuối route', () {
      expect(pointAtForTesting(route, 0), route.first);
      expect(pointAtForTesting(route, 1), route.last);
    });

    test('progress tăng thì khoảng cách đã đi tăng đều, không giật lùi', () {
      final samples = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
      double? previousWalked;
      for (final progress in samples) {
        final point = pointAtForTesting(route, progress);
        final walkedKm = routeDistanceKmForTesting([route.first, point]);
        // Không phải công thức tuyến tính tuyệt đối (vì đường có khúc rẽ),
        // nhưng quãng đã đi phải đơn điệu không giảm khi progress tăng.
        if (previousWalked != null) {
          expect(walkedKm, greaterThanOrEqualTo(previousWalked - 0.001));
        }
        previousWalked = walkedKm;
      }
    });

    test(
      'route phía sau giảm dần khi tiến độ tăng (đường còn lại ngắn dần)',
      () {
        final remainingAt20 = remainingRouteForTesting(route, 0.2);
        final remainingAt60 = remainingRouteForTesting(route, 0.6);
        final remainingAt99 = remainingRouteForTesting(route, 0.99);

        final kmAt20 = routeDistanceKmForTesting(remainingAt20);
        final kmAt60 = routeDistanceKmForTesting(remainingAt60);
        final kmAt99 = routeDistanceKmForTesting(remainingAt99);

        expect(kmAt20, greaterThan(kmAt60));
        expect(kmAt60, greaterThan(kmAt99));
        expect(kmAt99, lessThan(0.05));
      },
    );
  });

  group('hướng xoay xe máy (bearing)', () {
    test('bearing hợp lệ trong khoảng 0-360 độ', () {
      final route = [
        const LatLng(10.70, 106.60),
        const LatLng(10.72, 106.62),
        const LatLng(10.75, 106.60),
        const LatLng(10.78, 106.63),
      ];
      for (final progress in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
        final bearing = headingBearingForTesting(route, progress);
        expect(bearing, inInclusiveRange(0, 360));
      }
    });

    test('đi thẳng về hướng Bắc cho bearing gần 0 độ', () {
      final route = [const LatLng(10.70, 106.60), const LatLng(10.80, 106.60)];
      final bearing = bearingDegreesForTesting(route.first, route.last);
      expect(bearing, anyOf(lessThan(2), greaterThan(358)));
    });

    test('đi thẳng về hướng Đông cho bearing gần 90 độ', () {
      final route = [const LatLng(10.70, 106.60), const LatLng(10.70, 106.70)];
      final bearing = bearingDegreesForTesting(route.first, route.last);
      expect(bearing, closeTo(90, 2));
    });
  });

  group('chuyển động "đuổi theo" mốc GPS (chase)', () {
    test('luôn tiến gần target hơn, không bao giờ vượt quá target', () {
      var current = 0.0;
      const target = 0.6;
      // (1 - 0.045)^150 ≈ 0.001 -> sau 150 bước gần như hội tụ hoàn toàn,
      // nhưng vẫn phải tăng dần đều qua từng bước (không nhảy cóc).
      for (var i = 0; i < 150; i++) {
        final next = chaseTowardsForTesting(current, target, 0.045);
        expect(next, greaterThanOrEqualTo(current));
        expect(next, lessThanOrEqualTo(target));
        current = next;
      }
      expect(current, closeTo(target, 0.01));
    });

    test('mỗi bước chỉ ăn một phần nhỏ quãng còn lại (không teleport)', () {
      final next = chaseTowardsForTesting(0.0, 1.0, 0.045);
      expect(next, closeTo(0.045, 1e-9));
      expect(next, lessThan(0.1));
    });

    test(
      'hệ số làm mượt không phụ thuộc khung hình/giây (frame-rate độc lập)',
      () {
        const baseStep = 0.045;
        const referenceFrame = 1 / 60;

        // Hai khung 1/120s liên tiếp phải tương đương một khung 1/60s.
        final halfFrame = frameSmoothingFactorForTesting(
          referenceFrame / 2,
          baseStep,
          referenceFrame,
        );
        final combined = 1 - (1 - halfFrame) * (1 - halfFrame);
        final fullFrame = frameSmoothingFactorForTesting(
          referenceFrame,
          baseStep,
          referenceFrame,
        );
        expect(combined, closeTo(fullFrame, 1e-9));
      },
    );
  });

  group('khoảng cách/định dạng hiển thị', () {
    test('dưới 1km hiện theo mét, từ 1km trở lên hiện theo km', () {
      expect(formatTrackingDistanceForTesting(0.0), '0m');
      expect(formatTrackingDistanceForTesting(0.15), '150m');
      expect(formatTrackingDistanceForTesting(1.234), '1.2km');
    });
  });

  group(
    'vị trí quán/khách/tài xế theo từng đơn (không dùng chung dữ liệu)',
    () {
      test('quán và khách lấy đúng toạ độ đã lưu trong đơn', () {
        final order = _orderWith(
          restaurantId: 'quan-1',
          restaurantLat: 10.80,
          restaurantLng: 106.70,
          deliveryLat: 10.81,
          deliveryLng: 106.71,
        );

        final points = resolveTrackingPointsForTesting(order);

        expect(points.shop.latitude, 10.80);
        expect(points.shop.longitude, 106.70);
        expect(points.customer.latitude, 10.81);
        expect(points.customer.longitude, 106.71);
      });

      test(
        'hai đơn khác quán/khách cho vị trí driver/shop/customer khác nhau',
        () {
          final orderA = _orderWith(
            restaurantId: 'quan-a',
            restaurantLat: 10.70,
            restaurantLng: 106.60,
            deliveryLat: 10.71,
            deliveryLng: 106.61,
          );
          final orderB = _orderWith(
            restaurantId: 'quan-b',
            restaurantLat: 10.90,
            restaurantLng: 106.80,
            deliveryLat: 10.91,
            deliveryLng: 106.81,
          );

          final pointsA = resolveTrackingPointsForTesting(orderA);
          final pointsB = resolveTrackingPointsForTesting(orderB);

          expect(pointsA.shop, isNot(pointsB.shop));
          expect(pointsA.customer, isNot(pointsB.customer));
          expect(pointsA.driver, isNot(pointsB.driver));
        },
      );
    },
  );

  group('resume lộ trình theo thời gian thật (thoát ra vào lại không reset)', () {
    const toShop = Duration(seconds: 90);
    const toCustomer = Duration(seconds: 120);
    const wait = Duration(seconds: 12);
    const hold = Duration(seconds: 5);

    ({String phase, double progress}) at(int seconds) {
      return timelineStateForTesting(
        elapsed: Duration(seconds: seconds),
        toShop: toShop,
        toCustomer: toCustomer,
        waitAtShop: wait,
        arrivedHold: hold,
      );
    }

    test('mốc 0s là đầu chặng tài xế -> quán', () {
      final s = at(0);
      expect(s.phase, 'toShop');
      expect(s.progress, closeTo(0, 0.001));
    });

    test('giữa chặng tới quán cho tiến độ tương ứng, KHÔNG về 0', () {
      final s = at(45); // nửa chặng 90s
      expect(s.phase, 'toShop');
      expect(s.progress, closeTo(0.5, 0.02));
    });

    test('trong khoảng chờ quán lấy món', () {
      expect(at(95).phase, 'waitingAtShop'); // 90..102
    });

    test('đang giao tới khách với tiến độ tăng dần', () {
      // toCustomer bắt đầu ở 102s, dài 120s.
      expect(at(102).phase, 'toCustomer');
      final mid = at(162); // 102 + 60
      expect(mid.phase, 'toCustomer');
      expect(mid.progress, closeTo(0.5, 0.02));
    });

    test('đã tới nơi rồi đã giao xong khi vượt tổng thời gian', () {
      expect(at(223).phase, 'arrived'); // 222..227
      expect(at(230).phase, 'delivered');
      expect(at(100000).phase, 'delivered');
    });

    test('tiến độ đơn điệu không giảm suốt hai chặng di chuyển', () {
      double? prev;
      for (final sec in [0, 20, 40, 60, 80, 89]) {
        final p = at(sec).progress;
        if (prev != null) expect(p, greaterThanOrEqualTo(prev - 1e-9));
        prev = p;
      }
      prev = null;
      for (final sec in [103, 130, 160, 190, 220]) {
        final p = at(sec).progress;
        if (prev != null) expect(p, greaterThanOrEqualTo(prev - 1e-9));
        prev = p;
      }
    });
  });

  group('đo khoảng cách dưới 1km (bẫy roundResult của latlong2)', () {
    test('hai điểm cách nhau vài chục mét KHÔNG bị làm tròn về 0 km', () {
      // `Distance()` mặc định của latlong2 có `roundResult: true` và làm tròn
      // theo chính đơn vị được hỏi — `.as(LengthUnit.Kilometer, ...)` sẽ trả
      // 0.0 cho mọi cặp điểm cách nhau dưới 500m. Toàn bộ route tracking là
      // các đoạn vài chục mét, nên nếu quay lại dùng bản mặc định thì cả tuyến
      // dài "0 km", tài xế đứng yên và ETA/khoảng cách hiện sai.
      const a = LatLng(10.7843, 106.5682);
      const b = LatLng(10.7846, 106.5682); // ~33m
      final km = routeDistanceKmForTesting([a, b]);

      expect(km, greaterThan(0.02));
      expect(km, lessThan(0.05));
    });

    test('tổng chiều dài route ngắn phải cộng dồn đúng, không về 0', () {
      const start = LatLng(10.7843, 106.5682);
      const end = LatLng(10.7900, 106.5750); // ~0.9km
      final route = fallbackRoadRouteForTesting(start, end);

      expect(routeDistanceKmForTesting(route), greaterThan(0.5));
    });
  });

  group('tài xế spawn cách quán ~1km và route đủ dài để nhìn thấy', () {
    test('mọi đơn đều spawn tài xế cách quán khoảng 1km', () {
      for (var index = 0; index < 12; index++) {
        final order = _orderWith(
          restaurantId: 'quan-$index',
          restaurantLat: 10.78,
          restaurantLng: 106.57,
          deliveryLat: 10.80,
          deliveryLng: 106.60,
        );
        final points = resolveTrackingPointsForTesting(order);
        final spawnKm = routeDistanceKmForTesting([points.driver, points.shop]);
        expect(
          spawnKm,
          inInclusiveRange(0.9, 1.2),
          reason:
              'đơn quan-$index spawn cách quán ${spawnKm}km — phải quanh 1km '
              'để thấy rõ cả đoạn đường tài xế chạy tới quán',
        );
      }
    });

    test(
      'route tài xế -> quán đủ dài, tài xế nhích thấy được qua từng mốc',
      () {
        final order = _orderWith(
          restaurantId: 'quan-visible',
          restaurantLat: 10.78,
          restaurantLng: 106.57,
          deliveryLat: 10.80,
          deliveryLng: 106.60,
        );
        final points = resolveTrackingPointsForTesting(order);
        final route = fallbackRoadRouteForTesting(points.driver, points.shop);

        // Route phải dài hơn hẳn ngưỡng "một chấm nằm sát quán".
        expect(routeDistanceKmForTesting(route), greaterThan(0.85));

        // Mỗi mốc 5% tiến độ phải dịch chuyển được vài chục mét — nếu route bị
        // suy biến (mọi điểm trùng nhau) thì giá trị này về 0 và trên máy thật
        // sẽ thấy tài xế đứng yên dù % tiến độ vẫn chạy.
        var previous = pointAtForTesting(route, 0);
        for (var step = 1; step <= 20; step++) {
          final next = pointAtForTesting(route, step / 20);
          final movedMeters =
              routeDistanceKmForTesting([previous, next]) * 1000;
          expect(
            movedMeters,
            greaterThan(20),
            reason:
                'mốc ${step * 5}% chỉ nhích ${movedMeters}m — coi như đứng yên',
          );
          previous = next;
        }
      },
    );
  });

  group('hồ sơ tài xế theo từng đơn (không fake giống nhau cho mọi đơn)', () {
    test(
      'cùng một seed luôn ra đúng một tài xế (mở lại đơn cũ vẫn thấy tài xế cũ)',
      () {
        final first = driverProfileForTesting('order-abc-123');
        final second = driverProfileForTesting('order-abc-123');

        expect(first.name, second.name);
        expect(first.phone, second.phone);
        expect(first.plate, second.plate);
        expect(first.rating, second.rating);
      },
    );

    test('nhiều đơn khác nhau không cùng chung một tài xế', () {
      final seeds = List.generate(
        8,
        (index) => 'delivering-order-restaurant$index-1700000000$index-$index',
      );
      final profiles = seeds.map(driverProfileForTesting).toList();

      final names = profiles.map((p) => p.name).toSet();
      final plates = profiles.map((p) => p.plate).toSet();

      // Không đòi hỏi 100% khác nhau (hash có thể trùng), nhưng chắc chắn
      // không phải TẤT CẢ đơn đều ra cùng một tài xế như dữ liệu fake cũ.
      expect(names.length, greaterThan(1));
      expect(plates.length, greaterThan(1));
    });

    test('seed ưu tiên lấy từ entry.id, chỉ rơi về order khi id rỗng', () {
      final order = _orderWith(
        restaurantId: 'quan-x',
        restaurantLat: 10.7,
        restaurantLng: 106.6,
        deliveryLat: 10.71,
        deliveryLng: 106.61,
      );
      final withId = OrderEntry(
        id: 'delivering-quan-x-123-0',
        order: order,
        status: OrderStatus.delivering,
        updatedAt: DateTime(2024, 1, 1),
      );
      final withoutId = OrderEntry(
        order: order,
        status: OrderStatus.delivering,
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(driverProfileSeedForTesting(withId), 'delivering-quan-x-123-0');
      expect(
        driverProfileSeedForTesting(withoutId),
        isNot('delivering-quan-x-123-0'),
      );
      expect(driverProfileSeedForTesting(withoutId), contains('quan-x'));
    });
  });
}

CheckoutOrder _orderWith({
  required String restaurantId,
  required double restaurantLat,
  required double restaurantLng,
  required double deliveryLat,
  required double deliveryLng,
}) {
  return CheckoutOrder(
    restaurant: CheckoutRestaurantInfo(
      id: restaurantId,
      name: 'Quán $restaurantId',
      address: '12 Đường ABC',
      deliveryMinutes: 20,
      distanceKm: 1.5,
      latitude: restaurantLat,
      longitude: restaurantLng,
    ),
    items: const [
      CartItem(
        id: 'item-1',
        name: 'Cơm gà',
        description: '',
        imageUrl: '',
        unitPrice: 35000,
        quantity: 1,
        toppings: [],
        note: '',
      ),
    ],
    address: '99 Đường XYZ',
    receiverName: 'Khách hàng',
    receiverPhone: '0900000000',
    deliveryLatitude: deliveryLat,
    deliveryLongitude: deliveryLng,
  );
}
