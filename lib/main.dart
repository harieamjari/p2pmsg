/* main.dart - p2pmsg entry point
 *
 * Built with hopes, dreams and lots and lots of
 * demo code.
 */

import 'package:flutter/material.dart';
import 'setup.dart';


class P2PApp extends StatelessWidget {
  const P2PApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P over PGP messaging app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF2274A5)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFE83F6F),
        ),
        useMaterial3: true,
      ),
      home: SetupPage(),
    );
  }
}



Future<void> main() async {
  runApp(P2PApp());
}
