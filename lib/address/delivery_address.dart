class DeliveryAddress {
  final String id;
  final String label;
  final String receiverName;
  final String phone;
  final String address;
  final String detail;
  final String gate;
  final String note;
  final double latitude;
  final double longitude;

  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.receiverName,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.detail = '',
    this.gate = '',
    this.note = '',
  });

  String get title {
    final cleanLabel = cleanText(label);
    return switch (cleanLabel) {
      'Home' => 'Nhà',
      'Work' => 'Công ty',
      'Other' => 'Khác',
      '' => 'Nhà',
      _ => label,
    };
  }

  String get displayAddress {
    final parts = [
      detail,
      gate,
      address,
    ].map(cleanText).where((part) => part.isNotEmpty).toList();
    return parts.join(', ');
  }

  DeliveryAddress normalized() {
    return copyWith(
      label: cleanText(label),
      receiverName: cleanText(receiverName),
      phone: cleanText(phone),
      address: cleanText(address),
      detail: cleanText(detail),
      gate: cleanText(gate),
      note: cleanText(note),
    );
  }

  static String cleanText(String value) {
    final text = value.trim();
    if (!text.contains('%')) {
      return text;
    }

    try {
      return Uri.decodeComponent(text).trim();
    } catch (_) {
      return text.replaceAll('%20', ' ').trim();
    }
  }

  DeliveryAddress copyWith({
    String? id,
    String? label,
    String? receiverName,
    String? phone,
    String? address,
    String? detail,
    String? gate,
    String? note,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      receiverName: receiverName ?? this.receiverName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      detail: detail ?? this.detail,
      gate: gate ?? this.gate,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': cleanText(label),
      'receiverName': cleanText(receiverName),
      'phone': cleanText(phone),
      'address': cleanText(address),
      'detail': cleanText(detail),
      'gate': cleanText(gate),
      'note': cleanText(note),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] as String? ?? '',
      label: cleanText(json['label'] as String? ?? 'Nhà'),
      receiverName: cleanText(json['receiverName'] as String? ?? ''),
      phone: cleanText(json['phone'] as String? ?? ''),
      address: cleanText(json['address'] as String? ?? ''),
      detail: cleanText(json['detail'] as String? ?? ''),
      gate: cleanText(json['gate'] as String? ?? ''),
      note: cleanText(json['note'] as String? ?? ''),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}
