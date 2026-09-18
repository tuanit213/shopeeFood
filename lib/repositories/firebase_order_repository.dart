import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../checkout/checkout_models.dart';
import '../domain/order/order_v2.dart';
import 'order_repository.dart';

/// Client boundary for server-authoritative orders. The client submits only
/// selections; pricing and snapshots are returned by the callable function.
class FirebaseOrderRepository implements OrderRepository {
  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  FirebaseOrderRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
       firestore = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      firestore.collection('orders');

  @override
  Stream<List<OrderV2>> watchCustomerOrders(String customerId) {
    return _orders
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDocument).toList());
  }

  Stream<OrderV2?> watchOrder(String orderId) {
    return _orders.doc(orderId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return _fromDocument(doc);
    });
  }

  @override
  Future<OrderV2?> getById(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    return doc.exists && doc.data() != null ? _fromDocument(doc) : null;
  }

  @override
  Future<String> createCustomerOrder(OrderV2 order) {
    throw UnsupportedError(
      'Client order writes are disabled; use createOrderFromCheckout.',
    );
  }

  Future<OrderV2> createOrderFromCheckout(
    CheckoutOrder order, {
    required String idempotencyKey,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Đăng nhập để đặt đơn thật.',
      );
    }
    final callable = functions.httpsCallable('createOrder');
    final result = await callable.call({
      'idempotencyKey': idempotencyKey,
      'restaurantId': order.restaurant.id,
      'branchId': order.restaurant.id,
      'items': order.items
          .map(
            (item) => {
              'menuItemId': item.id,
              'quantity': item.quantity,
              'options': item.toppings
                  .map((name) => {'name': name})
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'deliveryAddress': {
        'formattedAddress': order.address,
        'receiverName': order.receiverName,
        'receiverPhone': order.receiverPhone,
        'latitude': order.deliveryLatitude,
        'longitude': order.deliveryLongitude,
      },
      'paymentMethod': order.paymentMethod,
      'driverTip': order.driverTip,
      'orderNote': order.orderNote,
      'useCutlery': order.useCutlery,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      throw StateError('createOrder returned no orderId');
    }
    final created = await getById(orderId);
    if (created == null) throw StateError('Created order is not readable');
    return created;
  }

  OrderV2 _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderV2.fromJson({..._normalize(doc.data()!), 'id': doc.id});
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> value) {
    Object? convert(Object? item) {
      if (item is Timestamp) return item.toDate().toUtc().toIso8601String();
      if (item is Map) {
        return item.map((key, nested) => MapEntry('$key', convert(nested)));
      }
      if (item is List) return item.map(convert).toList(growable: false);
      return item;
    }

    return convert(value) as Map<String, dynamic>;
  }
}
