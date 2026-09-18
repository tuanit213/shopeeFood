import '../address/delivery_address.dart';
import '../domain/address/delivery_address_v2.dart';

abstract final class LegacyAddressAdapter {
  static DeliveryAddressV2 toV2(DeliveryAddress legacy, {DateTime? now}) {
    final timestamp = now ?? DateTime.now().toUtc();
    return DeliveryAddressV2(
      id: legacy.id,
      label: legacy.label,
      receiverName: legacy.receiverName,
      receiverPhone: legacy.phone,
      formattedAddress: legacy.displayAddress,
      addressComponents: const AddressComponents(),
      location: AddressLocation(
        latitude: legacy.latitude,
        longitude: legacy.longitude,
      ),
      source: AddressSource.legacy,
      verified: false,
      createdAt: timestamp,
      updatedAt: timestamp,
      gate: legacy.gate,
      note: legacy.note,
    );
  }

  static DeliveryAddress fromV2(DeliveryAddressV2 value) => DeliveryAddress(
    id: value.id,
    label: value.label,
    receiverName: value.receiverName,
    phone: value.receiverPhone,
    address: value.formattedAddress,
    latitude: value.location.latitude,
    longitude: value.location.longitude,
    detail: [
      value.building,
      value.floor,
      value.unit,
    ].whereType<String>().where((item) => item.isNotEmpty).join(', '),
    gate: value.gate ?? '',
    note: value.note ?? '',
  );
}
