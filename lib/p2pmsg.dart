/* p2pmsg.dart - core p2p protocol */

//  Session handshake message format.
//
//  All integers in network byte order.
//
//  Clients initiates connection with the following tcp message.
//
//  Handshake format:
//
//  Size      |  Field
//  4 bytes   |  The string "P2GP"
//  4 bytes   | Whole message length
//  8 bytes   |  Unix epoch in seconds
//  4 bytes   | dstKeyFingerprint  length
//  ......    | dstKeyFingerprint
//  4 bytes   | PGP pkey length
//  ......    | PGP pkey
//  4 bytes   | PGP signature length
//  .......   | PGP signature of epoch+dstKeyFingerprint+pkey
//
//
//  Message format:
//
//  4 bytes   | The string "P2GM"
//  4 bytes   | Whole message length
//  4 bytes   | encrypted data len
//  .....     | encrypted data (see msgdec)
//  4 bytes   | PGP signature length
//  ....      | PGP signature
//
//  msgdec:
//
//  Size      |    Field
//  8 bytes   | Unix epoch in seconds
//  4 bytes   | Mimetype length
//  ......    | Mimetype
//  4 bytes   | Data length
//  ......    | data

import 'package:bonsoir/bonsoir.dart';
import 'package:openpgp/openpgp.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'utils.dart';
import 'dart:async';
import 'utils.dart';
import 'dart:io';

import 'settings.dart';

sealed class P2PMessage {}

///////////////////////////////////////////////

enum _EndpointType {
  server,
  client,
}

enum P2PEndpointStatus {
  active,
  online,
  offline,
}

class _P2PSocket {
  final Socket socket;
  final KeyPair keyPair;
  final _EndpointType endpointType;
  final String Function() getPass;

  Map<String, _P2PSocket> activeClients;

  String hostPkey = '';
  String hostFingerprint = '';
  final PublicKeyMetadata hostPkeyMeta;

  String endpointPkey = '';
  String endpointFingerprint = '';
  late PublicKeyMetadata endpointPkeyMeta;

  bool msgSentBeforeAck = false;

  late StreamSubscription<Uint8List> streamSub;

  final StreamSink<P2PMessage> sink;
  void Function(Socket)? onClose = null;
  List<int> _buf = <int>[];
  int _expectingLen = 0;
  bool isAcked = false;

  Future<String> _signBytesToString(Uint8List blob) async {
    return await OpenPGP.signBytesToString(blob, keyPair.privateKey, getPass());
  }

  Future<Uint8List> _encryptBytes(Uint8List blob) async {
    return await OpenPGP.encryptBytes(blob, endpointPkey);
  }

  Future<bool> _verifyBytes(String sig, Uint8List blob) async {
    return await OpenPGP.verifyBytes(sig, blob, endpointPkey);
  }

  Future<Uint8List> _decryptBytes(Uint8List blob) async {
    return await OpenPGP.decryptBytes(blob, keyPair.privateKey, getPass());
  }

  Future<bool> destroy() {
    socket.destroy();
    return Future.value(false);
  }

  void _onDone() {
    if (onClose != null) onClose!(socket);
    if (msgSentBeforeAck) return;
    if (endpointPkey != '') {
      sink.add(EventClientDisconnect(
          timestamp: P2PUtils.UnixEpoch(), keyFingerprint: endpointFingerprint));
      print('event Client Disconnect added on _onDone');
      activeClients.remove(endpointFingerprint);
    }
  }

  void _parseMessageData(Uint8List data) {
    print('parsing message data');
  // So you and I won't have to scroll up and down again and again.
//  Size      |    Field
//  8 bytes   | Unix epoch in seconds
//  4 bytes   | Mimetype length
//  ......    | Mimetype
//  4 bytes   | Data length
//  ......    | data
    try {
      List<int> buf = <int>[];
      buf.addAll(data);
  
      // timestamp
      int timestamp = P2PUtils.List2Uint64(buf);
      buf.removeRange(0, 8);
      print('message timestamp ${timestamp}');
  
      // mimetype
      int mimeTypeLen = P2PUtils.List2Uint32(buf);
      print('message mimetypeLen ${mimeTypeLen}');
      buf.removeRange(0, 4);
      Uint8List listMimeType = Uint8List(mimeTypeLen);
      List.copyRange<int>(listMimeType, 0, buf, 0, mimeTypeLen);
      buf.removeRange(0, mimeTypeLen);
  
      // data
      int dataLen = P2PUtils.List2Uint32(buf);
      print('message datalen ${dataLen}');
      buf.removeRange(0, 4);
      Uint8List listData = Uint8List(dataLen);
      List.copyRange<int>(listData, 0, buf, 0, dataLen);
      
      String mimeType = P2PUtils.List2String(listMimeType);
      assert(mimeType == 'application/text');
  
      String message = P2PUtils.List2String(listData);
      sink.add(EventMessageText(timestamp: timestamp, senderFingerprint: endpointFingerprint, messageText: message, messageStatus: P2PMessageStatus.sent));
    } catch (e) {
      print('malformed message data ${e}');
      socket.destroy();
    }
  }
  /////// HACK: We're recursively parsing the message which may
  /////// provide extra overhead and we still need to deal with bigger file uploads
 //////// and kill the connection.
  void _parseMessage(Uint8List data) async {
    try {
      _buf.addAll(data);
      if (_buf.length < _expectingLen) return;
      print('parsin message');

      // Encrypted data
      int encryptedLen = P2PUtils.List2Uint32(_buf);
      _buf.removeRange(0, 4);
      Uint8List listEncrypted = Uint8List(encryptedLen);
      List.copyRange<int>(listEncrypted, 0, _buf, 0, encryptedLen);
      _buf.removeRange(0, encryptedLen);

      // Signature
      int signatureLen = P2PUtils.List2Uint32(_buf);
      _buf.removeRange(0, 4);
      Uint8List listSignature = Uint8List(signatureLen);
      List.copyRange<int>(listSignature, 0, _buf, 0, signatureLen);
      _buf.removeRange(0, signatureLen);
      print('verifying message agains epk');
      print(endpointPkey) ;
      if (await _verifyBytes(P2PUtils.List2String(listSignature), listEncrypted)) {
        print('verify ok');
        _parseMessageData(await _decryptBytes(listEncrypted));
      }
//      sink.add(
//          EventMessageE(signature: listSignature, encrypted: listEncrypted, senderFingerprint: endpointFingerprint));
//      print('parsing successful');
//      print('encrypted ${listEncrypted}');
//      print('signature ${listSignature}');
    } catch (e) {
      print('parsing failed ${e}');
      socket.destroy();
      return;
    }
    streamSub.onData(_recvMessage);
    _recvMessage(Uint8List(0));
  }

  void _recvMessage(Uint8List data) {
    _buf.addAll(data);
    // Wait until we have received  "P2GH" + uint32 handshake message length
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
    if (endpointType == _EndpointType.client && !isAcked) {
      print('endpoint was trying to send message before ACKP');
      msgSentBeforeAck = true;
      socket.destroy();
      return;
    }
    _buf.removeRange(0, 4);

    _expectingLen = P2PUtils.List2Uint32(_buf);
    _buf.removeRange(0, 4);
    print('message ok expecting ${_expectingLen} bytes');
    if (_expectingLen > 8 * 1024) {
      print('exceeded max message length ${_expectingLen}');
      if (onClose != null) onClose!(socket);
      socket.destroy();
      return;
    }
    streamSub.onData(_parseMessage);
    _parseMessage(Uint8List(0));
  }

  // Primitive C-like parsing
  void _parseHandshake(Uint8List data) {
    try {
    // FIXME: Make sure to drop client when they start pushing dangerously large data.
      // Maximum 16 Kib
//      if (_buf.length + data.length > _expectingLen) {
//        print('exceeded max message length ${_expectingLen}');
//        if (onClose != null) onClose!(socket);
//        socket.destroy();
//        return;
//      }
      _buf.addAll(data);
      if (_buf.length < _expectingLen) return;
      print('parsing handshake');
      BytesBuilder HandshakeBlob = BytesBuilder();


      // timestamp 64 bit (network order)
      int timestamp = P2PUtils.List2Uint64(_buf);
      HandshakeBlob.add(P2PUtils.Uint64ToList(timestamp));
      _buf.removeRange(0, 8);

      // dstKeyFingerprint
      int dstKeyFingerprintLen = P2PUtils.List2Uint32(_buf);
      _buf.removeRange(0, 4);
      List<int> listKeyFingerprint = List<int>.filled(dstKeyFingerprintLen, 0);
      List.copyRange<int>(listKeyFingerprint, 0, _buf, 0, dstKeyFingerprintLen);
      if (String.fromCharCodes(listKeyFingerprint) != hostFingerprint){
        print('handshake dstFingerprint mismatch ${String.fromCharCodes(listKeyFingerprint)}');
        socket.destroy();
        return;
      };
      HandshakeBlob.add(listKeyFingerprint);
      _buf.removeRange(0, dstKeyFingerprintLen);

      // Pkey

      int pkeyLen = P2PUtils.List2Uint32(_buf);
      _buf.removeRange(0, 4);
      List<int> listPkey = List<int>.filled(pkeyLen, 0);
      List.copyRange<int>(listPkey, 0, _buf, 0, pkeyLen);
      endpointPkey = String.fromCharCodes(listPkey);

      HandshakeBlob.add(listPkey);
      _buf.removeRange(0, pkeyLen);

      // Signature
      int signatureLen = P2PUtils.List2Uint32(_buf);
      _buf.removeRange(0, 4);
      List<int> listSignature = List<int>.filled(signatureLen, 0);
      List.copyRange<int>(listSignature, 0, _buf, 0, signatureLen);
      _buf.removeRange(0, signatureLen);

      print('parsing successful');

      OpenPGP.verifyBytes(String.fromCharCodes(listSignature), HandshakeBlob.toBytes(), endpointPkey).then((isValid){
        if (!isValid) {
          print('malformed signature');
          socket.destroy();
          return;
        }
        if (endpointType == _EndpointType.client) _sendHandshake();
        OpenPGP.getPublicKeyMetadata(endpointPkey).then((PublicKeyMetadata meta) {  
          endpointPkeyMeta = meta;
          endpointFingerprint = P2PUtils.fingerprintToHex(meta.fingerprint);
          sink.add(
              EventClientConnect(timestamp: timestamp, name: meta.identities[0].name,
                keyFingerprint: endpointFingerprint, socket: socket));
          activeClients.addAll(<String, _P2PSocket>{endpointFingerprint:this});
          print('event ClientConnect added');
          if (endpointType == _EndpointType.client && msgSentBeforeAck) {
            sink.add(EventClientDisconnect(
              timestamp: P2PUtils.UnixEpoch(), keyFingerprint: endpointFingerprint));
            print('event ClientDisconnect added. note before ackp');
            activeClients.remove(endpointFingerprint);
            return;
          }
          // write ACKP to client
          if (endpointType == _EndpointType.client) {
            socket.add(<int>[65, 67, 75, 80]);
            socket.flush();
            isAcked = true;
          }
        });
      });
    } catch (e) {
      print('parsing failure ${e}');
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
    print('Doing handshake to endpoint ${endpointType}');

    // Check header (theres probably more efficient way)
    if (!(_buf[0] == 80 && // P
        _buf[1] == 50 && // 2
        _buf[2] == 71 && // G
        _buf[3] == 80)) {
      if (onClose != null) onClose!(socket);
      socket.destroy();
      print('handshake failed, malformed handshake header ${endpointType}');
      print(_buf);
      return;
    }

    _buf.removeRange(0, 4);
    _expectingLen = P2PUtils.List2Uint32(_buf);
   // print('handshake successful expecting ${_expectingLen} bytes');
    // max 16kib
    if (_expectingLen > 16 * 1024) {
      print('exceeded max handshake length');
      if (onClose != null) onClose!(socket);
      socket.destroy();
      return;
    }
    _buf.removeRange(0, 4);
    streamSub.onData(_parseHandshake);
    _parseHandshake(Uint8List(0));
    return;
  }

  void _waitACKP(Uint8List data) {
    _buf.addAll(data);
    // Wait until we have received  "ACKP"
    if (_buf.length < 4) return;
    if (!(_buf[0] == 65 && // A
        _buf[1] == 67 && // C
        _buf[2] == 75 && // K
        _buf[3] == 80)) { // P
      print('malformed ACKP');
      print(_buf);
      socket.destroy();
      return;
    }
    _buf.removeRange(0, 4);
    print('Recevied ACKP');

    streamSub.onData(_doHandshake);
    _doHandshake(Uint8List(0));
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
    int epoch = P2PUtils.UnixEpoch();
    BytesBuilder HandshakeBlob = BytesBuilder();
    HandshakeBlob.add(P2PUtils.Uint64ToList(epoch));
    HandshakeBlob.add(P2PUtils.String2List(endpointFingerprint));
    HandshakeBlob.add(P2PUtils.String2List(hostPkey));
    String sig = await _signBytesToString(HandshakeBlob.toBytes());

    
    BytesBuilder b = BytesBuilder();


    b.add(P2PUtils.Uint64ToList(epoch));

    b.add(P2PUtils.Uint32ToList(endpointFingerprint.length));
    b.add(Uint8List.fromList(endpointFingerprint.codeUnits));

    b.add(P2PUtils.Uint32ToList(hostPkey.length));
    b.add(Uint8List.fromList(hostPkey.codeUnits));

    b.add(P2PUtils.Uint32ToList(sig.length));
    b.add(Uint8List.fromList(sig.codeUnits));

    socket.add(<int>[80, 50, 71, 80]);
    socket.add(P2PUtils.Uint32ToList(b.length));
    socket.add(b.toBytes());

    //s.write("DITTOOODDNNCKWKDMNCKFKSKSMCMSKLWLW");
    socket.flush();
    print('handshake sent');
  }

//  void _onData(Uint8List data) {
//    _buf.addAll(data);
//    // Parse Message
//    print('received ${_buf}');
//
//    // Parsed successfully? add message
//    sink.add(EventMessageE(
//      signature: Uint8List(32),
//      encrypted: Uint8List(32),
//    ));
//  }
  Future<bool> SendMessageText(String message) async {
//  8 bytes   | Unix epoch in seconds
//  4 bytes   | Mimetype length
//  ......    | Mimetype
//  4 bytes   | Data length
//  ......    | data
    // plaintextBlob
    BytesBuilder plainBlob = BytesBuilder();
    int timestamp = P2PUtils.UnixEpoch();
    plainBlob.add(P2PUtils.Uint64ToList(timestamp));
    plainBlob.add(P2PUtils.Uint32ToList(16));
    plainBlob.add(P2PUtils.String2List('application/text'));
    plainBlob.add(P2PUtils.Uint32ToList(message.length));
    plainBlob.add(P2PUtils.String2List(message));

    Uint8List encryptedBytes = await _encryptBytes(plainBlob.toBytes());
    print('Message text encrypted');
    Uint8List sigBytes = P2PUtils.String2List(await _signBytesToString(encryptedBytes));
    print('Encrypted signed');

//  Message format (msgenc)
//
//  4 bytes   | The string "P2GM"
//  4 bytes   | Whole message length
//  4 bytes   | encrypted data len
//  .....     | encrypted data (see msgdec)
//  4 bytes   | PGP signature length
//  ....      | PGP signature
    socket.add(<int>[80,50,71,77]);
    socket.add(P2PUtils.Uint32ToList(4+4 + encryptedBytes.length + sigBytes.length));
    socket.add(P2PUtils.Uint32ToList(encryptedBytes.length));
    socket.add(encryptedBytes);
    socket.add(P2PUtils.Uint32ToList(sigBytes.length));
    socket.add(sigBytes);
    socket.flush();
//    sink.add(EventMessageText(timestamp: timestamp, senderFingerprint: hostFingerprint, messageText: message));
     
    return Future.value(true);
  }

  _P2PSocket.endpointClient(
      {required this.socket,
      required this.keyPair,
      required this.hostPkeyMeta,
      required this.getPass,
      required this.activeClients,
      required this.sink,
      this.onClose})
      : endpointType = _EndpointType.client,
        hostPkey = keyPair.publicKey {
    hostFingerprint = P2PUtils.fingerprintToHex(hostPkeyMeta.fingerprint);
    streamSub = socket.listen(_doHandshake, onDone: _onDone);
  }
  _P2PSocket.endpointServer(
      {required this.socket,
      required this.keyPair,
      required this.hostPkeyMeta,
      required this.endpointFingerprint,
      required this.getPass,
      required this.activeClients,
      required this.sink,
      this.onClose})
      : endpointType = _EndpointType.server,
        hostPkey = keyPair.publicKey {
    _sendHandshake();
    hostFingerprint = P2PUtils.fingerprintToHex(hostPkeyMeta.fingerprint);
    streamSub = socket.listen(_waitACKP, onDone: _onDone);
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
enum P2PBroadcastStatus {
  starting,
  started,
  stopping,
  stopped,
}

class P2PService {
  final int port;
  Future<bool> isInit = Future.value(false);
  // XXX: MUST BE IN A SECURE MEMORY!!
  late KeyPair keyPair;
  late String serverPkey;
  late String serverSkey;

  late String serverFingerprint;

  String password = '';
  String getPass() {return password;}

  void Function() ?onDiscoveryState = null;

  late PublicKeyMetadata serverPkeyMeta;
  late BonsoirService _serverService;
  final BonsoirDiscovery discovery = BonsoirDiscovery(type: '_p2pmsg._tcp');

  Stream<P2PMessage>? events;
  final StreamController<P2PMessage> _streamController;
  late ServerSocket _server;
  List<ResolvedBonsoirService> services = <ResolvedBonsoirService>[];
  List<_P2PSocket> _clients = <_P2PSocket>[];
  Map<String, _P2PSocket> _activeClients = <String, _P2PSocket>{};

  BonsoirBroadcast? serverBroadcast = null;
  P2PBroadcastStatus broadcastStatus = P2PBroadcastStatus.stopped;

  Future<bool> _Init() async {
    serverPkeyMeta = await OpenPGP.getPublicKeyMetadata(serverPkey);
    serverFingerprint = P2PUtils.fingerprintToHex(serverPkeyMeta.fingerprint);
    return Future.value(true);
  }

  P2PService({this.port = P2PSettings.port, required this.keyPair, required this.password})
   :  _streamController = StreamController(),
      serverPkey = keyPair.publicKey,
      serverSkey = keyPair.privateKey
    {
    events = _streamController.stream;
    isInit = _Init();
  }


  String _yubiSplit(String? s) {
    return (s ?? '').split('-')[0];
  }

  _onClose(Socket socket) {
    print('Client disconnected');
    _clients.removeWhere((_P2PSocket client) => client.socket == socket);
  }

  _onClient(Socket client) {
    print('Client connected');
    _clients.add(_P2PSocket.endpointClient(
      socket: client,
      keyPair: keyPair,
      hostPkeyMeta: serverPkeyMeta,
      getPass: getPass,
      activeClients: _activeClients,
      sink: _streamController.sink,
      onClose: _onClose,
    ));
  }
  _onBonsoirDiscoveryEvent(BonsoirDiscoveryEvent event) {
    switch (event.type) {
      case BonsoirDiscoveryEventType.discoveryServiceFound:
        event.service!.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryEventType.discoveryServiceResolved:
        // ignore our own broadcast
        if (event.service !=
            null /*&& event.service!.name != widget.userFingerprint*/)
        if (event.isServiceResolved){
          services.add(event.service! as ResolvedBonsoirService);
          _streamController.sink.add(EventClientOnline(keyFingerprint: _yubiSplit(event.service?.name)));
        }
        if (onDiscoveryState != null)
          onDiscoveryState!();
      case BonsoirDiscoveryEventType.discoveryServiceLost:
        services
            .removeWhere((service) => service.name == event.service?.name);
        _streamController.sink.add(EventClientOffline(keyFingerprint: _yubiSplit(event.service?.name)));
        if (onDiscoveryState != null)
          onDiscoveryState!();
      default:
        ;
    }
  }

  void _onBonsoirBroadcastEvent(BonsoirBroadcastEvent event) {
    switch (event.type) {
      case BonsoirBroadcastEventType.broadcastStarted:
        broadcastStatus = P2PBroadcastStatus.started;
      case BonsoirBroadcastEventType.broadcastStopped:
        broadcastStatus = P2PBroadcastStatus.stopped;
      default:;
    }
  }

  void broadcastStart(){
    assert(broadcastStatus == P2PBroadcastStatus.stopped);
    broadcastStatus = P2PBroadcastStatus.starting;
    serverBroadcast = BonsoirBroadcast(service: _serverService);
    serverBroadcast!.ready.then((_) {
      serverBroadcast!.eventStream
          ?.listen((event) => _onBonsoirBroadcastEvent(event));
      serverBroadcast?.start();
    });
  }
  void broadcastStop(){
    assert(broadcastStatus == P2PBroadcastStatus.started);
    broadcastStatus = P2PBroadcastStatus.stopping;
    serverBroadcast?.stop();
  }

  // Kills the active connection associated with keyFingerprint.
  // returns false if succes.s
  Future<bool> destroy(String keyFingerprint) async {
    if (!_activeClients.containsKey(keyFingerprint)) {
      print('no such active client with ${keyFingerprint}');
      return Future.value(true);
    }
    
    _P2PSocket p2p = _activeClients[keyFingerprint]!;
    return await p2p.destroy();
  }

  // returns 0, (false) if success
  Future<bool> connect(
      {required String address,
      required String keyFingerprint,
      int port = P2PSettings.port}) async {
    try {
      Socket server = await Socket.connect(address, port);
      print('Manually connected');
      _clients.add(_P2PSocket.endpointServer(
        socket: server,
        keyPair: keyPair,
        hostPkeyMeta: serverPkeyMeta,
        getPass: getPass,
        activeClients: _activeClients,
        sink: _streamController.sink,
        endpointFingerprint: keyFingerprint,
        onClose: _onClose,
      ));
      return Future.value(false);
    } catch (e) {
      print(e);
      return Future.value(true);
    }
  }

  // returns an address to be used with connect method
  // the address returned doesn't necessarily they're are the real deal and not just impersonating as someone.
  String ?resolve(String keyFingerprint){
    for (int i = 0; i < services.length; i++){
      if (keyFingerprint != services[i].name.split('-')[0])
        continue;
      return services[i].host;
    }
    return null;
  }

  Future<void> start() async {
    await isInit;
    _serverService = BonsoirService(
      name: P2PUtils.fingerprintToHex(serverPkeyMeta.fingerprint) +
           '-' + P2PUtils.UnixEpoch().toRadixString(16),
      type: '_p2pmsg._tcp',
      port: port,
      attributes: {
        'userName': serverPkeyMeta.identities[0].name,
        'userEmail': serverPkeyMeta.identities[0].email,
        'algorithm': serverPkeyMeta.algorithm,
        'keyId': serverPkeyMeta.keyId,
        'keyIdShort': serverPkeyMeta.keyIdShort,
        'keyIdNumeric': serverPkeyMeta.keyIdShort,
        'isSubKey': (serverPkeyMeta.isSubKey ? 'true' : 'false'),
        'canSign': (serverPkeyMeta.canSign ? 'true' : 'false'),
        'canEncrypt': (serverPkeyMeta.canEncrypt ? 'true' : 'false'),
        'uuid': Uuid().v1(),
      }
    );
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, P2PSettings.port);
    // Start serving clients. If anyone connects, begin handshake
    _server.listen(_onClient);
    await discovery.ready;
    discovery.eventStream!.listen((event) => _onBonsoirDiscoveryEvent(event));
    await discovery.start();
  }

  // returns false if success
  Future<bool> SendMessageText(String fingerprint, String message) async {
    if (!_activeClients.containsKey(fingerprint)) {
      print('no such active client with ${fingerprint}');
      return Future.value(true);
    }
    
    _P2PSocket p2p = _activeClients[fingerprint]!;
    return await p2p.SendMessageText(message);
  }
}

class MessageDecrypted {
  final int timestamp;
  final String mimeType;
  final Uint8List data;
  MessageDecrypted(
      {required this.timestamp, required this.mimeType, required this.data});
}


// Messages of Text Media or Pictures are supposedly to be encrypted

enum P2PMessageStatus {
  sent,
  sending,
  failed,
}

class EventMessageText extends P2PMessage {
  P2PMessageStatus messageStatus;
  final int timestamp;
  final String senderFingerprint;
  String messageText;
  EventMessageText({
    required this.messageStatus,
    required this.timestamp,
    required this.senderFingerprint,
    required this.messageText,
  });
}

class EventMessageFile extends P2PMessage {
  P2PMessageStatus messageStatus;
  final int timestamp;
  final String senderFingerprint;
  final String mimeType;
  final String filename;
  final Uint8List data;
  EventMessageFile({
    required this.messageStatus,
    required this.timestamp,
    required this.senderFingerprint,
    required this.mimeType,
    required this.filename,
    required this.data,
  });
}

class EventClientConnect extends P2PMessage {
  final int timestamp;
  final String name;
  final String keyFingerprint;
  final Socket socket;
  EventClientConnect({required this.timestamp, required this.name, required this.keyFingerprint, required this.socket});
}

class EventClientDisconnect extends P2PMessage {
  final int timestamp;
  final String keyFingerprint;
  EventClientDisconnect({required this.timestamp, required this.keyFingerprint});
}

class EventClientOnline extends P2PMessage {
  final String keyFingerprint;
  EventClientOnline({required this.keyFingerprint});
}

class EventClientOffline extends P2PMessage {
  final String keyFingerprint;
  EventClientOffline({required this.keyFingerprint});
}

class EventBroadcastStarted extends P2PMessage {
  EventBroadcastStarted();
}

class EventBroadcastStopped extends P2PMessage {
  EventBroadcastStopped();
}

//void handleEvent(P2PMessage event) {
//  switch (event) {
//    case EventClientConnect(timestamp: var timestamp, publicKey: var publicKey):
//      print('client connect: ${timestamp} ${publicKey}');
//    case EventMessageE(
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
//  p2pService.events?.listen(handleEvent);
//  await p2pService.start();
//  print('ok');
//  // p2pService.connect(address: "127.0.0.1", keyFingerprint: "", port: 6573);
//}
