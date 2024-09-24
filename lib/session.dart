import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';
import 'message.dart';

class Session { 
  final uuid;
  Session() : uuid = Uuid().v1();
}

class NewSessionPage extends StatefulWidget {
  final String userFingerprint;
  const NewSessionPage({super.key, required this.userFingerprint});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

// Discovers _p2pmsg._tcp services
class _NewSessionPageState extends State<NewSessionPage> {
  final BonsoirDiscovery discovery = BonsoirDiscovery(type: '_p2pmsg._tcp'); 
  List<BonsoirService> _services = <BonsoirService>[];

  _onTap (String name) {

  }

  Widget _listServicesBuilder(BuildContext context, int index) {
    return Card(
      child: ListTile(
        onTap: () => _onTap(_services[index].name),
        title: Text(
          (_services[index].attributes['userName'] ?? '') +
          ' <' + (_services[index].attributes['userEmail'] ?? '') + '>'
        ),
        subtitle: Text('fingerprint: ' + _services[index].name ?? ''),
        leading: Icon(Icons.account_circle_rounded),
      ),
    );
  }


  _onBonsoirDiscoveryEvent(BonsoirDiscoveryEvent event) {
    switch (event.type) {
      case BonsoirDiscoveryEventType.discoveryServiceFound:
        event.service!.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryEventType.discoveryServiceResolved:
      // ignore our own broadcast
        if (event.service != null /*&& event.service!.name != widget.userFingerprint*/)
          setState(() => _services.add(event.service!));
      case BonsoirDiscoveryEventType.discoveryServiceLost:
        setState(() => _services.removeWhere((service) => service.name == event.service?.name));
      default:;
    }
  }

  _bodyBuilder(context) {
    if (_services.length == 0) {
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
      itemCount: _services.length,
      itemBuilder: _listServicesBuilder,
    );
  }

  @override
  initState() {
    super.initState();
    discovery.ready.then((_) { 
      discovery.eventStream!.listen((event) =>
        _onBonsoirDiscoveryEvent(event)
      );
      discovery.start();
    });
  }

  @override
  dispose() {
    discovery.stop().then((_) => super.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, null);
        return Future.value(true);
      },
      child: 
        Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('New session', style: TextStyle(color: Colors.white)),
          ),
          body: _bodyBuilder(context),
        ), // Scaffold
    );
  }
}
















class SessionsPage extends StatefulWidget {
  final KeyPair keyPair;
  final BonsoirService service;
  final PublicKeyMetadata pkeyMetadata;

  const SessionsPage({
    super.key,
    required this.keyPair,
    required this.pkeyMetadata,
    required this.service
  });
    
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

enum BroadcastStatus {
  started,
  starting,
  stopped,
  stopping,
}

class _SessionsPageState extends State<SessionsPage> {
  List<Session> sessions = <Session>[];
  BonsoirBroadcast ?broadcast = null;
  BroadcastStatus _broadcastStatus = BroadcastStatus.stopped;
  bool _isBroadcast = false;


  Widget listSessionBuilder(BuildContext context, int index) {
    return Card(
      child: ListTile(
        title: Text('${index}'),
        subtitle: Text('${index} ' + sessions[index].uuid),
      ),
    );
  }

  _bodyBuilder(context) {
    if (sessions.length == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('No sessions'),
          ],
        ),
      ); // return
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: listSessionBuilder,
    );
  }

  _newSession(session) {
    setState(() {
      sessions.add(session);
    });
  }

  _onBonsoirBroadcastEvent(BonsoirBroadcastEvent event) {
    switch (event.type) {
      case BonsoirBroadcastEventType.broadcastStarted:
        _broadcastStatus = BroadcastStatus.started;
      case BonsoirBroadcastEventType.broadcastStopped:
        _broadcastStatus = BroadcastStatus.stopped;
      default:;
    }
  }

  @override
  dispose() {
    if (_broadcastStatus != BroadcastStatus.stopped ||
        _broadcastStatus != BroadcastStatus.stopping)
      broadcast?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Sessions', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          Switch(
            value: _isBroadcast,
            activeColor: Colors.green,
            onChanged: (bool value)  {
            // FIXME problem arises when user toggles switch very fast
              if (_broadcastStatus == BroadcastStatus.starting ||
                  _broadcastStatus == BroadcastStatus.stopping)
                return;


              // If stopped, start it
              if (_broadcastStatus == BroadcastStatus.stopped) {
                _broadcastStatus = BroadcastStatus.starting;
                assert(value == true); 
                setState(() { _isBroadcast = true; });
                broadcast = BonsoirBroadcast(service: widget.service);
                broadcast!.ready.then((_) {
                  broadcast!.eventStream?.listen((event) => 
                    _onBonsoirBroadcastEvent(event));
                  broadcast?.start();
                });
              // If started, stop it
              } else if (_broadcastStatus == BroadcastStatus.started) {
                _broadcastStatus = BroadcastStatus.stopping;
                assert(value == false); 
                setState(() { _isBroadcast = false; });
                broadcast?.stop();
              }
            },
          ), // switch
        ],
      ),
      body: _bodyBuilder(context),
      floatingActionButton: FloatingActionButton(
        //onPressed: newSession,
        onPressed: () async {
          final session = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewSessionPage(
                userFingerprint: widget.pkeyMetadata.fingerprint
              )
            ),
          );
          if (session != null) {
            _newSession(session);
          }
        },
        tooltip: 'New session',
        child: const Icon(Icons.add, color: Colors.white),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
