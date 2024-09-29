/* p2pmsg.dart - core p2p protocol */

//  Session handshake message format.
//  Clients initiates connection with the following tcp message.
//
//  Size      |  Field
//  4 bytes   |  The string "P2GP"
//  4 bytes   | Whole message length
//  8 bytes   |  Unix epoch in seconds
//  4 bytes   | Destination keyId length
//  ......    | dstKeyFingerprint
//  4 bytes   | PGP pkey length
//  ......    | PGP pkey
//  4 bytes   | PGP signature length
//  .......   | PGP signature of the above first 6 fields
//
//  All integers in big endian.
//
//  Message format (msgdec):
//
//  Size      |    Field
//  8 bytes   | Unix epoch in seconds
//  4 bytes   | Mimetype length
//  ......    | Mimetype
//  4 bytes   | Data length
//  ......    | data
//
//  Message format (msgenc)
//
//  4 bytes   | The string "P2GM"
//  4 bytes   | Whole message length
//  4 bytes   | encrypted data len
//  .....     | encrypted data (see msgdec)
//  4 bytes   | PGP signature length
//  ....      | PGP signature

import 'package:openpgp/openpgp.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

int _UnixEpoch() {
  return (DateTime.now().millisecondsSinceEpoch / 1000).toInt();
}

// Big endian
int _list2Uint64(List<int> l) {
  assert(l.length >= 8);
  return (l[0] << 56) +
      (l[1] << 48) +
      (l[2] << 40) +
      (l[3] << 32) +
      (l[4] << 24) +
      (l[5] << 16) +
      (l[6] << 8) +
      l[7];
}

int _list2Uint32(List<int> l) {
  assert(l.length >= 4);
  return (l[0] << 24) + (l[1] << 16) + (l[2] << 8) + l[3];
}

Uint8List _Uint32ToList(int i) {
  Uint8List l = Uint8List(4);
  l[0] = (i >> 24) & 255;
  l[1] = (i >> 16) & 255;
  l[2] = (i >> 8) & 255;
  l[3] = i & 255;
  return l;
}

Uint8List _Uint64ToList(int i) {
  Uint8List l = Uint8List(8);
  l[0] = (i >> 56) & 255;
  l[1] = (i >> 48) & 255;
  l[2] = (i >> 40) & 255;
  l[3] = (i >> 32) & 255;
  l[4] = (i >> 24) & 255;
  l[5] = (i >> 16) & 255;
  l[6] = (i >> 8) & 255;
  l[7] = i & 255;
  return l;
}

sealed class P2PMessage {}

class _MessageHandshake extends P2PMessage {
  final int timestamp;
  final String publicKey;
  final String dstKeyFingerprint;
  final Uint8List signature;
  _MessageHandshake(
      {required this.timestamp,
      required this.signature,
      required this.publicKey,
      required this.dstKeyFingerprint});
}

///////////////////////////////////////////////

enum EndpointType {
  server,
  client,
}

class _P2PSocket {
  final EndpointType endpointType;
  final Socket socket;
  String hostPkey = '';
  String hostFingerprint = '';
  final hostPkeyMeta;

  String endpointPkey = '';
  String endpointFingerprint = '';
  var endpointPkeyMeta;

  late StreamSubscription<Uint8List> streamSub;

  final StreamSink<P2PMessage> sink;
  void Function(Socket)? onClose = null;
  List<int> _buf = <int>[];
  int _expectingLen = 0;

  void _onDone() {
    if (onClose != null) onClose!(socket);
    if (endpointPkey != '') {
      sink.add(EventClientDisconnect(
          timestamp: _UnixEpoch(), publicKey: endpointPkey));
    }
  }

  /////// HACK: We're recursively parsing the message which may
  /////// provide extra overhead
  void _parseMessage(Uint8List data) {
    try {
      // Maximum 16 Kib
      _buf.addAll(data);
      if (_buf.length < _expectingLen) return;
      print('parsin message');

      // Encrypted data
      int encryptedLen = _list2Uint32(_buf);
      _buf.removeRange(0, 4);
      Uint8List listEncrypted = Uint8List(encryptedLen);
      List.copyRange<int>(listEncrypted, 0, _buf, 0, encryptedLen);
      _buf.removeRange(0, encryptedLen);

      // Signature
      int signatureLen = _list2Uint32(_buf);
      _buf.removeRange(0, 4);
      Uint8List listSignature = Uint8List(signatureLen);
      List.copyRange<int>(listSignature, 0, _buf, 0, signatureLen);
      _buf.removeRange(0, signatureLen);

      sink.add(
          MessageMessageE(signature: listSignature, encrypted: listEncrypted));
//      print('parsing successful');
//      print('encrypted ${listEncrypted}');
//      print('signature ${listSignature}');
    } catch (e) {
      print('parsing failed');
      socket.destroy();
      return;
    }
    streamSub.onData(_recvMessage);
    _recvMessage(Uint8List(0));
  }

  void _recvMessage(Uint8List data) {
    _buf.addAll(data);
    // Wait until we have received  "P2PGH" + uint32 handshake message length
    if (_buf.length < _expectingLen) return;
    print('Receiving message');

    // Check header (theres probably more efficient way)
    if (!(_buf[0] == 80 && // P
        _buf[1] == 50 && // 2
        _buf[2] == 71 && // G
        _buf[3] == 77)) {
      // H
      socket.destroy();
      print('invalid message header');
      return;
    }
    _buf.removeRange(0, 4);

    _expectingLen = _list2Uint32(_buf);
    _buf.removeRange(0, 4);
    print('message ok expecting ${_expectingLen} bytes');
    streamSub.onData(_parseMessage);
    _parseMessage(Uint8List(0));
  }

  // Primitive C-like parsing
  void _parseHandshake(Uint8List data) {
    try {
      // Maximum 16 Kib
      _buf.addAll(data);
      if (_buf.length < _expectingLen) return;
      print('parsing handshake');

      // timestamp 64 bit (network order)
      int timestamp = _list2Uint64(_buf);
      _buf.removeRange(0, 8);

      // dstKeyFingerprint
      int dstKeyFingerprintLen = _list2Uint32(_buf);
      _buf.removeRange(0, 4);
      List<int> listKeyFingerprint = List<int>.filled(dstKeyFingerprintLen, 0);
      List.copyRange<int>(listKeyFingerprint, 0, _buf, 0, dstKeyFingerprintLen);
      endpointFingerprint = String.fromCharCodes(listKeyFingerprint);
      _buf.removeRange(0, dstKeyFingerprintLen);

      // Pkey

      int pkeyLen = _list2Uint32(_buf);
      _buf.removeRange(0, 4);
      List<int> listPkey = List<int>.filled(pkeyLen, 0);
      List.copyRange<int>(listPkey, 0, _buf, 0, pkeyLen);
      endpointPkey = String.fromCharCodes(listPkey);
      _buf.removeRange(0, pkeyLen);

      // Signature
      int signatureLen = _list2Uint32(_buf);
      _buf.removeRange(0, 4);
      List<int> listSignature = List<int>.filled(signatureLen, 0);
      List.copyRange<int>(listSignature, 0, _buf, 0, signatureLen);

      _buf.removeRange(0, signatureLen);
      print('parsing successful');

      if (endpointType == EndpointType.client) _sendHandshake();
      sink.add(
          EventClientConnect(timestamp: timestamp, publicKey: endpointPkey));
    } catch (e) {
      print('parsing failure');
      socket.destroy();
      return;
    }
    streamSub.onData(_recvMessage);
    _expectingLen = 8;
    _recvMessage(Uint8List(0));
  }

  void _doHandshake(Uint8List data) {
    _buf.addAll(data);
    // Wait until we have received  "P2GP" + uint32 handshake message length
    if (_buf.length < 8) return;
    print('Doing handshake to client');

    // Check header (theres probably more efficient way)
    if (!(_buf[0] == 80 && // P
        _buf[1] == 50 && // 2
        _buf[2] == 71 && // G
        _buf[3] == 80)) {
      if (onClose != null) onClose!(socket);
      socket.destroy();
      print('handshake failed');
      return;
    }

    _buf.removeRange(0, 4);
    _expectingLen = _list2Uint32(_buf);
   // print('handshake successful expecting ${_expectingLen} bytes');
    // max 16kib
    if (_buf.length + data.length > 16 * 1024) {
      //print('exceeded max message length');
      if (onClose != null) onClose!(socket);
      socket.destroy();
      return;
    }
    _buf.removeRange(0, 4);
    streamSub.onData(_parseHandshake);
    _parseHandshake(Uint8List(0));
    return;
  }

  _sendHandshake() async {
//  4 bytes   |  The string "P2GP"
//  4 bytes   | Whole message length
//  8 bytes   |  Unix epoch in seconds
//  4 bytes   | Destination keyId length
//  ......    | dstKeyFingerprint
//  4 bytes   | PGP pkey length
//  ......    | PGP pkey
//  4 bytes   | PGP signature length
//  .......   | PGP signature of the above first 6 fields
    // Send P2GP Message
    // Header
    BytesBuilder b = BytesBuilder();

    b.add(_Uint64ToList(_UnixEpoch()));

    b.add(_Uint32ToList(endpointFingerprint.length));
    b.add(Uint8List.fromList(endpointFingerprint.codeUnits));

    b.add(_Uint32ToList(hostPkey.length));
    b.add(Uint8List.fromList(hostPkey.codeUnits));

    b.add(_Uint32ToList(0));
    b.add(Uint8List.fromList(''.codeUnits));

    socket.add(<int>[80, 50, 71, 80]);
    socket.add(_Uint32ToList(b.length));
    socket.add(b.toBytes());

    //s.write("DITTOOODDNNCKWKDMNCKFKSKSMCMSKLWLW");
    socket.flush();
  }

//  void _onData(Uint8List data) {
//    _buf.addAll(data);
//    // Parse Message
//    print('received ${_buf}');
//
//    // Parsed successfully? add message
//    sink.add(MessageMessageE(
//      signature: Uint8List(32),
//      encrypted: Uint8List(32),
//    ));
//  }

  _P2PSocket.endpointClient(
      {required this.socket,
      required this.hostPkey,
      required this.hostPkeyMeta,
      required this.sink,
      this.onClose})
      : endpointType = EndpointType.client {
    streamSub = socket.listen(_doHandshake, onDone: _onDone);
  }
  _P2PSocket.endpointServer(
      {required this.socket,
      required this.hostPkey,
      required this.hostPkeyMeta,
      required this.endpointFingerprint,
      required this.sink,
      this.onClose})
      : endpointType = EndpointType.server {
    _sendHandshake();
    streamSub = socket.listen(_doHandshake, onDone: _onDone);
  }
//  _P2PSocket(
//      {required this.serverPkey,
//      required this.serverPkeyMeta,
//      required this.clientFingerprint,
//      required this.socket,
//      required this.sink,
//      required this.isEndpointClient,
//      this.onClose}) {
//    if (!isEndpointClient)
//  }
}

///////////////////////////////////////////////

class P2PService {
  final int port;
  final String pkey;
  final serverPkeyMeta;
  Stream<P2PMessage>? events;
  late StreamController<P2PMessage> _streamController;
  late ServerSocket _server;

  List<_P2PSocket> _clients = <_P2PSocket>[];

 P2PService({this.port = 6573, required this.pkey, required this.serverPkeyMeta});

  _onClose(Socket socket) {
    print('Client disconnected');
    _clients.removeWhere((_P2PSocket client) => client.socket == socket);
  }

  _onClient(Socket client) {
    print('Client connected');
    _clients.add(_P2PSocket.endpointClient(
      socket: client,
      hostPkey: pkey,
      hostPkeyMeta: 1,
      sink: _streamController.sink,
      onClose: _onClose,
    ));
  }

  void ready() {
    _streamController = StreamController();
    events = _streamController.stream;
  }

  // returns 0, (false) if success
  Future<bool> connect(
      {required String address,
      required String keyFingerprint,
      int port = 6574}) async {
    try {
      Socket server = await Socket.connect(address, port);
      print('Manually connected');
      _clients.add(_P2PSocket.endpointServer(
        socket: server,
        hostPkey: pkey,
        hostPkeyMeta: 1,
        sink: _streamController.sink,
        endpointFingerprint: '',
        onClose: _onClose,
      ));
      return Future.value(false);
    } catch (e) {
      print(e);
      return Future.value(true);
    }
  }

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 6573);
    // Start serving clients. If anyone connects, begin handshake
    _server.listen(_onClient);
  }
}

class MessageMessageD extends P2PMessage {
  final int timestamp;
  final String mimeType;
  final Uint8List data;
  MessageMessageD(
      {required this.timestamp, required this.mimeType, required this.data});
}

// We store the encrypted message on the disk instead of
// the plain MessageMessageD.
class MessageMessageE extends P2PMessage {
  final Uint8List encrypted;
  final Uint8List signature;

  MessageMessageD decrypt(String skey) {
    return MessageMessageD(
      timestamp: 0,
      mimeType: 'application/text',
      data: Uint8List(4),
    );
  }

  MessageMessageE({required this.signature, required this.encrypted});
}

class EventClientConnect extends P2PMessage {
  final int timestamp;
  final String publicKey;
  EventClientConnect({required this.timestamp, required this.publicKey});
}

class EventClientDisconnect extends P2PMessage {
  final int timestamp;
  final String publicKey;
  EventClientDisconnect({required this.timestamp, required this.publicKey});
}

//void handleEvent(P2PMessage event) {
//  switch (event) {
//    case EventClientConnect(timestamp: var timestamp, publicKey: var publicKey):
//      print('client connect: ${timestamp} ${publicKey}');
//    case MessageMessageE(
//        signature: Uint8List listSignature,
//        encrypted: Uint8List listEncrypted
//      ):
//      print('client message: ${listSignature} ${listEncrypted}');
//    default:
//      ;
//  }
//}
//
//Future<void> main() async {
//  P2PService p2pService = P2PService(pkey: 'he', serverPkeyMeta: 1);
//  p2pService.ready();
//  p2pService.events?.listen(handleEvent);
//  await p2pService.start();
//  print('ok');
//  // p2pService.connect(address: "127.0.0.1", keyFingerprint: "", port: 6573);
//}
