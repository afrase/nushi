import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/jira_work.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// An issue in the task list, and the site it's on.
typedef Task = ({String site, JiraIssue issue});

/// [tasks] in the order the list shows them: grouped by status, the
/// groups in the workflow's order as far as Jira tells it (to do, in
/// progress, done, by the status's category), each group's statuses and
/// issues in the order Jira listed them.
List<Task> ordered(List<Task> tasks) {
  int rank(String category) => switch (category) {
    'new' => 0,
    'indeterminate' => 1,
    'done' => 2,
    _ => 3,
  };
  final seen = <String>{for (final t in tasks) t.issue.status}.toList();
  final category = {
    for (final t in tasks) t.issue.status: t.issue.statusCategory,
  };
  final statuses = [...seen]
    ..sort((a, b) {
      final by = rank(category[a]!).compareTo(rank(category[b]!));
      return by != 0 ? by : seen.indexOf(a).compareTo(seen.indexOf(b));
    });
  return [for (final s in statuses) ...tasks.where((t) => t.issue.status == s)];
}

/// The chats on an issue, the newest first.
List<ChatState> chatsOn(Daemon daemon, Task t) =>
    daemon.chats.values
        .where((c) => c.jiraSite == t.site && c.jiraKey == t.issue.key)
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created));

/// The task list, as Orca's task drawer: [tasks] (already [ordered])
/// under a line for each status, each row with its key (and site, when
/// [sites]), summary, priority, its chats (a click opens the newest),
/// its status (a menu of the moves) and Start work (a menu of folders,
/// then the New chat dialog with the issue picked). A click on a row
/// [onOpen]s its details.
class TaskList extends StatelessWidget {
  const new({
    required this.daemon,
    required this.tasks,
    required this.selected,
    required this.sites,
    required this.onOpen,
    required this.onMoved,
    required this.startMenu,
    super.key,
  });

  final Daemon daemon;
  final List<Task> tasks;
  final int selected;
  final bool sites;
  final void Function(int i) onOpen;
  final Future<void> Function() onMoved;

  /// Takes the selected row's Start work menu, for ⌘⏎.
  final void Function(OpenMenu open) startMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The priority only where the summary keeps room.
    builder: (context, box) => _list(context, wide: box.maxWidth > 900),
  );

  Widget _list(BuildContext context, {required bool wide}) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final rows = <Widget>[];
    for (final (i, task) in tasks.indexed) {
      final status = task.issue.status;
      if (i == 0 || tasks[i - 1].issue.status != status) {
        final n = tasks.where((x) => x.issue.status == status).length;
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(18, i == 0 ? 10 : 18, 18, 4),
            child: Text(
              '$status  $n',
              style: theme.ui(
                statusColor(t, task.issue.statusCategory),
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      rows.add(_row(context, theme, i, task, wide: wide));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 12), children: rows);
  }

  Widget _row(
    BuildContext context,
    NushiTheme theme,
    int i,
    Task task, {
    required bool wide,
  }) {
    final t = theme.t;
    final is_ = task.issue;
    final chats = chatsOn(daemon, task);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Tap(
        selected: i == selected,
        onTap: () => onOpen(i),
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Row(
          children: [
            SizedBox(
              width: 86,
              child: Text(
                is_.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.textSecondary, size: 11.5),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: is_.summary),
                    if (sites)
                      TextSpan(
                        text: '  ${task.site}',
                        style: theme.ui(t.textMuted, size: 11.5),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text),
              ),
            ),
            if (wide && is_.priority.isNotEmpty)
              SizedBox(
                width: 80,
                child: Text(
                  is_.priority,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.textMuted, size: 11.5),
                ),
              ),
            if (chats.isNotEmpty) _Chats(daemon, chats),
            // A column of its own, so the priorities line up.
            SizedBox(
              width: 130,
              child: Align(
                alignment: Alignment.centerRight,
                child: StatusMenu(
                  is_,
                  load: () => issueMoves(
                    context,
                    daemon,
                    task.site,
                    is_,
                    onMoved: onMoved,
                  ),
                ),
              ),
            ),
            Menu(
              digits: true,
              entries: folderEntries(
                daemon,
                onPick: (f) =>
                    startWork(context, daemon, task.site, is_.key, f),
              ),
              builder: (context, open) {
                if (i == selected) startMenu(open);
                return Tap(
                  onTap: open,
                  tooltip: i == selected ? 'Start work (⌘⏎)' : 'Start work',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text('Start work', style: theme.ui(t.link, size: 12)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The agents of an issue's chats (three at most, then how many more); a
/// click opens the newest chat.
class _Chats extends StatelessWidget {
  const new(this.daemon, this.chats);

  final Daemon daemon;
  final List<ChatState> chats;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = chats.length;
    return Tap(
      onTap: () => daemon.select(chats.first.id),
      tooltip: n == 1 ? 'Open its chat' : 'Open its newest chat (it has $n)',
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in chats.take(3))
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: AgentMark(c.agent, size: 13, color: t.textSecondary),
            ),
          if (n > 3) Text('+${n - 3}', style: theme.ui(t.textMuted, size: 11)),
        ],
      ),
    );
  }
}
