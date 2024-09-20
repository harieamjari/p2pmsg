// setup.dart - Setup page for new users 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:openpgp/openpgp.dart';
import 'session.dart';


// Generate pgp keys for new users, else get password
// to decrypt pgp key
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  var name = '';
  var email = '';
  var password = '';
  var _isLoading = false;

  void _onSubmit() {
    setState(() => _isLoading = true);
    var keyOptions = KeyOptions()..rsaBits = 2048;
    final keyPair = OpenPGP.generate(
      options: Options()
        ..name = name
        ..email = email
        ..passphrase = password
        ..keyOptions = keyOptions
    );
    keyPair.then((key) async {
      PublicKeyMetadata metadata = await OpenPGP.getPublicKeyMetadata(key.publicKey);
      BonsoirService service = BonsoirService(
        name: metadata.fingerprint,
        type: '_p2pmsg._tcp',
        port: 6573
      );
      BonsoirBroadcast broadcast = BonsoirBroadcast(service: service);
      //await broadcast.ready;
      Navigator.pushReplacement<void, void>(
        context,
          MaterialPageRoute<void>(
            builder: (context) => SessionsPage(keyPair: key, service: service, broadcast: broadcast),
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
          onSubmitted: (String value) {
            name = value; 
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
          onSubmitted: (String value) {
            email = value; 
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
          onSubmitted: (String value) {
            password = value; 
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
