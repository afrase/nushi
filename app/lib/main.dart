import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'chat_view.dart';
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
      body: ListenableBuilder(
        listenable: daemon,
        builder: (context, _) {
          final chat = daemon.chat;
          if (!daemon.connected) {
            return const Center(child: Text('Daemon not running'));
          }
          if (chat == null) return _StartChat(daemon: daemon);
          return ChatView(chat: chat, daemon: daemon);
        },
      ),
    ),
  );
}

class _StartChat extends StatefulWidget {
  const _StartChat({required this.daemon});

  final Daemon daemon;

  @override
  State<_StartChat> createState() => _StartChatState();
}

class _StartChatState extends State<_StartChat> {
  bool _starting = false;
  String _error = '';

  Future<void> _start() async {
    final folder = await getDirectoryPath(confirmButtonText: 'Start chat');
    if (folder == null) return;
    setState(() => _starting = true);
    try {
      await widget.daemon.startChat(folder);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Connected'),
        const SizedBox(height: 16),
        _starting
            ? const CircularProgressIndicator()
            : FilledButton(
                onPressed: _start,
                child: const Text('Start a chat in a folder…'),
              ),
        if (_error.isNotEmpty) ...[const SizedBox(height: 16), Text(_error)],
      ],
    ),
  );
}
