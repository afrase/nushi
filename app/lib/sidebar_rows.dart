import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
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
/// row, making it movable with what it's given.
class MovableRows extends StatelessWidget {
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
  Widget build(BuildContext context) => SlideList<_MovingChat>(
    count: chats.length,
    accepts: (m) => m.group == group,
    onMove: onMove,
    item: (i, drag) {
      final c = chats[i];
      return KeyedSubtree(
        key: ValueKey(c.id),
        child: row(
          c,
          (child, {required enabled}) => LayoutBuilder(
            builder: (context, box) => drag.draggable(
              data: _MovingChat(group, c.id),
              enabled: enabled,
              feedback: Lifted(
                c.shownTitle,
                width: box.maxWidth,
                weight: FontWeight.w400,
              ),
              child: child,
            ),
          ),
        ),
      );
    },
  );
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
