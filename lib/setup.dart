// setup.dart - Setup page for new users 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:openpgp/openpgp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'utils.dart';
import 'sessions.dart';
import 'settings.dart';


// Generate pgp keys for new users, else get password
// to decrypt pgp key

enum SetupState {
  stateNew,
  stateLogin,
  stateLoading,
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _secureStorage = const FlutterSecureStorage();
  String _name = '';
  String _email = '';
  String _password = '';
  String _b64Key = '';
  String _b64IV = '';
  bool _isLoading = false;
  SetupState _state = SetupState.stateLoading;
  //bool _isFinished = false;

  @override
  initState(){
    super.initState();
  }
  void _onSubmit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    var keyOptions = KeyOptions()..rsaBits = 4096;
    final keyPair = await OpenPGP.generate(
      options: Options()
        ..name = _name
        ..email = _email
        ..passphrase = _password
        ..keyOptions = keyOptions
    );
    // 256 bit key
    final key = encrypt.Key(Uint8List.fromList(sha256.convert(_password.codeUnits).bytes));
    final iv = encrypt.IV.fromLength(16);
    final encrypted = encrypt.Encrypter(encrypt.AES(key)).encrypt(keyPair.privateKey, iv: iv);
    await _secureStorage.write(key: 'secretKey', value: encrypted.base64);
    await _secureStorage.write(key: 'iv', value: iv.base64);
//// Dummy pgp key
//    var keyPair = Future<KeyPair>.value(KeyPair(
//    '''
//-----BEGIN PGP PUBLIC KEY BLOCK-----
//Version: Keybase OpenPGP v1.0.0
//Comment: https://keybase.io/crypto
//
//xsBNBGcXCAUBCAC7eNXpXl9oEZI97UDTk/g5wv7sV8gbVs3ChPteIh3xzCP+IhvQ
//F11eB+8CwxxosqjXWuRpoOG5ZPxO8rpvAvMejDARKrS25u3Y+xQia3ZJNpgWlqhW
//HuphG6nneonZvxqeJhgfRSxBFN6HjKjtc40g2bh2YbWFdw13IihwO3z2FvGWwULq
//HBOwBhiUIPiAR2hXRYEtCrbr3p2SJQphItolx+mDeG2gkgbC4NxEBDGxupb/pnCH
//v3keQgOrQeSdlx06/wqdxk/XwdDuq1sKyZs8TWtfHCIoluo9m+XVBetEw9vUx99t
//tC4ZZGjS5hgavmwgi+3tYxpKFnGNQJZygeM/ABEBAAHNGUpvaG4gRG9lIDxqb2hu
//LmRvZUBnLmNvbT7CwG0EEwEKABcFAmcXCAUCGy8DCwkHAxUKCAIeAQIXgAAKCRDX
//lYXhKOyOu5FpCACW19ka8X4EiiPP5vgnAg4cWFQL6WmTOy//9T53vod62NoCp1gA
//tEWXEtZBPG7iJx8Kgz1jwHKN9eSG4OTdjWD3UfSF+4XXLp7ViUbBwcmZ5HJZN6Wi
//X1LIdG7DsgToPBgIbLhe7tJFWIBR59B+CryOfup4mGNLEJj4paWaAgYsdW/KVIkR
//lbue1em4m+aN0qBzfoFWawakRbzugQprIdpZvSTSKXrK08Al0w+uMC4c60PFaib6
//1Clr9aX01afPvmXNXE2cb1LAt8ME3P96PwMzjZ+AWOWv7+wYYtc0fTk7N8T1oVmd
//tRAHrGHihYMPSto4HcP4avuSW0UqPPIikQ9KzsBNBGcXCAUBCADgUPsVfLPkFaLJ
//yaJ8D735dxTFSiP0N5WRp6xIe9hTmC0tiaoCWeiW4COyYXaoEKG2P1606ohU24Pn
//rORa9MYyW1Li0xbQSk1MJ20qL3owHEdSrtwB1D/mVxh1DdIkOfZYRoOkx7Y6H/Vr
//CDe2Qeft12cClZ2fJFFXrrPXCWIUxKrEuV4PQgrSFw+UdM8VuBW+6Fac/UME7ppr
//8yS5BIF8M6SGIKrSrCcdqZDz95xMeIcnbDEwbRWSmPx6y/ez6Sv4B30aIU0STHu/
//mOOVP7UwZ/zTyWBt1aMuQlhCldnOHO3Vy+VpKjR60nPjYzeKP8w/skuCNnWLTWXb
//rxI4i0fPABEBAAHCwYQEGAEKAA8FAmcXCAUFCQ8JnAACGy4BKQkQ15WF4SjsjrvA
//XSAEGQEKAAYFAmcXCAUACgkQHx/ZUmhW+YZz5gf/dPpDmNfAoIR7qlwN+a2jBcHq
//zwpdsyVo0DWyNaqqBt4N9X1GCcgKju8s9gmpmaCT3JyXV6XCJgpwAgCNj4mx+AU3
//Vxav3+dpQb+iFKvxAF67pYY0VhJW2CtdihU822sj7AHOxCkzOaageFO/QClD8qdk
//Cxkd/N+aYOtmHDwEVEUwCkFCHDGbS95XM5EFefTKfKNbGafnMpros/DMTHaN+iyn
//mJTyfsLRjwVT+KtVjxIjbl0HhfIwO7d5KtAUpdHXpzg598is8Gg8/F9srJysSdGF
//Xa48wGuGJqBqw7LaaQl9y75Sf0d9QVx5rd/YXYPb824XchiYm/bN5wRNTawTgXD/
//CACqZnWVp8jMc29ZchTTb0zfLCOjsaNVSvgHMLewQ+2xj2Vpxe61IKJQD5GaJtB5
//eNLK0rHl0egHpoub/lDrQtOK2Qna90oXjwbnA7KFW3uNL8Ij6x+aLzHgOC5IjKst
//9NZhbgtcfU4Ke6psjCtwamSYLDkEZ4zIlEQDfrXwqbXf3afcSx1IPTzcSr51pc5a
//oqe2wH5tYXM/Tob7j5UBKK6akquikwX6wuWqi9YmwZib3DNWqxAdgxqFMXi6dx6p
//EjLmJJngsE3HFkUSn6e8olDAs4tDoaiZXKLUw/RcfoqDRMAZAgymrczvfMiJ7T+k
///K0aOdyB8cmNtBtEmYBjscC1zsBNBGcXCAUBCADUESQJCyA+eELRnc8q2BKbiHQe
//NBHIdoTEYa1E5Av0mOuB21Extb66W3QKqzpYymbPHmVCf3f8vGoNkSZ4/H5d2pp3
//W8DLm68ElWCHokx7RVb7zYDJHBkxs9GLWJDPF9NQ1nqxszz0GOoEBrvlz2Es3NAZ
//HH6zY9+fH/CVjYE2ZPONxFOWwZKGrkXCimC2cc+vfVXv9z+RXB03H1Lx+Lk55RqF
//b7IBGbJ1gY/xLtJXb7mHOBbK8LYMR73wS5zo20YGZJ/5rDDTzuGlLpX+B/Vl1lu3
//8VKTJMavKTPM6ur5hcMfFgks6vVVYfq7rZBix0rsI/LKBXlGD4hdweWH9xbXABEB
//AAHCwYQEGAEKAA8FAmcXCAUFCQ8JnAACGy4BKQkQ15WF4SjsjrvAXSAEGQEKAAYF
//AmcXCAUACgkQwypGXBNNNYY2Ggf+IO2egnE/jlApVQbEKFtGAJaPM2K4+rg5urD5
//IhPjVAUtlRYeJD+KPtqOEoCtNra6bbzG0ABzmTB1u4OMs94GxMJvWj7QsBdijd2e
//msKafmL53sZttOYSDmafploCwUlIn8IvDE8OMr0SPzPPJ/rfV9HJS/chI5bGuTJx
//FSuIRnp4Mja7VTUDnRg71RDiavCnTgXe72z7ylrcw9kgSPlTQOaS3nW4K444n7GC
//xfpkeAaK+WTWIYth7bpksLNsHTHGXsDs1FFgFYAQ5p5j8WAZrOW0JcywOgqZibl7
//yJFymVcNiKYK0YTUmZ+EBVBT23Hpw/jwsGk7xCfv5MPRJMJc7z5oB/9VL02mOUiu
//GJSDjnPA6PQyPOlEWUeTQElbqU8EnWkmEEfBX/fj5KglyS0v2myURMjlNKvQySGK
//84AOkhdugJ169kOaf2hN8G/vpFFOwXmPIBc8vmozQuZxzWhPLx6xQu8GgO2B1B/z
//HCoPDmOZUpmw/5CJ6Edru7AzqKgM1r6jqRo0AgWqT97Nf/is5obcQLtIsIy87TzZ
//weZpDF66CsMj8cgUQH8H7pKVGhjCJWW+8Ras2dZbGUMAj5GdTvpWXMV4JfUyv35P
//LnSMvC3oa0UJXkpBiBGLZke6eQaahTKrNMOMKeuBYTzqdPtB5nxG6XRidG7lItfi
//TqbLzuS2Te1c
//=uXZB
//-----END PGP PUBLIC KEY BLOCK-----
//''',
//'''
//-----BEGIN PGP PRIVATE KEY BLOCK-----
//Version: Keybase OpenPGP v1.0.0
//Comment: https://keybase.io/crypto
//
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
//=VLKT
//-----END PGP PRIVATE KEY BLOCK-----
//'''));
    //print(key.publicKey);
    //print(key.privateKey);
    PublicKeyMetadata metadata = await OpenPGP.getPublicKeyMetadata(keyPair.publicKey);
    Navigator.pushReplacement<void, void>(
      context,
        MaterialPageRoute<void>(
          builder: (context) => SessionsPage(
            keyPair: keyPair,
            password: _password),
        ),
    );
    //_isFinished = true;
    //setState(() => _isLoading = false);
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

  String ?_errorTextName = null;
  String ?_errorTextEmail = null;
  String ?_errorTextPassword = null;

  inputFieldLogin(context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (String value) {
            _password = value; 
            setState(() => _errorTextPassword = _validateLoginPassword());
          },
          obscureText: true,
          decoration: InputDecoration(
              hintText: "Password",
              errorText: _errorTextPassword,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none
              ),
              fillColor: Color(0xFFFFBF00).withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.password)),
        ), const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () async {
            if (_validateLoginPassword() != null) return;
            if(_isLoading) return;
            setState(() => _isLoading = true);
            final key = encrypt.Key(Uint8List.fromList(sha256.convert(_password.codeUnits).bytes));
            final iv = encrypt.IV.fromBase64(_b64IV);
            try {
              final String secretKey = encrypt.Encrypter(encrypt.AES(key)).decrypt(encrypt.Encrypted.fromBase64(_b64Key), iv: iv);
              final KeyPair keyPair = KeyPair(await OpenPGP.convertPrivateKeyToPublicKey(secretKey), secretKey);
              PublicKeyMetadata metadata = await OpenPGP.getPublicKeyMetadata(keyPair.publicKey);
              Navigator.pushReplacement<void, void>(
                context,
                  MaterialPageRoute<void>(
                    builder: (context) => SessionsPage(
                      keyPair: keyPair,
                      password: _password),
                  ),
              );
            } catch (e) {
              setState((){
                _isLoading = false;
                _errorTextPassword = 'Invalid password';
              });
            } // catch
          },
          icon: _isLoading
            ? Container(
                padding: const EdgeInsets.all(1.0),
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
            "Decrypt key",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  String ?_validateName() {
    if (_name.length == 0) return 'Name can\'t be empty';
    if (_name.length > 64) return 'Name is too long';
    final nameRegex = RegExp(r'^[A-Za-z\ \.-]+$');
    if (!nameRegex.hasMatch(_name)) return 'Name must not contain numbers or special characters';

    return null;
  }
  String ?_validateEmail() {
    if (_email.length == 0) return 'Email can\'t be empty';
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_email)) return 'Please enter a valid email';
    return null;
  }
  String ?_validatePassword() {
    if (_password.length == 0) return 'Password can\'t be empty';
//    final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$');
//    if (!passwordRegex.hasMatch(_password)) return 'Must contain atleast one letter, one number and one special character';
    return null;
  }
  String ?_validateLoginPassword() {
    if (_password.length == 0) return 'Password can\'t be empty';
    return null;
  }
  inputField(context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (String value) {
            _name = value;
            setState(() => _errorTextName = _validateName());
          },
          decoration: InputDecoration(
              hintText: "Name",
              errorText: _errorTextName,
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
            setState(() => _errorTextEmail = _validateEmail());
          },
          decoration: InputDecoration(
              hintText: "Email",
              errorText: _errorTextEmail,
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
            setState(() => _errorTextPassword = _validatePassword());
          },
          obscureText: true,
          decoration: InputDecoration(
              hintText: "Password",
              errorText: _errorTextPassword,
              errorMaxLines: 3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none
              ),
              fillColor: Color(0xFFFFBF00).withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.password)),
        ), const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            if (!(_validateEmail() == null &&
                  _validateName() == null &&
                  _validatePassword() == null)) return;
            if(!_isLoading) _onSubmit();
          },
          icon: _isLoading
            ? Container(
                padding: const EdgeInsets.all(1.0),
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

  _stateNew(context) {
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

  _stateLogin(context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: AnimateList(
            interval: 400.ms,
            effects: [FadeEffect(duration: 400.ms)],
            children: [
//              headerLogin(context),
              inputFieldLogin(context),
            ],
          ),
        ),
      ), // container
    );

  }

  _stateLoading(context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: AnimateList(
            interval: 200.ms,
            effects: [FadeEffect(duration: 400.ms)],
            children: [
              CircularProgressIndicator(),
            ],
          ),
        ),
      ), // container
    );
  }

  @override
  Widget build(BuildContext context) {
    _secureStorage.read(key: 'secretKey').then((String ?b64) async {
      if (_state != SetupState.stateLoading) return;
      if (b64 == null) {
        setState(() => _state = SetupState.stateNew);
        return;
      }
      _b64Key = b64!;
      String ?temp = await _secureStorage.read(key: 'iv');
      assert(temp != null);
      _b64IV = temp!;
      // User has already registered, now login,
      setState(() => _state = SetupState.stateLogin);
    });
    
    switch (_state) {
      case SetupState.stateLoading:
        return _stateLoading(context);
      case SetupState.stateNew:
        return _stateNew(context);
      case SetupState.stateLogin:
        return _stateLogin(context);
    }
  }
}
