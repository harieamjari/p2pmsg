import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'sessions.dart';
import 'p2pmsg.dart';

class Session {
  final String uuid;
  final String name;
  final String keyFingerprint;
  void Function() ?onMessage;

  bool isOnline = false;
  Socket ?socket;

  List<String> messages = <String>[
    'this',
    'i',
    'send',
    'Alpha bravo charlie delta echo foxtrot golf hotel india juliet'
  ];
  List<EventMessageE> emessages = <EventMessageE>[];

  String toString() {
    return keyFingerprint;
  }

  Session({required this.name, required this.keyFingerprint, this.socket})
      : uuid = Uuid().v1();
}

class SessionPage extends StatefulWidget {
  Session session;
  SessionPage({required this.session});

  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final ScrollController _scrollController = ScrollController();
  String messageText = '';

  @override
  void initState() {
    super.initState();
    widget.session.onMessage = _onMessage;
  }

  @override
  void dispose() {
    super.dispose();
    widget.session.onMessage = null;
  }

  void _onMessage() {
    setState((){});
  }

  void _scrollDown() {
    _scrollController.animateTo(
      0.0,// _scrollController.position.maxScrollExtent,
      duration: Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  double ?_listItemExtentBuilder(int index, SliverLayoutDimensions dimensions) {
    if (index > widget.session.messages.length) return null;
    return 150.0; 
  }

  Widget _listMessageBuilder(BuildContext context, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(5.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 60.0),
            child: Container(
              padding: const EdgeInsets.all(7.0),
              child: Text(widget.session.messages[index],
                  style: TextStyle(fontSize: 16.0, color: Colors.white)),
              decoration: BoxDecoration(
                color: Color(0xFFFFBF00),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        //SizedBox(height: 8.0),
      ],
    );
//    return ListTile(
//      title: Text(widget.session.messages[index]),
//    );
  }

  Future<void> _onRefresh() {
    return Future.delayed(Duration(seconds: 1));
  }

  _bodyBuilder(context) {
    Session session = widget.session;
    if (widget.session.messages.length == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width / 2),
              child: Text(
                  'This might be the beginning of your legendary conversation with ${session.name}', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ); // return
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.session.messages.length,
        itemBuilder: _listMessageBuilder,
        reverse: true,
       // itemExtentBuilder: _listItemExtentBuilder,
      ),
    );
  }

  Widget build(BuildContext context) {
    var textController = TextEditingController();
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false);

        return Future.value(true);
      },
      child: Scaffold(
        appBar: AppBar(
          //backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          backgroundColor:
              Color(0xFFE83F6F), //Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Session', style: TextStyle(color: Colors.white)),
        ),
        body: Column(
          children: [
            Expanded(child: _bodyBuilder(context)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                    child: Container(
                        padding: EdgeInsets.fromLTRB(9,4,0,4),
                        constraints: BoxConstraints(maxHeight: 100.0),
                        child: TextField(
                          controller: textController,
                          onChanged: (String value) {messageText = value;},
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: "Message",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none),
                            fillColor: Color(0xFFFFBF00).withOpacity(0.1),
                            filled: true,
                            //prefixIcon: const Icon(Icons.email)
                          )))),
                Container(
                  child: IconButton(icon: Icon(Icons.send), color: Color(0xFF2274A5), onPressed: () {
                    textController.clear();
                    setState((){widget.session.messages.insert(0, messageText);});
                    messageText = '';
                    _scrollDown(); 
                  }),
                  padding: const EdgeInsets.fromLTRB(0,4,7,4),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ), // Scaffold
    );
  }
}

class NewSessionPage extends StatefulWidget {
  final String userFingerprint;
  final Map<String, Session> sessions;
  final P2PService p2pService;
  const NewSessionPage(
      {super.key, required this.userFingerprint, required this.sessions, required this.p2pService});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

// Discovers _p2pmsg._tcp services
class _NewSessionPageState extends State<NewSessionPage> {
  //final BonsoirDiscovery discovery = BonsoirDiscovery(type: '_p2pmsg._tcp');

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
          //_onTap(widget.p2pService.services[index]);
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
    super.dispose();
    widget.p2pService.onDiscoveryState = null;
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
       ScaffoldMessenger.of(context)
           .showSnackBar(SnackBar(content: Text(messageText)));
       break;
     case EventClientConnect(timestamp: int timestamp, name: String name, keyFingerprint: String keyFingerprint, socket: Socket socket):
        setState((){sessions.addAll(<String,Session>{
          keyFingerprint: Session(name: name, keyFingerprint: keyFingerprint, socket: socket),
        });});
       break;
     case EventClientDisconnect(timestamp: int timestamp, keyFingerprint: String keyFingerprint):
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
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SessionPage(
                      session: session,
                ),
            ),
          );
        },
        title: Text(session.name),
        subtitle: Text('fingerprint: ' + session.keyFingerprint),
        trailing: Icon(Icons.arrow_forward),
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
              if (_isLoading) {
                return;
              }
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
        //onPressed: newSession,
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
