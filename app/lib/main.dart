import 'package:flutter/material.dart';

import 'chat_view.dart';
import 'daemon.dart';
import 'sidebar.dart';

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
      body: ListenableBuilder(
        listenable: daemon,
        builder: (context, _) {
          if (!daemon.connected) {
            return const Center(child: Text('Daemon not running'));
          }
          final chat = daemon.selected;
          return Row(
            children: [
              SizedBox(width: 260, child: Sidebar(daemon: daemon)),
              const VerticalDivider(width: 1),
              Expanded(
                child: chat == null
                    ? const Center(child: Text('Start a chat in a folder'))
                    : ChatView(
                        key: ValueKey(chat.id),
                        chat: chat,
                        daemon: daemon,
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
