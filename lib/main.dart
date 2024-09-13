import 'package:flutter/material.dart';
import 'session.dart';
import 'setup.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SessionsPage(title: 'Sessions'),
    );
  }
}

void main() {
  runApp(const MyApp());
}
