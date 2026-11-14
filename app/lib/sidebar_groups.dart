import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/card_list.dart' show reordered;
import 'package:nushi/chat.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/project_sort.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_group_header.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The sidebar's project groups ([sidebarGroups]), each a header and its
/// chats. A header is the folder's name on one line, its path in its
/// tooltip; two projects of the same name show their parents after it. A
/// group moves by dragging its header, the others sliding apart where it
/// would go ([SlideList]; the order is kept in [sidebarOrder]); the
/// header's chevron collapses it (kept in [sidebarCollapsed]). A collapsed
/// group shows the most urgent of its chats' states as one dot beside its
/// name, and of its rows only the selected chat's ([shownChats]), the
/// others folding away. A group with no chats to show (a project kept,
/// [sidebarProjects]) is its header alone while its chats are pinned or
/// in a section; once none of its folder is left unarchived ([live]) it
/// says "No chats" under its header, unless collapsed, and its menu's
/// Remove from sidebar forgets it ([forgetProject]). A project's header
/// starts with its tile, small ([tile]; ADR 0112).
class SidebarGroups extends StatelessWidget {
  const new({
    required this.groups,
    required this.selectedId,
    required this.starting,
    required this.startingAgent,
    required this.live,
    required this.row,
    required this.onNew,
    required this.onTerminal,
    super.key,
    this.reorders,
    this.tile,
    this.onChangeTile,
  });

  final Map<String, List<ChatState>> groups;

  /// A project's tile for its header, and its menu's Change tile….
  final Widget Function(String folder)? tile;
  final void Function(String folder)? onChangeTile;
  final String? selectedId;

  /// The folder a chat is starting in, while one is, and its agent.
  final String? starting;
  final String? startingAgent;

  /// The folders with a chat that isn't archived ([liveFolders]), shown
  /// here or not (pinned, in a section): those the sidebar can't forget,
  /// and whose empty group doesn't say "No chats".
  final Set<String> live;
  final Widget Function(String folder, ChatState chat, Movable movable) row;

  /// A new chat in a folder ('' for none); null while one starts.
  final void Function(String folder)? onNew;

  /// A terminal in a folder, in one of its group's chats.
  final void Function(String folder, List<ChatState> chats) onTerminal;

  /// Whether a project's rows move by dragging (its sort is Manual); else
  /// they drag only into a section. All do without it.
  final bool Function(String folder)? reorders;

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.toList();
    final parents = twinParents(groups.keys);
    return SlideList<_Moving>(
      count: entries.length,
      accepts: (_) => true,
      onMove: (from, to) => sidebarOrder.value = reordered(
        sidebarOrder.value,
        groups.keys.toList(),
        from,
        to,
      ),
      item: (i, drag) {
        final MapEntry(key: folder, value: chats) = entries[i];
        final collapsed = sidebarCollapsed.value.contains(folder);
        return Column(
          key: ValueKey(folder),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              folder,
              twin: parents[folder] ?? '',
              chats: chats,
              collapsed: collapsed,
              onNew: switch (onNew) {
                final f? => () => f(folder),
                null => null,
              },
              onTerminal: folder.isEmpty || chats.isEmpty
                  ? null
                  : () => onTerminal(folder, chats),
              onRemove: live.contains(folder)
                  ? null
                  : () => forgetProject(folder),
              lead: folder.isEmpty ? null : tile?.call(folder),
              onChangeTile: switch (onChangeTile) {
                final f? when folder.isNotEmpty => () => f(folder),
                _ => null,
              },
              drag: drag,
            ),
            // Only when it's true (none pinned or in a section), and not
            // over the row of a chat starting there.
            Disclosure(
              open:
                  chats.isEmpty &&
                  !live.contains(folder) &&
                  !collapsed &&
                  starting != folder,
              child: const GroupHint('No chats'),
            ),
            MovableRows(
              standIn: starting == folder
                  ? StartingRow(
                      key: const ValueKey(#starting),
                      agent: startingAgent ?? '',
                    )
                  : null,
              group: folder,
              chats: chats,
              collapsed: collapsed,
              reorders: reorders?.call(folder) ?? true,
              selectedId: selectedId,
              row: (c, movable) => row(folder, c, movable),
              onMove: (from, to) => moveInProject(folder, chats, from, to),
            ),
          ],
        );
      },
    );
  }
}

/// What a header's drag carries: its group's folder.
class _Moving {
  const new(this.folder);

  final String folder;
}

/// Moves the chat at [from] of [shown] (the rows of [folder]'s group) to
/// [to], in [sidebarChats]; a chat it doesn't show (pinned, archived)
/// keeps its place there.
void moveInProject(String folder, List<ChatState> shown, int from, int to) {
  sidebarChats.value = {
    ...sidebarChats.value,
    folder: reordered(
      sidebarChats.value[folder] ?? const [],
      [for (final c in shown) c.id],
      from,
      to,
    ),
  };
}

/// For the folders of [folders] that share their name with another: what
/// tells them apart, their parent's name ("work" for ~/work/app), or its
/// path when that's shared too.
Map<String, String> twinParents(Iterable<String> folders) {
  final byName = <String, List<String>>{};
  for (final f in folders.where((f) => f.isNotEmpty)) {
    (byName[folderParts(f).$1] ??= []).add(f);
  }
  final out = <String, String>{};
  for (final twins in byName.values.where((l) => l.length > 1)) {
    final names = [for (final f in twins) folderParts(folderParts(f).$2).$1];
    final unique = names.toSet().length == names.length;
    for (final (i, f) in twins.indexed) {
      out[f] = unique && names[i].isNotEmpty ? names[i] : folderParts(f).$2;
    }
  }
  return out;
}

/// A project's menu, its group's header's and its tile's in the project
/// rail: New chat here, Open in terminal, and for a folder Remove from
/// sidebar, off ([onRemove] null) while a chat of it isn't archived, and
/// Change tile… ([onChangeTile]).
List<MenuEntry> projectEntries({
  required String folder,
  required VoidCallback? onNew,
  required VoidCallback? onTerminal,
  required VoidCallback? onRemove,
  VoidCallback? onChangeTile,
}) => [
  MenuEntry('New chat here', onPick: onNew),
  MenuEntry('Open in terminal', onPick: onTerminal),
  if (folder.isNotEmpty) ...[
    MenuEntry(
      'Remove from sidebar',
      tooltip: onRemove == null ? "It has chats that aren't archived" : '',
      onPick: onRemove,
    ),
    if (onChangeTile != null) ...[
      MenuEntry.divider,
      MenuEntry('Change tile…', onPick: onChangeTile),
    ],
  ],
];

/// A group's header: the folder's name (its path in the tooltip; [twin]
/// after it, muted, when another project has the same name), or "No
/// folder" ('') for chats in scratch folders; after it a chevron button
/// that collapses the group, shown as the + is or while it's collapsed,
/// with the summary dot beside it then ([GroupHeader]); its Sort button
/// ([ProjectSortButton]) and a + for a new chat there, shown under the
/// pointer or with keyboard focus (their room kept, so names don't move),
/// the Sort button always while the project sorts its own way. Dragged, it
/// moves the group. Its menu (a right-click) is the project's
/// ([projectEntries]). [lead], the project's tile, comes before its name.
class _Header extends StatefulWidget {
  const new(
    this.folder, {
    required this.twin,
    required this.chats,
    required this.collapsed,
    required this.onNew,
    required this.onTerminal,
    required this.onRemove,
    required this.drag,
    this.lead,
    this.onChangeTile,
  });

  final String folder;
  final String twin;
  final List<ChatState> chats;
  final bool collapsed;
  final VoidCallback? onNew;
  final VoidCallback? onTerminal; // a terminal there, in one of its chats
  final VoidCallback? onRemove; // forgets the project, once no chat is live
  final Widget? lead;
  final VoidCallback? onChangeTile;
  final ItemDrag<_Moving> drag;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _hover = false;
  bool _focus = false; // the + has keyboard focus

  void _toggle() => sidebarCollapsed.toggle(widget.folder);

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final folder = widget.folder;
    final name = folder.isEmpty ? 'No folder' : folderParts(folder).$1;
    return Menu(
      entries: projectEntries(
        folder: folder,
        onNew: widget.onNew,
        onTerminal: widget.onTerminal,
        onRemove: widget.onRemove,
        onChangeTile: widget.onChangeTile,
      ),
      builder: (context, open) => LayoutBuilder(
        builder: (context, box) => widget.drag.draggable(
          data: _Moving(folder),
          feedback: Lifted(name, width: box.maxWidth),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (d) => open(d.localPosition),
              child: GroupHeader(
                title: name,
                chats: widget.chats,
                collapsed: widget.collapsed,
                onToggle: _toggle,
                lead: widget.lead,
                titleWidget: folder.isEmpty
                    ? _name(theme, name)
                    : Tooltip(
                        message: tildePath(folder),
                        child: _name(theme, name),
                      ),
                trailing: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: (f) => setState(() => _focus = f),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProjectSortButton(folder, shown: _hover || _focus),
                      Opacity(
                        opacity: _hover || _focus ? 1 : 0,
                        child: IconTap(
                          Icons.add,
                          tooltip: 'New chat here',
                          size: 14,
                          onTap: widget.onNew,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _name(NushiTheme theme, String name) {
    final t = theme.t;
    return Text.rich(
      TextSpan(
        text: name,
        children: [
          if (widget.twin.isNotEmpty)
            TextSpan(
              text: '  · ${widget.twin}',
              style: theme.ui(t.textMuted, size: 11.5),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GroupHeader.style(theme),
    );
  }
}

/// Where a chat starting in a group will be, until its row takes the
/// place: a row's shape, the working ring, the agent's mark and
/// "Starting Claude…" shining.
class StartingRow extends StatelessWidget {
  const new({required this.agent, super.key});

  final String agent; // '' when not known

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // A chat row's room ([Tap]'s padding inside the row's own), so the
    // row comes in its place with no jump.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Sidebar.start,
        Sidebar.rowGap / 2,
        Sidebar.end,
        Sidebar.rowGap / 2,
      ),
      child: Container(
        height: Sidebar.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: Sidebar.rowPad),
        child: Row(
          children: [
            // A working chat's ring, still in a still frame ([loopRepaint]):
            // a start may wait on a trust card for as long as it's up.
            CustomPaint(
              size: const Size.square(ChatDot.size * 1.6),
              painter: StatusMark(
                t.running,
                ringing: !reduceMotion(context) && loopRepaint != null,
              ),
            ),
            const SizedBox(width: 8),
            if (agent.isEmpty) const SizedBox(width: 14) else AgentMark(agent),
            const SizedBox(width: 8),
            Expanded(
              child: Shine(
                child: Text(
                  agent.isEmpty
                      ? 'Starting…'
                      : 'Starting ${agentTitle(agent)}…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
