import 'dart:math';

import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'chat.dart';
import 'chat_menu.dart';
import 'chat_view.dart';
import 'daemon.dart';
import 'details_panel.dart';
import 'folder_button.dart';
import 'mcp.dart';
import 'menu.dart';
import 'panes.dart';
import 'settings.dart';
import 'sidebar.dart';
import 'status.dart';
import 'terminal_panel.dart';
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
        label: 'Nushi',
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
      title: 'Nushi',
      debugShowCheckedModeBanner: false,
      theme: const NushiTheme(Tokens.light).toThemeData(),
      darkTheme: const NushiTheme(Tokens.dark).toThemeData(),
      themeMode: _mode,
      scrollBehavior: const NativeScroll(),
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
      return LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Resizable(
              name: 'sidebar',
              initial: 260,
              min: 200,
              max: min(480, box.maxWidth - 560),
              child: Sidebar(daemon: daemon),
            ),
            Expanded(
              child: daemon.mcpFolder != null
                  ? McpView(daemon: daemon, folder: daemon.mcpFolder!)
                  : chat == null
                  ? Center(
                      child: Text(
                        'Start a chat',
                        style: theme.ui(theme.t.textMuted),
                      ),
                    )
                  : _ChatPane(key: ValueKey(chat.id), chat, daemon),
            ),
          ],
        ),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ValueListenableBuilder(
      valueListenable: showDetails,
      builder: (context, show, _) {
        // The panel goes when the chat would get too narrow.
        final fits =
            box.maxWidth >=
            paneWidth('details', DetailsPanel.width) + ChatView.minWidth;
        final panel = show && fits && !_changes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: widget.chat,
              builder: (context, _) => _Header(
                widget.chat,
                widget.daemon,
                changes: _changes,
                onChanges: (v) => setState(() => _changes = v),
                panel: panel,
                onPanel: fits && !_changes
                    ? () => showDetails.value = !show
                    : null,
              ),
            ),
            Expanded(
              child: TerminalArea(
                chat: widget.chat,
                daemon: widget.daemon,
                child: _changes
                    ? ChangesView(chat: widget.chat, daemon: widget.daemon)
                    : ChatView(
                        chat: widget.chat,
                        daemon: widget.daemon,
                        details: panel
                            ? DetailsPanel(
                                chat: widget.chat,
                                daemon: widget.daemon,
                                onChanges: () =>
                                    setState(() => _changes = true),
                              )
                            : null,
                      ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The chat's header: its title (double-click renames it), the agent, its
/// model and status, the folder while the details panel is hidden, the
/// Chat | Changes switch, the terminal's and the panel's buttons and the
/// chat's menu.
class _Header extends StatefulWidget {
  const _Header(
    this.chat,
    this.daemon, {
    required this.changes,
    required this.onChanges,
    required this.panel,
    required this.onPanel,
  });

  final ChatState chat;
  final Daemon daemon;
  final bool changes;
  final ValueChanged<bool> onChanges;
  final bool panel; // the details panel shows, with the folder in it
  final VoidCallback? onPanel; // shows or hides it; null when it can't show

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _renaming = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
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
          const _Monogram(),
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
          const SizedBox(width: 16),
          Expanded(
            // The folder, unless the panel has it or there's no room.
            child: LayoutBuilder(
              builder: (context, box) => widget.panel || box.maxWidth < 90
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: FolderButton(chat: chat, daemon: widget.daemon),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Segmented(
            value: widget.changes,
            segments: const [(false, 'Chat'), (true, 'Changes')],
            onChanged: widget.onChanges,
          ),
          const SizedBox(width: 4),
          TerminalButton(chat: chat, daemon: widget.daemon),
          IconTap(
            Icons.view_sidebar_outlined,
            tooltip: widget.onPanel == null
                ? 'The window is too narrow for the details panel'
                : widget.panel
                ? 'Hide details'
                : 'Show details',
            color: widget.panel ? t.text : t.textSecondary,
            onTap: widget.onPanel,
          ),
          Menu(
            tooltip: 'Chat menu',
            entries: chatMenu(
              context,
              chat,
              widget.daemon,
              onRename: () => setState(() => _renaming = true),
            ),
            child: Icon(Icons.more_horiz, size: 16, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The agent's monogram: its letter on its color.
class _Monogram extends StatelessWidget {
  const _Monogram();

  static const size = 16.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.claude,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: Text(
        'C',
        style: TextStyle(
          fontFamily: NushiTheme.uiFont,
          fontSize: size * 0.64,
          height: 1,
          fontWeight: FontWeight.w600,
          color: t.monogramText,
        ),
      ),
    );
  }
}
