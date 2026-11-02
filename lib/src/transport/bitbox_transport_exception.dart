class BitboxTransportException implements Exception {
  BitboxTransportException(this.message);

  final String message;

  @override
  String toString() => 'BitboxTransportException: $message';
}
