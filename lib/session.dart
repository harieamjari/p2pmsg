import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Session { 
  final uuid;
  Session() : uuid = Uuid().v1();
}

class NewSessionPage extends StatelessWidget {
  final String title;
  const NewSessionPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, null);
        return Future.value(null);
      },
      child: 
        Scaffold(
          appBar: AppBar(
            // TRY THIS: Try changing the color here to a specific color (to
            // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
            // change color while the other colors stay the same.
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            // Here we take the value from the SessionsPage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text(title),
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
  final String title;
  const SessionsPage({super.key, required this.title});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<Session> sessions = <Session>[];
  int nbSessions = 0;

  Widget listSessionBuilder(BuildContext context, int index) {
    return Card(
      child: ListTile(
        title: Text('${index}'),
        subtitle: Text('${index} ' + sessions[index].uuid),
      ),
    );
  }

  void newSession(session) {
    setState(() {
      sessions.add(session);
      nbSessions++;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the SessionsPage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: () {
        if (nbSessions == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'No sessions',
                ),
              ],
            ),
          ); // return
        }
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: listSessionBuilder,
        );
      }(),
      floatingActionButton: FloatingActionButton(
        //onPressed: newSession,
        onPressed: () async {
          final session = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewSessionPage(title: 'New session')),
          );
          if (session != null) {
            newSession(session);
          }
        },
        tooltip: 'New session',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
