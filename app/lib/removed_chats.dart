import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What deletes an agent's sessions on its own, by agent.
const _expires = {
  'claude': 'Claude Code deletes sessions after 30 days by default',
};

/// Says, once, which chats the daemon removed because their agent no longer
/// had their sessions; OK dismisses it (ADR 0015).
class RemovedChatsBar extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  /// The bar's sentence for [removed].
  static String text(List<RemovedChat> removed) {
    String title(RemovedChat r) =>
        '“${r.title.isEmpty ? 'Untitled chat' : r.title}”';
    final agents = {for (final r in removed) r.agent};
    final one = agents.length == 1 ? agents.first : null;
    final why = switch (_expires[one]) {
      final e? => ' ($e)',
      null => '',
    };
    if (removed.length == 1) {
      return 'Removed ${title(removed.first)}: '
          '${agentTitle(removed.first.agent)} no longer had its session$why.';
    }
    final names = [
      for (final r in removed)
        if (one == null) '${title(r)} (${agentTitle(r.agent)})' else title(r),
    ].join(', ');
    final who = one == null ? 'their agents' : agentTitle(one);
    return 'Removed ${removed.length} chats whose sessions $who deleted$why: '
        '$names.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final removed = daemon.removedChats;
    return Container(
      color: t.raised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.history_toggle_off, size: 14, color: t.textMuted),
          Expanded(
            child: Tooltip(
              message: [
                for (final r in removed) '${r.title} — ${tildePath(r.folder)}',
              ].join('\n'),
              child: Text(
                text(removed),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          ),
          Button(
            label: 'OK',
            kind: ButtonKind.ghost,
            height: 24,
            onPressed: daemon.dismissRemoved,
          ),
        ],
      ),
    );
  }
}
