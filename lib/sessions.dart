import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';
import 'sessions.dart';

import 'p2pmsg.dart';
import 'utils.dart';

import 'session.dart';
import 'new_session.dart';

class SessionsPage extends StatefulWidget {
  // NOTE: must be in a secure memory to prevent being
  // swapped to the disk. 
  final String password;
  final KeyPair keyPair;

  final P2PService p2pService;

  SessionsPage(
      {super.key,
      required this.keyPair,
      required this.password}) : p2pService = P2PService(keyPair: keyPair, password: password) {
  }

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  //List<Session> sessions = <Session>[];
  Map<String, Session> sessions = {};
  bool _isBroadcast = false;
  bool _isLoading = true;

  _p2pInit() async {
    setState((){_isLoading = true;});
    widget.p2pService.events?.listen(_p2pEventHandler);
    await widget.p2pService.start(); 
    setState((){_isLoading = false;});
  }
  
  @override
  initState() {
    super.initState();
    _p2pInit();
  }

  @override
  dispose() {
    if (widget.p2pService.broadcastStatus != P2PBroadcastStatus.stopped ||
        widget.p2pService.broadcastStatus != P2PBroadcastStatus.stopping) widget.p2pService.broadcastStop();
    super.dispose();
  }

  _p2pEventHandler(P2PMessage event) {
    switch (event){
     case EventMessageText(senderFingerprint: String senderFingerprint, messageText: String messageText):
       // onMessage is a callback registered on _SessionPageState.initState().
       // It is only registered when we're actually in SessionPage.
       // Usually, it is just some setState().

//       if (sessions[senderFingerprint]!.onMessage != null)
//         sessions[senderFingerprint]!.onMessage!();
       print('recv EventMessageText');
       sessions[senderFingerprint]!.messages.insert(0, event);
       if (sessions[senderFingerprint]!.onMessage != null)
         sessions[senderFingerprint]!.onMessage!();
       //widget.session.messages.add(event);
       ScaffoldMessenger.of(context)
           .showSnackBar(SnackBar(content: Text(messageText)));
       break;
     case EventClientConnect(timestamp: int timestamp, name: String name, keyFingerprint: String keyFingerprint, socket: Socket socket):
        if (!sessions.containsKey(keyFingerprint))
            sessions.addAll(<String,Session>{
              keyFingerprint: Session(name: name, keyFingerprint: keyFingerprint, socket: socket, status: P2PEndpointStatus.active),
          });
        setState((){sessions[keyFingerprint]!.status = P2PEndpointStatus.active;}); 
        //widget.p2pService.sendMessageText(keyFingerprint, 'Al-buharie is the best programmer');
       break;
     case EventClientDisconnect(timestamp: int timestamp, keyFingerprint: String keyFingerprint):
        if (!sessions.containsKey(keyFingerprint)) return;
        sessions[keyFingerprint]!.status = P2PEndpointStatus.online; 
       break;
     case EventClientOnline(keyFingerprint: String keyFingerprint):
       if (sessions.containsKey(keyFingerprint))
         setState((){sessions[keyFingerprint]!.status = P2PEndpointStatus.online;});
       break;
     case EventClientOffline(keyFingerprint: String keyFingerprint):
       if (sessions.containsKey(keyFingerprint))
         setState((){sessions[keyFingerprint]!.status = P2PEndpointStatus.offline;});
       break;
     default:;
    }

  }

  Widget listSessionBuilder(BuildContext context, int index) {
    List<String> keys = sessions.keys.toList();
    Session session = sessions[keys[index]]!;
    return Card(
      child: ListTile(
        onTap: () {
          if (session.status == P2PEndpointStatus.online) {
            print('ontap');
            String ?address = widget.p2pService.resolve(session.keyFingerprint);
            if (address != null)
              widget.p2pService.connect(keyFingerprint: session.keyFingerprint, address: address!).then((b){
                if (!b)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('connected to ${session.keyFingerprint}:${address!}')));
                else 
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('connection failed')));
              });
          }
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SessionPage(
                      session: session,
                      p2pService: widget.p2pService,
                ),
            ),
          );
        },
        title: Text(session.name),
        subtitle: Text('fingerprint: ' + session.keyFingerprint),
        trailing: Icon(Icons.arrow_forward),
        leading: Icon(Icons.circle,
          color: (){
          switch(session.status){
            case P2PEndpointStatus.online: return Colors.yellow;
            case P2PEndpointStatus.offline: return Colors.grey;
            case P2PEndpointStatus.active: return Colors.green;
          }
        }(),
          size: 12.0,
        ), 
      ),
    );
  }

  Future<void> _onRefresh() {
    return Future.delayed(Duration(seconds: 2));
  }

  _bodyBuilder(context) {
    if (sessions.length == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _isLoading ? CircularProgressIndicator() : const Text('No available sessions'),
          ],
        ),
      ); // return
    }
    return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          itemCount: sessions.length,
          itemBuilder: listSessionBuilder,
        ));
  }

  _newSessions(Map<String, Session> msessions) {
    setState(() {
      sessions.addAll(msessions);
    });
    // Then Resolve sessions
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Color(0xFFE83F6F), //Theme.of(context).colorScheme.inversePrimary,

        title: const Text('Sessions', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          Switch(
            value: _isBroadcast,
            activeColor: Color(0xFF32936F),
            activeTrackColor: Colors.white,
            onChanged: (bool value) {
              if (_isLoading) return;
              if (widget.p2pService.broadcastStatus == P2PBroadcastStatus.starting ||
                  widget.p2pService.broadcastStatus == P2PBroadcastStatus.stopping) return;

              // If stopped, start it
              if (widget.p2pService.broadcastStatus == P2PBroadcastStatus.stopped) {
                assert(value == true);
                setState(() {
                  _isBroadcast = true;
                  widget.p2pService.broadcastStart();
                });
                // If started, stop it
              } else if (widget.p2pService.broadcastStatus == P2PBroadcastStatus.started) {
                assert(value == false);
                setState(() {
                  _isBroadcast = false;
                  widget.p2pService.broadcastStop();
                });
              }
            },
          ), // switch
        ],
      ),
      body: _bodyBuilder(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_isLoading) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Service is loading...')));
            return;
          }
          final bool newAdded = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => NewSessionPage(
                      userFingerprint: widget.p2pService.serverPkeyMeta.fingerprint,
                      sessions: this.sessions,
                      p2pService: widget.p2pService,
                    )),
          );
          if (newAdded) setState(() {});
        },
        tooltip: 'New session',
        child: const Icon(Icons.add, color: Colors.white),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
