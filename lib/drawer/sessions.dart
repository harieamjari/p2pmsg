// drawer/sessions.dart - contains drawer pages
// Contains pages for about, settings, and 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PublicKeyInfoPage extends StatelessWidget {
  final PublicKeyMetadata publicKeyMetadata;
  final String publicKey;

  @override
  const PublicKeyInfoPage({super.key, required this.publicKey, required this.publicKeyMetadata});
  _pkeyText(context) {
    return Container(
      color: Color(0x10101010),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 60.0,
          maxHeight: 200.0,
    
      ),
      child: Expanded(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, 
            child: SelectableText(publicKey, style: TextStyle(fontFamily: 'Courier')),
          )
        )
      )
    );
  }
  _copyPkey(){
    return ElevatedButton.icon(
      onPressed: () {
      },
      icon: Icon(Icons.copy, color: Colors.black),
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 5),
        backgroundColor: Color(0xFFF2F2F2),
      ),
      label: const Text(
        "Copy",
        style: TextStyle(fontSize: 12, color: Colors.black),
      ),
    );
  }

  _header(context) {
    return Column(
      children: [
        Text(
          "Public key info",
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.0),
        _pkeyText(context),
        _copyPkey(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            SizedBox(height: 10.0),
            Text('userName: ${publicKeyMetadata.identities[0].name}'),
            Text('userEmail: ${publicKeyMetadata.identities[0].email}'),
            Text('algorithm: ${publicKeyMetadata.algorithm}'),
            Text('keyId: ${publicKeyMetadata.keyId}'),
            Text('keyIdShort: ${publicKeyMetadata.keyIdShort}'),
            Text('keyIdNumeric: ${publicKeyMetadata.keyIdShort}'),
            Text('isSubKey: ${publicKeyMetadata.isSubKey ? 'true' : 'false'}'),
            Text('canSign: ${publicKeyMetadata.canSign ? 'true' : 'false'}'),
            Text('canEncrypt: ${publicKeyMetadata.canEncrypt ? 'true' : 'false'}'),
          ],
        ),
      )
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  _header(context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image(image: AssetImage('assets/icon.jpg'), height: 150.0),
        ),
        Text(
          "p2pmsg",
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        //margin: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: AnimateList(
            interval: 400.ms,
            effects: [FadeEffect(duration: 400.ms)],
            children: [
              _header(context),
              Text("A peer to peer messaging over PGP"),
              SizedBox(height: 40),
              Text("https://github.com/harieamjari/p2pmsg"),
            ],
          ),
        ),
      ), // container
    );
  }
}

