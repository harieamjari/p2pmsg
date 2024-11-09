import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:openpgp/openpgp.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';

import 'p2pmsg.dart';
import 'utils.dart';
import 'quotes.dart';

class Session {
  final String uuid;
  final String name;
  final String keyFingerprint;
  void Function() ?onMessage;
  P2PEndpointStatus status;

  // Are they online?
  bool isOnline = false;

  Socket ?socket;

//  List<String> messages = <String>[
//    'this',
//    'i',
//    'send',
//    'Alpha bravo charlie delta echo foxtrot golf hotel india juliet'
//  ];
  List<P2PMessage> messages = <P2PMessage>[];

  String toString() {
    return keyFingerprint;
  }

  Session({required this.name, required this.keyFingerprint, this.socket, this.status = P2PEndpointStatus.offline})
      : uuid = Uuid().v1();
}

class SessionPage extends StatefulWidget {
  Session session;
  P2PService p2pService;
  SessionPage({required this.session, required this.p2pService});

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
    if (widget.session.messages.length != 1) 
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

  String _messageStatus(P2PMessageStatus msgStatus){
    switch (msgStatus){
      case P2PMessageStatus.sent: return 'sent';
      case P2PMessageStatus.sending: return 'sending';
      case P2PMessageStatus.failed: return 'failed';
    }
    // unreachable
    assert(false);
  }

  Widget _listMessageBuilder(BuildContext context, int index) {
    var alignment = CrossAxisAlignment.start;
    P2PMessageStatus msgStatus = P2PMessageStatus.failed;
    var text = Text('unknown',
                    style: TextStyle(fontSize: 16.0, color: Colors.white));
    switch (widget.session.messages[index]) {
      case EventMessageText(senderFingerprint: String senderFingerprint, messageText: String messageText, messageStatus: P2PMessageStatus messageStatus):
        msgStatus = messageStatus;
        if (senderFingerprint == widget.p2pService.serverFingerprint)
          alignment = CrossAxisAlignment.end; 
        text = Text(messageText,
                    style: TextStyle(fontSize: 16.0, color: Colors.white));
      default:; 
    }
    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(5.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 60.0),
            child: Container(
              padding: const EdgeInsets.all(7.0),
              child: text,
              decoration: BoxDecoration(
                color: Color(0xFFFFBF00),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        CrossAxisAlignment.end == alignment ? 
          Padding(
            padding: EdgeInsets.only(right: 5.0),
            child: Container(
              padding: const EdgeInsets.only(right: 7.0),
              child: Text((){
                switch (msgStatus){
                  case P2PMessageStatus.sent: return 'sent';
                  case P2PMessageStatus.sending: return 'sending';
                  case P2PMessageStatus.failed: return 'failed';
                  default: return 'unknown';
                }
              }(),  style: TextStyle(fontSize: 14.0, color: Colors.grey)),
  //            decoration: BoxDecoration(
  //              color: Color(0xFFFFBF00),
  //              borderRadius: BorderRadius.circular(10),
  //            ),
            ),
          ) : SizedBox(height: 0, width: 0)
        ,
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
                  maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              child: 
  Text(P2PQuotes[Random().nextInt(P2PQuotes.length)], style: TextStyle(fontStyle: FontStyle.italic)),
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
                    var tempMsg = messageText;
                    EventMessageText ev = EventMessageText(
                      timestamp: P2PUtils.UnixEpoch(),
                      senderFingerprint: widget.p2pService.serverFingerprint,
                      messageText: tempMsg,
                      messageStatus: P2PMessageStatus.sending,
                    );
                    setState((){
                      messageText = '';
                      widget.session.messages.insert(0, ev);
                    });
                    widget.p2pService.SendMessageText(widget.session.keyFingerprint, tempMsg).then((bool isFailed){
                        setState(() {ev.messageStatus = (isFailed ? P2PMessageStatus.failed : P2PMessageStatus.sent);});
                    });
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
