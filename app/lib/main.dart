import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'chat.dart';
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
                    : _ChatPane(key: ValueKey(chat.id), chat, daemon),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// A chat, with a switch between its transcript and its folder's changes.
class _ChatPane extends StatefulWidget {
  const _ChatPane(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  bool _changes = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: widget.daemon,
                builder: (context, _) => Text(
                  widget.chat.title.isEmpty ? 'New chat' : widget.chat.title,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Chat')),
                ButtonSegment(value: true, label: Text('Changes')),
              ],
              selected: {_changes},
              onSelectionChanged: (s) => setState(() => _changes = s.first),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: _changes
            ? ChangesView(chat: widget.chat, daemon: widget.daemon)
            : ChatView(chat: widget.chat, daemon: widget.daemon),
      ),
    ],
  );
}
