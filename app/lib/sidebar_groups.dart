import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_cards.dart' show reordered;
import 'package:nushi/settings.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The sidebar's project groups ([sidebarGroups]), each a header and its
/// chats. A group moves by dragging its header, a line showing where it
/// will go (the order is kept in [sidebarOrder]); the header's chevron
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
  final Widget Function(ChatState chat) row;

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
  EdgeDraggingAutoScroller? _scroller;

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
    _scroller?.stopAutoScroll();
    _scroller = null;
    if (mounted) {
      setState(() {
        _moving = null;
        _dropAt = null;
      });
    }
  }

  /// Scrolls the list while the pointer is near its top or bottom edge.
  void _dragged(DragUpdateDetails d) {
    if (_scroller == null) {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      _scroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 50);
    }
    _scroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: d.globalPosition, width: 1, height: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = widget.groups.length;
    final line = _moves ? _dropAt : null;
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
                    onDragUpdate: _dragged,
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
                  for (final c in shownChats(folder, chats, widget.selectedId))
                    widget.row(c),
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
    final t = NushiTheme.of(context).t;
    return DragTarget<_Moving>(
      onMove: (d) {
        final box = context.findRenderObject()! as RenderBox;
        onOver(after: box.globalToLocal(d.offset).dy > box.size.height / 2);
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (_) => onDrop(),
      builder: (context, _, _) => Stack(
        children: [
          child,
          if (line case final at?)
            Positioned(
              key: const Key('drop line'),
              left: 8,
              right: 8,
              top: at == .down ? 0 : null,
              bottom: at == .up ? 0 : null,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A group's header: the folder's name and path, or "No folder" ('') for
/// chats in scratch folders; a chevron button that collapses the group,
/// with the summary dot beside the name while it's collapsed. Dragged, it
/// moves the group.
class _Header extends StatelessWidget {
  const new(
    this.folder, {
    required this.chats,
    required this.collapsed,
    required this.onNew,
    required this.onTerminal,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final String folder;
  final List<ChatState> chats;
  final bool collapsed;
  final VoidCallback? onNew;
  final VoidCallback? onTerminal; // a terminal there, in one of its chats
  final VoidCallback onDragStarted;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;

  void _toggle() => sidebarCollapsed.value = collapsed
      ? ({...sidebarCollapsed.value}..remove(folder))
      : {...sidebarCollapsed.value, folder};

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
      builder: (context, open) => LayoutBuilder(
        builder: (context, box) => Draggable<_Moving>(
          data: _Moving(folder),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _Lifted(name, width: box.maxWidth),
          onDragStarted: onDragStarted,
          onDragUpdate: onDragUpdate,
          onDragEnd: (_) => onDragEnd(),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (d) => open(d.localPosition),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 6, 2),
                child: Row(
                  children: [
                    IconTap(
                      collapsed ? Icons.chevron_right : Icons.expand_more,
                      tooltip: collapsed ? 'Expand' : 'Collapse',
                      size: 14,
                      color: t.textMuted,
                      onTap: _toggle,
                    ),
                    const SizedBox(width: 2),
                    Expanded(child: _name(theme, name, parent)),
                    IconTap(Icons.add, tooltip: 'New chat here', onTap: onNew),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _name(NushiTheme theme, String name, String parent) {
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text, weight: FontWeight.w600),
              ),
            ),
            if (collapsed)
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
        ),
        if (parent.isNotEmpty)
          Text(
            parent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.textMuted, size: 11),
          ),
      ],
    );
  }
}

/// The header under the pointer while it's dragged: the folder's name,
/// just past the pointer and see-through, so the drop line shows.
class _Lifted extends StatelessWidget {
  const new(this.name, {required this.width});

  final String name;
  final double width; // the header's

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Transform.translate(
      offset: const Offset(12, 4),
      child: Opacity(
        opacity: 0.85,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            constraints: BoxConstraints(maxWidth: width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: box(
              t.borderSubtle,
              fill: t.raised,
              radius: NushiTheme.control,
            ).copyWith(boxShadow: [BoxShadow(color: t.shadow, blurRadius: 12)]),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text, weight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
