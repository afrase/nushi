import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/inline_edit.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The chats, grouped by folder (a chat in a worktree under its
/// repository): the folder with the newest chat first, and in each folder
/// the newest chat first. Archived chats are in a collapsed group at the
/// bottom.
class Sidebar extends StatefulWidget {
  const new({required this.daemon, super.key});

  final Daemon daemon;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _showArchived = false;

  void _new(String folder) => newChat(context, widget.daemon, folder);

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
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final groups = <String, List<ChatState>>{};
    final byNewest = widget.daemon.chats.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final archived = [
      for (final c in byNewest)
        if (c.archived) c,
    ];
    for (final c in byNewest.where((c) => !c.archived)) {
      (groups[c.scratch ? '' : c.home] ??= []).add(c);
    }
    final starting = widget.daemon.starting;
    if (starting != null) groups.putIfAbsent(starting, () => []);
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
              onPressed: starting == null ? () => _new('') : null,
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
                    onNew: starting == null ? () => _new(folder) : null,
                    onTerminal: folder.isEmpty || chats.isEmpty
                        ? null
                        : () => _terminal(folder, chats),
                  ),
                  if (starting == folder)
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
                          Chevron(open: _showArchived, size: 16),
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
          _Footer(widget.daemon),
        ],
      ),
    );
  }
}

/// The footer: the ways into the MCP servers view (for the open chat's
/// folder, else the home folder) and Jira.
class _Footer extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final mcp = daemon.mcpFolder != null;
    Widget row(
      String label,
      IconData icon,
      VoidCallback onTap, {
      required bool open,
    }) => Tap(
      selected: open,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: t.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: theme.ui(t.textSecondary, size: 12)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'MCP servers',
            Icons.hub_outlined,
            open: mcp,
            () => daemon.showMcp(
              mcp
                  ? null
                  : daemon.selected?.folder ?? Platform.environment['HOME']!,
            ),
          ),
          row(
            'Jira',
            Icons.task_alt,
            open: daemon.jiraOpen,
            () => daemon.showJira(open: !daemon.jiraOpen),
          ),
          row(
            'GitHub',
            Icons.merge_type,
            open: daemon.githubOpen,
            () => daemon.showGitHub(open: !daemon.githubOpen),
          ),
        ],
      ),
    );
  }
}

/// A group's header: the folder's name and path, or "No folder" ('') for
/// chats in scratch folders.
class _FolderHeader extends StatelessWidget {
  const new(this.folder, {required this.onNew, required this.onTerminal});

  final String folder;
  final VoidCallback? onNew;
  final VoidCallback? onTerminal; // a terminal there, in one of its chats

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
  const new(this.chat, {required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _renaming = false;
  final _double = DoubleClick();

  void _tap() {
    if (_double()) setState(() => _renaming = true);
    widget.daemon.select(widget.chat.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
                const SizedBox(width: 6),
                Tooltip(
                  message: chat.agentName,
                  child: AgentMark(
                    chat.agent,
                    color: chat.archived ? t.textMuted : t.textSecondary,
                  ),
                ),
                const SizedBox(width: 7),
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
                else if (chat.jiraKey.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      chat.jiraKey,
                      style: theme.code(t.textMuted, size: 10.5),
                    ),
                  )
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
                if (chat.archived && !chat.scratch)
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
