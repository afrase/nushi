import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The sidebar's chat rows that move by dragging (a project's, Pinned's),
// the Pinned section's header, and what dragging in the sidebar shares
// with the projects' headers (`sidebar_groups.dart`).

/// Makes a chat's row movable: [child] dragged, unless [enabled] is off
/// (its title being renamed in place).
typedef Movable = Widget Function(Widget child, {required bool enabled});

/// What a chat row's drag carries: its list ([MovableRows.group]) and the
/// chat.
class _MovingChat {
  const new(this.group, this.id);

  final Object group;
  final String id;
}

/// Chats' rows that move by dragging, within this list only (a chat's
/// folder decides its project, so a row of another list is refused): a
/// line shows where the dragged one lands, and [onMove] says it moved
/// from one place to another. [row] builds each row, making it movable
/// with what it's given.
class MovableRows extends StatefulWidget {
  const new({
    required this.group,
    required this.chats,
    required this.row,
    required this.onMove,
    super.key,
  });

  /// Which list it is: a project's folder, or [pinnedGroup].
  final Object group;
  final List<ChatState> chats;
  final Widget Function(ChatState chat, Movable movable) row;
  final void Function(int from, int to) onMove;

  @override
  State<MovableRows> createState() => _MovableRowsState();
}

/// [MovableRows.group] for the Pinned section.
const pinnedGroup = #pinned;

class _MovableRowsState extends State<MovableRows> {
  String? _moving; // the chat being dragged
  int? _dropAt; // where it would go: before the row at this index
  final _scroll = EdgeScroll();

  int get _from =>
      _moving == null ? -1 : widget.chats.indexWhere((c) => c.id == _moving);

  bool get _moves {
    final at = _dropAt;
    final from = _from;
    return from >= 0 && at != null && at != from && at != from + 1;
  }

  bool _ours(_MovingChat m) => m.group == widget.group;

  void _over(int at) {
    if (at != _dropAt) setState(() => _dropAt = at);
  }

  void _drop() {
    if (_moves) {
      final from = _from;
      final at = _dropAt!;
      widget.onMove(from, at > from ? at - 1 : at);
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
    final n = widget.chats.length;
    final line = _moves ? _dropAt : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in widget.chats.indexed)
          _RowTarget(
            key: ValueKey(c.id),
            accepts: _ours,
            onOver: ({required after}) => _over(i + (after ? 1 : 0)),
            onLeave: () => setState(() => _dropAt = null),
            onDrop: _drop,
            line: line == i
                ? VerticalDirection.down
                : line == n && i == n - 1
                ? VerticalDirection.up
                : null,
            child: Opacity(
              opacity: _moving == c.id ? 0.4 : 1,
              child: widget.row(
                c,
                (child, {required enabled}) => LayoutBuilder(
                  builder: (context, box) => Draggable<_MovingChat>(
                    data: _MovingChat(widget.group, c.id),
                    maxSimultaneousDrags: enabled ? null : 0,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Lifted(
                      c.shownTitle,
                      width: box.maxWidth,
                      weight: FontWeight.w400,
                    ),
                    onDragStarted: () => setState(() => _moving = c.id),
                    onDragUpdate: (d) => _scroll.update(this.context, d),
                    onDragEnd: (_) => _end(),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A row as a place to drop a dragged row of its list ([accepts]): its
/// upper half puts the row before it, its lower half after. [line] draws
/// the drop line at its top (down) or bottom (up).
class _RowTarget extends StatelessWidget {
  const new({
    required this.accepts,
    required this.onOver,
    required this.onLeave,
    required this.onDrop,
    required this.line,
    required this.child,
    super.key,
  });

  final bool Function(_MovingChat) accepts;
  final void Function({required bool after}) onOver;
  final VoidCallback onLeave;
  final VoidCallback onDrop;
  final VerticalDirection? line;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<_MovingChat>(
    onWillAcceptWithDetails: (d) => accepts(d.data),
    onMove: (d) {
      if (!accepts(d.data)) return; // another list's row: no line here
      final box = context.findRenderObject()! as RenderBox;
      onOver(after: box.globalToLocal(d.offset).dy > box.size.height / 2);
    },
    onLeave: (d) {
      if (d != null && accepts(d)) onLeave();
    },
    onAcceptWithDetails: (_) => onDrop(),
    builder: (context, _, _) => DropLine(line: line, child: child),
  );
}

/// [child] with the drop line at its top (down) or bottom (up), where a
/// dragged header or row would land.
class DropLine extends StatelessWidget {
  const new({required this.line, required this.child, super.key});

  final VerticalDirection? line;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Stack(
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
    );
  }
}

/// Scrolls the list a drag is in while the pointer is near its top or
/// bottom edge.
class EdgeScroll {
  EdgeDraggingAutoScroller? _scroller;

  void update(BuildContext context, DragUpdateDetails d) {
    if (_scroller == null) {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      _scroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 50);
    }
    _scroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: d.globalPosition, width: 1, height: 40),
    );
  }

  void stop() {
    _scroller?.stopAutoScroll();
    _scroller = null;
  }
}

/// What's dragged, under the pointer: a header's name or a chat's title,
/// just past the pointer and see-through, so the drop line shows.
class Lifted extends StatelessWidget {
  const new(
    this.name, {
    required this.width,
    super.key,
    this.weight = FontWeight.w600,
  });

  final String name;
  final double width; // the header's or row's
  final FontWeight weight;

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
              style: theme.ui(t.text, weight: weight),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Pinned section, above the projects while a chat is pinned: its
/// header, and its chats' rows ([row]), which move by dragging; with the
/// section collapsed, only the selected chat's row, if it's pinned.
class PinnedSection extends StatelessWidget {
  const new(this.daemon, {required this.row, super.key});

  final Daemon daemon;
  final Widget Function(ChatState chat, Movable movable) row;

  @override
  Widget build(BuildContext context) {
    final pinned = pinnedChats(daemon);
    if (pinned.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PinnedHeader(chats: pinned),
        MovableRows(
          group: pinnedGroup,
          chats: [...shownPinned(daemon)],
          row: row,
          // Two rows or more show only while it's open: all of them.
          onMove: (from, to) => unawaited(
            tryOrShow(
              context,
              () => setChatPins(daemon, [
                for (final c in reorderedChats(pinned, from, to)) c.id,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Pinned section's header, as a project's: "Pinned", and a chevron
/// that collapses the section (kept in [pinnedCollapsed]), the most
/// urgent of its chats' states as one dot while it's collapsed.
class PinnedHeader extends StatelessWidget {
  const new({required this.chats, super.key});

  final List<ChatState> chats;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final collapsed = pinnedCollapsed.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 6, 2),
      child: Row(
        children: [
          IconTap(
            collapsed ? Icons.chevron_right : Icons.expand_more,
            tooltip: collapsed ? 'Expand' : 'Collapse',
            size: 12,
            padding: 6,
            color: t.textMuted,
            onTap: () => pinnedCollapsed.value = !collapsed,
          ),
          const SizedBox(width: 2),
          // As tall as a project's + button, so both headers match.
          SizedBox(
            height: 26,
            child: Center(
              child: Text(
                'Pinned',
                style: theme.ui(t.text, weight: FontWeight.w600),
              ),
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
    );
  }
}
