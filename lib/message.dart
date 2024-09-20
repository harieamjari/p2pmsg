import 'dart:typed_data';

sealed class P2PMessage {
  final BigInt timestamp;
  final Uint8List signature;
  P2PMessage({
    required this.timestamp,
    required this.signature
  });
}

class MessageHandshake extends P2PMessage {
  final Uint8List publicKey;
  final String dstKeyId;
  MessageHandshake({
    required super.timestamp,
    required super.signature,
    required this.publicKey,
    required this.dstKeyId
  });
}

class MessageMessage extends P2PMessage {
  final String mimeType;
  final Uint8List data;
  MessageMessage({
    required super.timestamp,
    required super.signature,
    required this.mimeType,
    required this.data
  });
}
