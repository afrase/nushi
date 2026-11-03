import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The sidebar's chat rows that move by dragging (a project's, Pinned's),
// the Pinned section's header, and the dragged look the projects' headers
// share (`sidebar_groups.dart`).

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
/// folder decides its project, so a row of another list is refused): the
/// others slide apart where the dragged one would land ([SlideList]), and
/// [onMove] says it moved from one place to another. [row] builds each
/// row, making it movable with what it's given. [collapsed], the rows
/// other than [selectedId]'s fold away together ([Disclosure]), and none
/// moves.
class MovableRows extends StatelessWidget {
  const new({
    required this.group,
    required this.chats,
    required this.row,
    required this.onMove,
    super.key,
    this.collapsed = false,
    this.selectedId,
    this.standIn,
  });

  /// Which list it is: a project's folder, or [pinnedGroup].
  final Object group;
  final List<ChatState> chats;
  final Widget Function(ChatState chat, Movable movable) row;
  final void Function(int from, int to) onMove;
  final bool collapsed;
  final String? selectedId;

  /// A row-shaped placeholder at the top for a chat starting here, which
  /// its row takes the place of ([SlideList.standIn]).
  final Widget? standIn;

  @override
  Widget build(BuildContext context) => SlideList<_MovingChat>(
    count: chats.length,
    standIn: standIn,
    accepts: (m) => m.group == group && !collapsed,
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
                data: _MovingChat(group, c.id),
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
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 2),
            child: Tap(
              onTap: onToggle,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  TurnChevron(open: open, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Archived  ${archived.length}',
                    style: theme.ui(t.textSecondary, size: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        Disclosure(
          open: open && archived.isNotEmpty,
          child: SlideList<_MovingChat>(
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
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final collapsed = pinnedCollapsed.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 6, 2),
      child: Row(
        children: [
          IconTap.drawn(
            (size, color) =>
                TurnChevron(open: !collapsed, size: size, color: color),
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
