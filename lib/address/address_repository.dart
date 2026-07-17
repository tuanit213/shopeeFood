import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'delivery_address.dart';

class AddressRepository {
  static const _addressesKey = 'delivery_addresses';
  static const _selectedAddressKey = 'selected_delivery_address_id';

  static Future<List<DeliveryAddress>> loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_addressesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <DeliveryAddress>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => DeliveryAddress.fromJson(item as Map<String, dynamic>))
        .where((address) => address.id.isNotEmpty)
        .toList();
  }

  static Future<DeliveryAddress?> loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString(_selectedAddressKey);
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    final addresses = await loadAddresses();
    for (final address in addresses) {
      if (address.id == selectedId) {
        return address;
      }
    }
    return null;
  }

  static Future<void> saveAndSelect(DeliveryAddress address) async {
    final normalizedAddress = address.normalized();
    final addresses = await loadAddresses();
    final index = addresses.indexWhere(
      (item) => item.id == normalizedAddress.id,
    );
    if (index >= 0) {
      addresses[index] = normalizedAddress;
    } else {
      addresses.insert(0, normalizedAddress);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _addressesKey,
      jsonEncode(addresses.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_selectedAddressKey, normalizedAddress.id);
  }

  static Future<void> select(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedAddressKey, id);
  }
}
