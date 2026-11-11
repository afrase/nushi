import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The sidebar's chat rows that move by dragging (a project's, Pinned's),
// the Pinned section's header, the dragged look the projects' headers
// share (`sidebar_groups.dart`), and an empty group's line.

/// Makes a chat's row movable: [child] dragged, unless [enabled] is off
/// (its title being renamed in place).
typedef Movable = Widget Function(Widget child, {required bool enabled});

/// What a chat row's drag carries: its list ([MovableRows.group]) and the
/// chat. A section takes one from another list (`sidebar_sections.dart`).
class MovingChat {
  const new(this.group, this.id);

  final Object group;
  final String id;
}

/// Chats' rows that move by dragging, within this list only (a chat's
/// folder decides its project, so a row of another list is refused): the
/// others slide apart where the dragged one would land ([SlideList]), and
/// [onMove] says it moved from one place to another. [row] builds each
/// row, making it movable with what it's given. [collapsed], the rows
/// other than [selectedId]'s fold away together ([Disclosure]), and none
/// moves. Without [reorders] (the sort sets the order) a row still drags,
/// into a section, but its own list takes no drop.
class MovableRows extends StatelessWidget {
  const new({
    required this.group,
    required this.chats,
    required this.row,
    required this.onMove,
    super.key,
    this.collapsed = false,
    this.reorders = true,
    this.selectedId,
    this.standIn,
  });

  /// Which list it is: a project's folder, or [pinnedGroup].
  final Object group;
  final List<ChatState> chats;
  final Widget Function(ChatState chat, Movable movable) row;
  final void Function(int from, int to) onMove;
  final bool collapsed;
  final bool reorders;
  final String? selectedId;

  /// A row-shaped placeholder at the top for a chat starting here, which
  /// its row takes the place of ([SlideList.standIn]).
  final Widget? standIn;

  @override
  Widget build(BuildContext context) => SlideList<MovingChat>(
    count: chats.length,
    standIn: standIn,
    accepts: (m) => reorders && m.group == group && !collapsed,
    onMove: onMove,
    item: (i, drag) {
      final c = chats[i];
      return KeyedSubtree(
        key: ValueKey(c.id),
        child: Disclosure(
          open: !collapsed || c.id == selectedId,
          child: row(
            c,
            (child, {required enabled}) => LayoutBuilder(
              builder: (context, box) => drag.draggable(
                data: MovingChat(group, c.id),
                enabled: enabled && !collapsed,
                feedback: Lifted(
                  c.shownTitle,
                  width: box.maxWidth,
                  weight: FontWeight.w400,
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The archived chats' rows ([row]), newest first, under a header that
/// opens and folds them ([open], [onToggle]), at the sidebar's bottom
/// while a chat is archived. They don't move by dragging.
class ArchivedSection extends StatelessWidget {
  const new(
    this.archived, {
    required this.open,
    required this.onToggle,
    required this.row,
    super.key,
  });

  final List<ChatState> archived;
  final bool open;
  final VoidCallback onToggle;
  final Widget Function(ChatState chat) row;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Disclosure(
          open: archived.isNotEmpty,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Sidebar.start,
              12,
              Sidebar.end,
              2,
            ),
            child: Tap(
              onTap: onToggle,
              padding: const EdgeInsets.symmetric(
                horizontal: Sidebar.rowPad,
                vertical: 5,
              ),
              child: Row(
                children: [
                  Text(
                    'Archived  ${archived.length}',
                    style: theme.ui(
                      t.textMuted,
                      size: 11.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TurnChevron(open: open, size: 12, color: t.textMuted),
                ],
              ),
            ),
          ),
        ),
        Disclosure(
          open: open && archived.isNotEmpty,
          child: SlideList<MovingChat>(
            count: archived.length,
            accepts: (_) => false,
            onMove: (_, _) {},
            item: (i, _) => KeyedSubtree(
              key: ValueKey(archived[i].id),
              child: row(archived[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// What a group with no rows says under its header, muted, at its name's
/// place: a section's "Drag chats here", a project's "No chats".
class GroupHint extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Sidebar.start + Sidebar.rowPad,
        2,
        Sidebar.end,
        6,
      ),
      child: Text(text, style: theme.ui(theme.t.textMuted, size: 12)),
    );
  }
}

/// [MovableRows.group] for the Pinned section.
const pinnedGroup = #pinned;

/// What's dragged, under the pointer: a header's name or a chat's title,
/// just past the pointer and see-through, so the gap below shows.
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
            decoration: BoxDecoration(
              color: t.raised,
              borderRadius: BorderRadius.circular(NushiTheme.control),
              boxShadow: [BoxShadow(color: t.shadow, blurRadius: 12)],
            ),
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
/// section collapsed, only the selected chat's row, if it's pinned
/// ([shownPinned]), the others folded away.
class PinnedSection extends StatelessWidget {
  const new(this.daemon, {required this.row, super.key});

  final Daemon daemon;
  final Widget Function(ChatState chat, Movable movable) row;

  @override
  Widget build(BuildContext context) {
    final pinned = pinnedChats(daemon);
    // Its header grows in with the first pin, its rows gliding there.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Disclosure(
          open: pinned.isNotEmpty,
          child: PinnedHeader(chats: pinned),
        ),
        MovableRows(
          group: pinnedGroup,
          chats: pinned,
          collapsed: pinnedCollapsed.value,
          selectedId: daemon.selectedId,
          row: row,
          // Rows move only while it's open, when all of them show.
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
  Widget build(BuildContext context) => GroupHeader(
    title: 'Pinned',
    chats: chats,
    collapsed: pinnedCollapsed.value,
    onToggle: () => pinnedCollapsed.value = !pinnedCollapsed.value,
  );
}

/// A group's header (a project's, Pinned's, a section's, a Date or Status
/// group's): a small muted label over its rows (ADR 0111), [lead] (an
/// agent's mark) before [title]; after it the chevron that collapses the
/// group ([onToggle]), quiet: it shows under the pointer, with the
/// keyboard's focus, and always while the group is [collapsed], when the
/// most urgent of its chats' states is one dot beside it; and [trailing]
/// at its end. As tall as a project's header with its + button, so all
/// match.
class GroupHeader extends StatefulWidget {
  const new({
    required this.title,
    required this.chats,
    required this.collapsed,
    required this.onToggle,
    super.key,
    this.lead,
    this.trailing,
    this.titleWidget,
  });

  final String title;
  final List<ChatState> chats;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget? lead;
  final Widget? trailing;

  /// In [title]'s place (a field to rename a section).
  final Widget? titleWidget;

  /// A group's name, as its header writes it.
  static TextStyle style(NushiTheme theme) =>
      theme.ui(theme.t.textMuted, size: 11.5, weight: FontWeight.w600);

  @override
  State<GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<GroupHeader> {
  bool _hover = false;
  bool _focus = false; // the chevron has the keyboard's focus

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final collapsed = widget.collapsed;
    return MouseRegion(
      opaque: false,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        // Its name starts where its rows' marks do.
        padding: const EdgeInsets.fromLTRB(
          Sidebar.start + Sidebar.rowPad,
          10,
          Sidebar.end + 2,
          0,
        ),
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              if (widget.lead case final lead?) ...[
                lead,
                const SizedBox(width: 6),
              ],
              // The name takes what the row leaves; the chevron follows it.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child:
                          widget.titleWidget ??
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GroupHeader.style(theme),
                          ),
                    ),
                    _chevron(t),
                    if (collapsed) _summary(),
                  ],
                ),
              ),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chevron(Tokens t) {
    final collapsed = widget.collapsed;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focus = f),
      child: Opacity(
        opacity: collapsed || _hover || _focus ? 1 : 0,
        child: IconTap.drawn(
          (size, color) =>
              TurnChevron(open: !collapsed, size: size, color: color),
          tooltip: collapsed ? 'Expand' : 'Collapse',
          size: 12,
          padding: 4,
          color: t.textMuted,
          onTap: widget.onToggle,
        ),
      ),
    );
  }

  /// The most urgent of its chats' states, while it's collapsed.
  Widget _summary() => ListenableBuilder(
    listenable: Listenable.merge([for (final c in widget.chats) c.look]),
    builder: (context, _) => switch (groupPhase(widget.chats)) {
      final phase? => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: PhaseDot(phase),
      ),
      null => const SizedBox.shrink(),
    },
  );
}
