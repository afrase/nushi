import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'menu.dart';
import 'status.dart';
import 'terminal_panel.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The chats, grouped by folder (a chat in a worktree under its
/// repository): the folder with the newest chat first, and in each folder
/// the newest chat first. Archived chats are in a collapsed group at the
/// bottom.
class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.daemon});

  final Daemon daemon;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? _starting; // the folder a chat is starting in ('' for none)
  bool _showArchived = false;

  /// Starts a chat in [folder] ('' for a scratch folder).
  Future<void> _start(String folder) async {
    setState(() => _starting = folder);
    await tryOrShow(context, () => widget.daemon.startChat(folder));
    if (mounted) setState(() => _starting = null);
  }

  /// Opens a terminal in [folder] for the chat shown, if it's one of
  /// [chats], else for the newest of them, which it shows.
  Future<void> _terminal(String folder, List<ChatState> chats) async {
    final daemon = widget.daemon;
    final chat = chats.contains(daemon.selected)
        ? daemon.selected!
        : chats.first;
    daemon.select(chat.id);
    await tryOrShow(context, () => openTerminalIn(daemon, chat, folder));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final groups = <String, List<ChatState>>{};
    final byNewest = widget.daemon.chats.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final archived = [
      for (final c in byNewest)
        if (c.archived) c,
    ];
    for (final c in byNewest.where((c) => !c.archived)) {
      (groups[isScratch(c.folder) ? '' : c.home] ??= []).add(c);
    }
    if (_starting != null) groups.putIfAbsent(_starting!, () => []);
    return DecoratedBox(
      decoration: BoxDecoration(color: t.raised),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Button(
              label: 'New chat',
              icon: Icons.add,
              kind: ButtonKind.primary,
              height: 28,
              onPressed: _starting == null ? () => _start('') : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 10),
              children: [
                for (final MapEntry(key: folder, value: chats)
                    in groups.entries) ...[
                  _FolderHeader(
                    folder,
                    onNew: _starting == null ? () => _start(folder) : null,
                    onTerminal: folder.isEmpty || chats.isEmpty
                        ? null
                        : () => _terminal(folder, chats),
                  ),
                  if (_starting == folder)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                      child: Text(
                        'Starting…',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ),
                  for (final c in chats)
                    _ChatRow(c, key: ValueKey(c.id), daemon: widget.daemon),
                ],
                if (archived.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 2),
                    child: Tap(
                      onTap: () =>
                          setState(() => _showArchived = !_showArchived),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showArchived
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 16,
                            color: t.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Archived  ${archived.length}',
                            style: theme.ui(t.textSecondary, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showArchived)
                    for (final c in archived)
                      _ChatRow(c, key: ValueKey(c.id), daemon: widget.daemon),
                ],
              ],
            ),
          ),
          _McpButton(widget.daemon),
        ],
      ),
    );
  }
}

/// The footer's way into the MCP servers view, for the open chat's folder
/// (else the home folder).
class _McpButton extends StatelessWidget {
  const _McpButton(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final open = daemon.mcpFolder != null;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Tap(
        selected: open,
        onTap: () => daemon.showMcp(
          open
              ? null
              : daemon.selected?.folder ?? Platform.environment['HOME']!,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            Icon(Icons.hub_outlined, size: 14, color: t.textSecondary),
            const SizedBox(width: 8),
            Text('MCP servers', style: theme.ui(t.textSecondary, size: 12)),
          ],
        ),
      ),
    );
  }
}

/// A group's header: the folder's name and path, or "No folder" ('') for
/// chats in scratch folders.
class _FolderHeader extends StatelessWidget {
  const _FolderHeader(
    this.folder, {
    required this.onNew,
    required this.onTerminal,
  });

  final String folder;
  final VoidCallback? onNew;
  final VoidCallback? onTerminal; // a terminal there, in one of its chats

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final (name, parent) = folder.isEmpty
        ? ('No folder', '')
        : folderParts(folder);
    return Menu(
      entries: [
        MenuEntry('New chat here', onPick: onNew),
        MenuEntry('Open in terminal', onPick: onTerminal),
      ],
      builder: (context, open) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (d) => open(d.localPosition),
        child: _header(theme, t, name, parent),
      ),
    );
  }

  Widget _header(NushiTheme theme, Tokens t, String name, String parent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, weight: FontWeight.w600),
                ),
                if (parent.isNotEmpty)
                  Text(
                    parent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.code(t.textMuted, size: 11),
                  ),
              ],
            ),
          ),
          IconTap(Icons.add, tooltip: 'New chat here', onTap: onNew),
        ],
      ),
    );
  }
}

/// A chat in the list: click opens it, double-click renames it, and a
/// right-click opens its menu.
class _ChatRow extends StatefulWidget {
  const _ChatRow(this.chat, {super.key, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _renaming = false;
  DateTime _lastTap = DateTime(0);

  void _tap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) < kDoubleTapTimeout) {
      setState(() => _renaming = true);
    }
    _lastTap = now;
    widget.daemon.select(widget.chat.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final chat = widget.chat;
    final daemon = widget.daemon;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Menu(
          entries: chatMenu(
            context,
            chat,
            daemon,
            onRename: () => setState(() => _renaming = true),
          ),
          builder: (context, open) => Tap(
            onTap: _tap,
            onSecondaryTapUp: (d) => open(d.localPosition),
            selected: daemon.selectedId == chat.id,
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: _renaming ? 1 : 5,
            ),
            child: Row(
              children: [
                ChatDot(chat: chat),
                const SizedBox(width: 8),
                Expanded(
                  child: _renaming
                      ? RenameField(
                          chat: chat,
                          daemon: daemon,
                          onDone: () => setState(() => _renaming = false),
                        )
                      : Text(
                          chat.title.isEmpty ? 'New chat' : chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(
                            chat.archived ? t.textSecondary : t.text,
                          ),
                        ),
                ),
                if (chat.waiting)
                  Text('needs you', style: theme.ui(t.needs, size: 11.5))
                else if (chat.worktree case final wt?)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        wt.branch.replaceFirst('nushi/', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.code(t.textMuted, size: 10.5),
                      ),
                    ),
                  ),
                if (chat.archived && !isScratch(chat.folder))
                  Text(
                    folderParts(chat.home).$1,
                    style: theme.ui(t.textMuted, size: 11.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
