import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';

import 'p2pmsg.dart';
import 'utils.dart';
import 'session.dart';


class NewSessionPage extends StatefulWidget {
  final String userFingerprint;
  final Map<String, Session> sessions;
  final P2PService p2pService;
  const NewSessionPage(
      {super.key, required this.userFingerprint, required this.sessions, required this.p2pService});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage> {
  bool _newAdded = false;

  String _yubiSplit(String? s) {
    return (s ?? '').split('-')[0];
  }

  Future<void> _onRefresh() {
    if (widget.p2pService.services.length != 0)
      setState((){});
    return Future.delayed(Duration(seconds: 2));
  }

  void _onDiscovery(){
    setState((){});
  }

  Widget _listServicesBuilder(BuildContext context, int index) {
    return Card(
      child: ListTile(
        onTap: () {
          BonsoirService service = widget.p2pService.services[index];
          String name = _yubiSplit(service.name);
          if (widget.sessions.containsKey(name))
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('User already exist')));
          else {
            _newAdded = true;
            widget.sessions.addAll(<String, Session>{
              '${name}': Session(
                name: service.attributes['userName'] ?? '',
                status: P2PEndpointStatus.online,
                keyFingerprint: name,
              )
            });
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Added')));
          }
        },
        title: Text((widget.p2pService.services[index].attributes['userName'] ?? '') +
            ' <' +
            (widget.p2pService.services[index].attributes['userEmail'] ?? '') +
            '>'),
        subtitle: Text('fingerprint: ' + widget.p2pService.services[index].name ?? ''),
        leading: Icon(Icons.account_circle_rounded),
      ),
    );
  }


  _bodyBuilder(context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: () {
        if (widget.p2pService.services.length == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('No available users'),
              ],
            ),
          ); // return
        }
        return ListView.builder(
          itemCount: widget.p2pService.services.length,
          itemBuilder: _listServicesBuilder,
        );
      }(),
    );
  }

  @override
  initState() {
    widget.p2pService.onDiscoveryState = _onDiscovery;
    super.initState();
  }

  @override
  dispose() {
    widget.p2pService.onDiscoveryState = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _newAdded);

        return Future.value(true);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFE83F6F),
          title:
              const Text('New session', style: TextStyle(color: Colors.white)),
        ),
        body: _bodyBuilder(context),
      ), // Scaffold
    );
  }
}
