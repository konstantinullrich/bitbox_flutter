class BitboxDevice {
  final String identifier;
  final int vendorId;
  final int productId;
  final String productName;
  final int deviceId;
  final String deviceName;
  final String manufacturerName;
  final int configurationCount;
  final bool isUsb;

  const BitboxDevice({
    required this.identifier,
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.deviceId,
    required this.deviceName,
    required this.manufacturerName,
    required this.configurationCount,
    required this.isUsb,
  });

  factory BitboxDevice.fromMap(Map<dynamic, dynamic> map) => BitboxDevice(
    identifier: map['identifier'],
    vendorId: map['vendorId'],
    productId: map['productId'],
    productName: map['productName'] ?? '',
    deviceId: map['deviceId'],
    deviceName: map['deviceName'],
    manufacturerName: map['manufacturerName'] ?? '',
    configurationCount: map['configurationCount'] ?? 0,
    isUsb: map['isUsb'] ?? bool,
  );

  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'vendorId': vendorId,
    'productId': productId,
    'productName': productName,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'manufacturerName': manufacturerName,
    'configurationCount': configurationCount,
    'isUsb': isUsb,
  };

  @override
  String toString() => toMap().toString();
}
