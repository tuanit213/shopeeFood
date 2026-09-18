import '../domain/order/order_v2.dart';

abstract interface class OrderRepository {
  Stream<List<OrderV2>> watchCustomerOrders(String customerId);
  Future<OrderV2?> getById(String orderId);
  Future<String> createCustomerOrder(OrderV2 order);
}
