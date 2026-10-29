import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/inline_edit.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_groups.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The chats: the pinned ones first ([PinnedSection]), then grouped by
/// folder (a chat in a worktree under its repository; [SidebarGroups]):
/// the groups in the order they were dragged into, a new folder's first,
/// and in each the chats as they were dragged, a new one first. Archived
/// chats are in a collapsed group at the bottom. While ⌘ is held
/// alone, the first nine chats shown (archived left out) show the number
/// ⌘ opens them with.
class Sidebar extends StatefulWidget {
  const new({required this.daemon, super.key});

  final Daemon daemon;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _showArchived = false;
  final _hold = CommandHold();

  /// The chats' pull requests' checks, for their rows' dots, asked while
  /// the list shows.
  late final PullStates _pulls;

  @override
  void initState() {
    super.initState();
    _pulls = PullStates.of(widget.daemon)..watch();
  }

  @override
  void dispose() {
    _hold.dispose();
    _pulls.unwatch();
    super.dispose();
  }

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
    final daemon = widget.daemon;
    final archived = daemon.chats.values.where((c) => c.archived).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final starting = daemon.starting;
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
              hint: '⌘N',
              onPressed: starting == null ? () => _new('') : null,
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _hold,
                sidebarOrder,
                sidebarCollapsed,
                sidebarChats,
                pinnedCollapsed,
              ]),
              builder: (context, _) {
                final held = _hold.value;
                final numbers = {
                  for (final (i, c) in chatOrder(daemon).take(9).indexed)
                    c.id: i + 1,
                };
                Widget row(
                  ChatState c,
                  Movable movable, {
                  bool pinned = false,
                }) => _ChatRow(
                  c,
                  key: ValueKey(c.id),
                  daemon: daemon,
                  number: held ? numbers[c.id] : null,
                  movable: movable,
                  project: pinned,
                );
                return ListView(
                  padding: const EdgeInsets.only(bottom: 10),
                  children: [
                    PinnedSection(
                      daemon,
                      row: (c, movable) => row(c, movable, pinned: true),
                    ),
                    SidebarGroups(
                      groups: sidebarGroups(daemon, starting: starting),
                      selectedId: daemon.selectedId,
                      starting: starting,
                      onNew: starting == null ? _new : null,
                      onTerminal: _terminal,
                      row: row,
                    ),
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
                          _ChatRow(c, key: ValueKey(c.id), daemon: daemon),
                    ],
                  ],
                );
              },
            ),
          ),
          _Footer(daemon),
        ],
      ),
    );
  }
}

/// The footer: the views in the chat's place, Jira, GitHub and Settings
/// (each again closes it). MCP servers and Skills are Settings' sections,
/// reached there, from a chat's ⋯ and from the palette.
class _Footer extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            'Jira',
            Icons.task_alt,
            open: daemon.place is JiraPlace,
            () => daemon.toggle(const JiraPlace()),
          ),
          row(
            'GitHub',
            Icons.merge_type,
            open: daemon.place is GitHubPlace,
            () => daemon.toggle(const GitHubPlace()),
          ),
          row(
            'Settings',
            Icons.settings_outlined,
            open: daemon.place is SettingsPlace,
            () => daemon.place is SettingsPlace
                ? daemon.back()
                : daemon.openSettings(),
          ),
        ],
      ),
    );
  }
}

/// A chat in the list: click opens it, double-click renames it, a
/// right-click opens its menu, and dragged ([movable]) it moves within
/// its list. A pinned chat's ([project]) says its project after its title,
/// muted, in the place of its branch or Jira key.
class _ChatRow extends StatefulWidget {
  const new(
    this.chat, {
    required this.daemon,
    super.key,
    this.number,
    this.movable,
    this.project = false,
  });

  final ChatState chat;
  final Daemon daemon;
  final Movable? movable;
  final bool project;

  /// The number ⌘ opens it with, shown while ⌘ is held.
  final int? number;

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
    final movable =
        widget.movable ?? (Widget child, {required bool enabled}) => child;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => movable(
        enabled: !_renaming,
        Padding(
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
                  // Its state in a word on hover ("needs you"), which the
                  // row leaves to the dot so the title keeps its width.
                  Tooltip(
                    message: phaseWord(chat.phase, t).$1,
                    child: ChatDot(chat: chat, sparks: true),
                  ),
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
                            chat.shownTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.ui(
                              chat.archived ? t.textSecondary : t.text,
                            ),
                          ),
                  ),
                  if (widget.project)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        chat.scratch ? '' : folderParts(chat.home).$1,
                        style: theme.ui(t.textMuted, size: 11.5),
                      ),
                    )
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
                  if (chat.pull != null) PullDot(chat, PullStates.of(daemon)),
                  if (chat.archived && !chat.scratch)
                    Text(
                      folderParts(chat.home).$1,
                      style: theme.ui(t.textMuted, size: 11.5),
                    ),
                  if (widget.number case final n?)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: box(
                        t.fieldBorder,
                        fill: t.fieldFill,
                        radius: NushiTheme.control,
                      ),
                      child: Text(
                        '⌘$n',
                        style: theme.code(t.textSecondary, size: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
