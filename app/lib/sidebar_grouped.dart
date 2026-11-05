import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/status.dart';

/// The sidebar's groups under a grouping other than Project
/// ([groupChats]): each a header, an agent's mark before an Agent group's
/// name and the state's dot before a Status group's, collapsed by its
/// chevron (kept in [sidebarCollapsed] by [ChatGroup.key]); None's one
/// group has none. The groups come and go with motion but don't drag;
/// their rows drag only into a section, the sort setting their order.
class GroupedChats extends StatelessWidget {
  const new({
    required this.groups,
    required this.selectedId,
    required this.row,
    super.key,
  });

  final List<ChatGroup> groups;
  final String? selectedId;
  final Widget Function(ChatState chat, Movable movable) row;

  @override
  Widget build(BuildContext context) => SlideList<Object>(
    count: groups.length,
    accepts: (_) => false,
    onMove: (_, _) {},
    item: (i, _) {
      final g = groups[i];
      final headed = g.label.isNotEmpty;
      final collapsed = headed && sidebarCollapsed.value.contains(g.key);
      return Column(
        key: ValueKey(g.key),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headed)
            GroupHeader(
              title: g.label,
              chats: g.chats,
              collapsed: collapsed,
              onToggle: () => sidebarCollapsed.toggle(g.key),
              lead: g.agent.isNotEmpty
                  ? AgentMark(g.agent)
                  : g.key.startsWith('status:') && g.chats.isNotEmpty
                  ? PhaseDot(g.chats.first.phase)
                  : null,
            )
          else
            const SizedBox(height: 6),
          MovableRows(
            group: g.key,
            chats: g.chats,
            collapsed: collapsed,
            reorders: false,
            selectedId: selectedId,
            row: row,
            onMove: (_, _) {},
          ),
        ],
      );
    },
  );
}
