import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'chat.dart';
import 'chat_menu.dart';
import 'chat_view.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'sidebar.dart';
import 'theme/theme.dart';
import 'usage.dart';
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
            bundledDaemon == null
                ? 'Daemon not running'
                : 'Starting the daemon…',
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
                      'Start a chat',
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
          widget.daemon,
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

/// The chat's header: its title (double-click renames it), the agent, its
/// model and status, the folder, the Chat | Changes switch and the chat's
/// menu.
class _Header extends StatefulWidget {
  const _Header(
    this.chat,
    this.daemon, {
    required this.changes,
    required this.onChanges,
  });

  final ChatState chat;
  final Daemon daemon;
  final bool changes;
  final ValueChanged<bool> onChanges;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _renaming = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final meta = theme.ui(t.textSecondary, size: 12);
    final model = chat.config.where((o) => o.category == 'model').firstOrNull;
    final modelName = model?.values
        .where((v) => v.value == model.current)
        .firstOrNull
        ?.name;
    final titleStyle = theme.ui(t.text, size: 13, weight: FontWeight.w600);
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: _renaming
                ? RenameField(
                    chat: chat,
                    daemon: widget.daemon,
                    style: titleStyle,
                    onDone: () => setState(() => _renaming = false),
                  )
                : GestureDetector(
                    onDoubleTap: widget.daemon.canManageChats
                        ? () => setState(() => _renaming = true)
                        : null,
                    child: Text(
                      chat.title.isEmpty ? 'New chat' : chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          const AgentMonogram(),
          const SizedBox(width: 8),
          Text(
            'Claude',
            style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
          ),
          if (modelName != null) ...[
            const SizedBox(width: 10),
            Text(modelName, style: meta),
          ],
          const SizedBox(width: 10),
          if (chat.archived)
            Text('archived', style: meta)
          else ...[
            ChatDot(chat: chat),
            const SizedBox(width: 5),
            ChatStatusWord(chat, style: meta),
          ],
          const SizedBox(width: 10),
          CostLabel(chat.usage, style: meta),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FolderButton(chat: chat, daemon: widget.daemon),
            ),
          ),
          const SizedBox(width: 12),
          Segmented(
            value: widget.changes,
            segments: const [(false, 'Chat'), (true, 'Changes')],
            onChanged: widget.onChanges,
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Chat menu',
              iconSize: 16,
              color: t.textSecondary,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                final box = context.findRenderObject()! as RenderBox;
                showChatMenu(
                  context,
                  box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                  chat,
                  widget.daemon,
                  onRename: () => setState(() => _renaming = true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
