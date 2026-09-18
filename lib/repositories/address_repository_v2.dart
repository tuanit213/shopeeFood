import '../domain/address/delivery_address_v2.dart';

abstract interface class AddressRepositoryV2 {
  Stream<List<DeliveryAddressV2>> watchForUser(String uid);
  Future<void> save(String uid, DeliveryAddressV2 address);
  Future<void> delete(String uid, String addressId);
}
