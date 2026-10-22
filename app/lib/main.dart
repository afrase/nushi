import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'chat.dart';
import 'chat_view.dart';
import 'daemon.dart';
import 'sidebar.dart';
import 'theme/theme.dart';
import 'widgets.dart';

void main() => runApp(NushiApp(daemon: Daemon()));

class NushiApp extends StatefulWidget {
  const NushiApp({super.key, required this.daemon});

  final Daemon daemon;

  @override
  State<NushiApp> createState() => _NushiAppState();
}

class _NushiAppState extends State<NushiApp> {
  var _mode = ThemeMode.system;

  PlatformMenuItem _appearance(String label, ThemeMode mode) =>
      PlatformMenuItem(
        label: label,
        onSelected: () => setState(() => _mode = mode),
      );

  @override
  Widget build(BuildContext context) => PlatformMenuBar(
    menus: [
      const PlatformMenu(
        label: 'Nushi Next',
        menus: [
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: [
          _appearance('Light Appearance', ThemeMode.light),
          _appearance('Dark Appearance', ThemeMode.dark),
          _appearance('System Appearance', ThemeMode.system),
        ],
      ),
    ],
    child: MaterialApp(
      title: 'Nushi Next',
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.light).toThemeData(),
      darkTheme: const NushiTheme(Tokens.dark).toThemeData(),
      themeMode: _mode,
      home: Scaffold(body: _Shell(widget.daemon)),
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: daemon,
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      if (!daemon.connected) {
        return Center(
          child: Text(
            'Daemon not running',
            style: theme.ui(theme.t.textSecondary),
          ),
        );
      }
      final chat = daemon.selected;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: Sidebar(daemon: daemon)),
          Expanded(
            child: chat == null
                ? Center(
                    child: Text(
                      'Start a chat in a folder',
                      style: theme.ui(theme.t.textMuted),
                    ),
                  )
                : _ChatPane(key: ValueKey(chat.id), chat, daemon),
          ),
        ],
      );
    },
  );
}

/// A chat under its header, with a switch between its transcript and its
/// folder's changes.
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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListenableBuilder(
        listenable: widget.chat,
        builder: (context, _) => _Header(
          widget.chat,
          changes: _changes,
          onChanges: (v) => setState(() => _changes = v),
        ),
      ),
      Expanded(
        child: _changes
            ? ChangesView(chat: widget.chat, daemon: widget.daemon)
            : ChatView(chat: widget.chat, daemon: widget.daemon),
      ),
    ],
  );
}

/// The chat's header: the agent, its model and status, the folder, and
/// the Chat | Changes switch.
class _Header extends StatelessWidget {
  const _Header(this.chat, {required this.changes, required this.onChanges});

  final ChatState chat;
  final bool changes;
  final ValueChanged<bool> onChanges;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final meta = theme.ui(t.textSecondary, size: 12);
    final model = chat.config.where((o) => o.category == 'model').firstOrNull;
    final modelName = model?.values
        .where((v) => v.value == model.current)
        .firstOrNull
        ?.name;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          const AgentMonogram(),
          const SizedBox(width: 10),
          Text(
            'Claude',
            style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
          ),
          if (modelName != null) ...[
            const SizedBox(width: 10),
            Text(modelName, style: meta),
          ],
          const SizedBox(width: 10),
          ChatDot(chat: chat),
          const SizedBox(width: 5),
          ChatStatusWord(chat, style: meta),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              chat.folder,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.code(t.textMuted, size: 11.5),
            ),
          ),
          const SizedBox(width: 12),
          Segmented(
            value: changes,
            segments: const [(false, 'Chat'), (true, 'Changes')],
            onChanged: onChanges,
          ),
        ],
      ),
    );
  }
}
