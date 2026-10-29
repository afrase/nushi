import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_cards.dart' show reordered;
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The sidebar's project groups ([sidebarGroups]), each a header and its
/// chats. A header is the folder's name on one line, its path in its
/// tooltip; two projects of the same name show their parents after it. A
/// group moves by dragging its header, a line showing where it will go
/// (the order is kept in [sidebarOrder]); the header's chevron
/// collapses it (kept in [sidebarCollapsed]). A collapsed group shows the
/// most urgent of its chats' states as one dot beside its name, and of
/// its rows only the selected chat's.
class SidebarGroups extends StatefulWidget {
  const new({
    required this.groups,
    required this.selectedId,
    required this.starting,
    required this.row,
    required this.onNew,
    required this.onTerminal,
    super.key,
  });

  final Map<String, List<ChatState>> groups;
  final String? selectedId;

  /// The folder a chat is starting in, while one is.
  final String? starting;
  final Widget Function(ChatState chat, Movable movable) row;

  /// A new chat in a folder ('' for none); null while one starts.
  final void Function(String folder)? onNew;

  /// A terminal in a folder, in one of its group's chats.
  final void Function(String folder, List<ChatState> chats) onTerminal;

  @override
  State<SidebarGroups> createState() => _SidebarGroupsState();
}

/// What a header's drag carries: its group's folder.
class _Moving {
  const new(this.folder);

  final String folder;
}

class _SidebarGroupsState extends State<SidebarGroups> {
  String? _moving; // the folder whose group is being dragged
  int? _dropAt; // where it would go: before the group at this index
  final _scroll = EdgeScroll();

  /// Where the dragged group is now, if it's being dragged.
  int get _from =>
      _moving == null ? -1 : widget.groups.keys.toList().indexOf(_moving!);

  /// Whether a drop at [_dropAt] would move the group (not just put it
  /// back where it is).
  bool get _moves {
    final at = _dropAt;
    final from = _from;
    return from >= 0 && at != null && at != from && at != from + 1;
  }

  void _over(int at) {
    if (at != _dropAt) setState(() => _dropAt = at);
  }

  void _drop() {
    if (_moves) {
      final from = _from;
      final at = _dropAt!;
      sidebarOrder.value = reordered(
        sidebarOrder.value,
        widget.groups.keys.toList(),
        from,
        at > from ? at - 1 : at,
      );
    }
    _end();
  }

  void _end() {
    _scroll.stop();
    if (mounted) {
      setState(() {
        _moving = null;
        _dropAt = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = widget.groups.length;
    final line = _moves ? _dropAt : null;
    final parents = twinParents(widget.groups.keys);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, MapEntry(key: folder, value: chats))
            in widget.groups.entries.indexed)
          _Target(
            key: ValueKey(folder),
            onOver: ({required after}) => _over(i + (after ? 1 : 0)),
            onLeave: () => setState(() => _dropAt = null),
            onDrop: _drop,
            line: line == i
                ? VerticalDirection.down
                : line == n && i == n - 1
                ? VerticalDirection.up
                : null,
            child: Opacity(
              opacity: _moving == folder ? 0.4 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    folder,
                    twin: parents[folder] ?? '',
                    chats: chats,
                    collapsed: sidebarCollapsed.value.contains(folder),
                    onNew: switch (widget.onNew) {
                      final f? => () => f(folder),
                      null => null,
                    },
                    onTerminal: folder.isEmpty || chats.isEmpty
                        ? null
                        : () => widget.onTerminal(folder, chats),
                    onDragStarted: () => setState(() => _moving = folder),
                    onDragUpdate: (d) => _scroll.update(context, d),
                    onDragEnd: _end,
                  ),
                  if (widget.starting == folder)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                      child: Text(
                        'Starting…',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ),
                  MovableRows(
                    group: folder,
                    chats: [...shownChats(folder, chats, widget.selectedId)],
                    row: widget.row,
                    onMove: (from, to) => moveInProject(
                      folder,
                      [...shownChats(folder, chats, widget.selectedId)],
                      from,
                      to,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A group as a place to drop a dragged header: its upper half puts the
/// group before it, its lower half after. [line] draws the drop line at
/// its top (down) or bottom (up).
class _Target extends StatelessWidget {
  const new({
    required this.onOver,
    required this.onLeave,
    required this.onDrop,
    required this.line,
    required this.child,
    super.key,
  });

  final void Function({required bool after}) onOver;
  final VoidCallback onLeave;
  final VoidCallback onDrop;
  final VerticalDirection? line;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_Moving>(
      onMove: (d) {
        final box = context.findRenderObject()! as RenderBox;
        onOver(after: box.globalToLocal(d.offset).dy > box.size.height / 2);
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (_) => onDrop(),
      builder: (context, _, _) => DropLine(line: line, child: child),
    );
  }
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

/// A group's header: the folder's name (its path in the tooltip; [twin]
/// after it, muted, when another project has the same name), or "No
/// folder" ('') for chats in scratch folders; a chevron button that
/// collapses the group, with the summary dot beside the name while it's
/// collapsed; a + for a new chat there, shown under the pointer or with
/// keyboard focus (its room kept, so names don't move). Dragged, it moves
/// the group.
class _Header extends StatefulWidget {
  const new(
    this.folder, {
    required this.twin,
    required this.chats,
    required this.collapsed,
    required this.onNew,
    required this.onTerminal,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final String folder;
  final String twin;
  final List<ChatState> chats;
  final bool collapsed;
  final VoidCallback? onNew;
  final VoidCallback? onTerminal; // a terminal there, in one of its chats
  final VoidCallback onDragStarted;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _hover = false;
  bool _focus = false; // the + has keyboard focus

  void _toggle() => sidebarCollapsed.value = widget.collapsed
      ? ({...sidebarCollapsed.value}..remove(widget.folder))
      : {...sidebarCollapsed.value, widget.folder};

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final folder = widget.folder;
    final name = folder.isEmpty ? 'No folder' : folderParts(folder).$1;
    return Menu(
      entries: [
        MenuEntry('New chat here', onPick: widget.onNew),
        MenuEntry('Open in terminal', onPick: widget.onTerminal),
      ],
      builder: (context, open) => LayoutBuilder(
        builder: (context, box) => Draggable<_Moving>(
          data: _Moving(folder),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Lifted(name, width: box.maxWidth),
          onDragStarted: widget.onDragStarted,
          onDragUpdate: widget.onDragUpdate,
          onDragEnd: (_) => widget.onDragEnd(),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (d) => open(d.localPosition),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 6, 2),
                child: Row(
                  children: [
                    IconTap(
                      widget.collapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      tooltip: widget.collapsed ? 'Expand' : 'Collapse',
                      size: 12,
                      padding: 6,
                      color: t.textMuted,
                      onTap: _toggle,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: folder.isEmpty
                          ? _name(theme, name)
                          : Tooltip(
                              message: tildePath(folder),
                              child: _name(theme, name),
                            ),
                    ),
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onFocusChange: (f) => setState(() => _focus = f),
                      child: Opacity(
                        opacity: _hover || _focus ? 1 : 0,
                        child: IconTap(
                          Icons.add,
                          tooltip: 'New chat here',
                          onTap: widget.onNew,
                        ),
                      ),
                    ),
                  ],
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
    final chats = widget.chats;
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              text: name,
              children: [
                if (widget.twin.isNotEmpty)
                  TextSpan(
                    text: '  · ${widget.twin}',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text, weight: FontWeight.w600),
          ),
        ),
        if (widget.collapsed)
          ListenableBuilder(
            listenable: Listenable.merge(chats),
            builder: (context, _) => switch (groupPhase(chats)) {
              final phase? => Padding(
                padding: const EdgeInsets.only(left: 5),
                child: PhaseDot(phase),
              ),
              null => const SizedBox.shrink(),
            },
          ),
      ],
    );
  }
}
