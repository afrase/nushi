import 'package:flutter/material.dart';

import 'daemon.dart';

void main() => runApp(NushiApp(daemon: Daemon()));

class NushiApp extends StatelessWidget {
  const NushiApp({super.key, required this.daemon});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nushi Next',
    theme: ThemeData(colorSchemeSeed: Colors.blueGrey),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.blueGrey,
      brightness: Brightness.dark,
    ),
    home: Scaffold(
      body: Center(
        child: ListenableBuilder(
          listenable: daemon,
          builder: (context, _) =>
              Text(daemon.connected ? 'Connected' : 'Daemon not running'),
        ),
      ),
    ),
  );
}
