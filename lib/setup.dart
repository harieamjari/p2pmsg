// setup.dart - Setup page for new users 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:openpgp/openpgp.dart';
import 'package:uuid/uuid.dart';
import 'sessions.dart';
import 'settings.dart';


// Generate pgp keys for new users, else get password
// to decrypt pgp key
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  String _name = '';
  String _email = '';
  String _password = '';
  bool _isLoading = false;

  String _fingerprintToHex(String str) {
    String builder = '';
    List<String> list = str.split(':');
    for (var i = 0; i < list.length; i++) {
      if (i > 1 && (i%2) == 0)
        builder += ' ';
      builder += int.parse(list[i]).toRadixString(16).padLeft(2, '0');
    }
    return builder;
  }

  void _onSubmit() {
    setState(() => _isLoading = true);
    var keyOptions = KeyOptions()..rsaBits = 2048;
    final keyPair = OpenPGP.generate(
      options: Options()
        ..name = _name
        ..email = _email
        ..passphrase = _password
        ..keyOptions = keyOptions
    );
    keyPair.then((key) async {
      PublicKeyMetadata metadata = await OpenPGP.getPublicKeyMetadata(key.publicKey);
      BonsoirService service = BonsoirService(
        name: _fingerprintToHex(metadata.fingerprint) +
             '-' + int.parse(DateTime.now().millisecondsSinceEpoch/1000).toRadixString(16),
        type: '_p2pmsg._tcp',
        port: P2PSettings.port,
        attributes: {
          'userName': _name,
          'userEmail': _email,
          'algorithm': metadata.algorithm,
          'keyId': metadata.keyId,
          'keyIdShort': metadata.keyIdShort,
          'keyIdNumeric': metadata.keyIdShort,
          'isSubKey': (metadata.isSubKey ? 'true' : 'false'),
          'canSign': (metadata.canSign ? 'true' : 'false'),
          'canEncrypt': (metadata.canEncrypt ? 'true' : 'false'),
          'uuid': Uuid().v1(),
        }
      );
      Navigator.pushReplacement<void, void>(
        context,
          MaterialPageRoute<void>(
            builder: (context) => SessionsPage(
              keyPair: key,
              pkeyMetadata: metadata,
              service: service),
          ),
      );
      setState(() => _isLoading = false);
    });
  }

  header(context) {
    return Column(
      children: [
        Text(
          "Setup",
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        Text("Let me know who you are"),
      ],
    );
  }

  inputField(context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (String value) {
            _name = value; 
          },
          decoration: InputDecoration(
              hintText: "Name",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none
              ),
              fillColor: Color(0xFFFFBF00).withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.person)),
        ), const SizedBox(height: 10),
        TextField(
          onChanged: (String value) {
            _email = value; 
          },
          decoration: InputDecoration(
              hintText: "Email",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none
              ),
              fillColor: Color(0xFFFFBF00).withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.email)),
        ), const SizedBox(height: 10),
        TextField(
          onChanged: (String value) {
            _password = value; 
          },
          obscureText: true,
          decoration: InputDecoration(
              hintText: "Password",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none
              ),
              fillColor: Color(0xFFFFBF00).withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.password)),
        ), const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () { if(!_isLoading) _onSubmit(); },
          icon: _isLoading
            ? Container(
                padding: const EdgeInsets.all(3.0),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.key, color: Colors.white),
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Color(0xFFE83F6F),
          ),
          label: const Text(
            "Generate key",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: AnimateList(
            interval: 400.ms,
            effects: [FadeEffect(duration: 400.ms)],
            children: [
              header(context),
              inputField(context),
            ],
          ),
        ),
      ), // container
    );
  }
}
