class BitboxDevice {
  final String identifier;
  final int vendorId;
  final int productId;
  final String productName;
  final int deviceId;
  final String deviceName;
  final String manufacturerName;
  final int configurationCount;

  BitboxDevice({
    required this.identifier,
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.deviceId,
    required this.deviceName,
    required this.manufacturerName,
    required this.configurationCount,
  });

  factory BitboxDevice.fromIdentifier(String identifier) {
    return BitboxDevice(
      identifier: identifier,
      vendorId: 0,
      productId: 0,
      productName: '',
      deviceId: 0,
      deviceName: '',
      manufacturerName: '',
      configurationCount: 1,
    );
  }

  factory BitboxDevice.fromMap(Map<dynamic, dynamic> map) {
    return BitboxDevice(
      identifier: map['identifier'],
      vendorId: map['vendorId'],
      productId: map['productId'],
      productName: map['productName'] ?? '',
      deviceId: map['deviceId'],
      deviceName: map['deviceName'],
      manufacturerName: map['manufacturerName'] ?? '',
      configurationCount: map['configurationCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'identifier': identifier,
      'vendorId': vendorId,
      'productId': productId,
      'productName': productName,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'manufacturerName': manufacturerName,
      'configurationCount': configurationCount,
    };
  }

  @override
  String toString() => toMap().toString();
}
