import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

class Session { 
  final uuid;
  Session() : uuid = Uuid().v1();
}

class NewSessionPage extends StatelessWidget {
  const NewSessionPage({super.key});

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
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, Session());
              },
              child: const Text('Ok'),
            ),
          ),// center
        ), // Scaffold
    );
  }
}

class SessionsPage extends StatefulWidget {
  final KeyPair keyPair;
  final BonsoirService service;
  final BonsoirBroadcast broadcast;

  const SessionsPage({
    super.key,
    required this.keyPair,
    required this.service,
    required this.broadcast
  });

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<Session> sessions = <Session>[];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Sessions', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _bodyBuilder(context),
      floatingActionButton: FloatingActionButton(
        //onPressed: newSession,
        onPressed: () async {
          final session = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewSessionPage()),
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
