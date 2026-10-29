import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/card_list.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/jira_work.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
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

/// The statuses of [tasks], in the order they come.
List<String> statusesOf(List<Task> tasks) => [
  ...{for (final t in tasks) t.issue.status},
];

/// [tasks] (already [ordered]) with their status groups in the order they
/// were dragged into in [place] (a site's id, `*` for every site's list);
/// a status not dragged yet (one Jira added since) goes last.
List<Task> grouped(List<Task> tasks, String place) {
  final saved = jiraGroupOrder.value[place] ?? const [];
  final statuses = statusesOf(tasks);
  return [
    for (final s in [
      ...saved.where(statuses.contains),
      ...statuses.where((s) => !saved.contains(s)),
    ])
      ...tasks.where((t) => t.issue.status == s),
  ];
}

/// Whether [status]'s group is collapsed in [place].
bool collapsedGroup(String place, String status) =>
    jiraCollapsed.value[place]?.contains(status) ?? false;

/// [tasks] as the list shows them: [grouped], without collapsed groups'
/// (the keys move through these).
List<Task> visibleTasks(List<Task> tasks, String place) => [
  for (final t in grouped(tasks, place))
    if (!collapsedGroup(place, t.issue.status)) t,
];

/// The chats on an issue, the newest first.
List<ChatState> chatsOn(Daemon daemon, Task t) =>
    daemon.chats.values
        .where((c) => c.jiraSite == t.site && c.jiraKey == t.issue.key)
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created));

/// The task list, as Orca's task drawer: [tasks] (already [ordered]) in a
/// card for each status, the cards in the order they were dragged into
/// and each collapsible, both remembered for [place] (see [grouped]).
/// A click on a row [onOpen]s its details.
class TaskList extends StatelessWidget {
  const new({
    required this.daemon,
    required this.tasks,
    required this.place,
    required this.selected,
    required this.sites,
    required this.onOpen,
    required this.onMoved,
    required this.startMenu,
    super.key,
    this.people = true,
    this.selectedRow,
  });

  final Daemon daemon;
  final List<Task> tasks;
  final String place;

  /// The selected issue's key.
  final String? selected;
  final bool sites;

  /// With each row's assignee (not in a list of my issues).
  final bool people;
  final void Function(Task task) onOpen;
  final Future<void> Function() onMoved;

  /// The selected row's key, to scroll it into view.
  final GlobalKey? selectedRow;

  /// Takes the selected row's Start work menu (and its issue's key), for
  /// ⌘⏎.
  final void Function(String key, OpenMenu open) startMenu;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([jiraGroupOrder, jiraCollapsed]),
    builder: (context, _) => LayoutBuilder(
      // The priority only where the summary keeps room.
      builder: (context, box) => _list(context, wide: box.maxWidth > 700),
    ),
  );

  Widget _list(BuildContext context, {required bool wide}) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = grouped(tasks, place);
    // The one row [selectedRow] keys (a key may be on two sites).
    final first = shown.where((x) => x.issue.key == selected).firstOrNull;
    final statuses = statusesOf(shown);
    final collapsed = jiraCollapsed.value[place] ?? const [];
    final columns = (
      key: _keyWidth(context, theme),
      priority: wide,
      people: people,
    );
    return CardList(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      buildAll: true,
      onReorder: (from, to) => jiraGroupOrder.value = {
        ...jiraGroupOrder.value,
        place: reordered(
          jiraGroupOrder.value[place] ?? const [],
          statuses,
          from,
          to,
        ),
      },
      children: [
        for (final (i, status) in statuses.indexed)
          CardShell(
            key: ValueKey(status),
            index: i,
            open: !collapsed.contains(status),
            onToggle: () => jiraCollapsed.value = {
              ...jiraCollapsed.value,
              place: collapsed.contains(status)
                  ? [...collapsed.where((s) => s != status)]
                  : [...collapsed, status],
            },
            title: Text(
              '$status  ${shown.where((x) => x.issue.status == status).length}',
              style: theme.ui(
                statusColor(
                  t,
                  shown
                      .firstWhere((x) => x.issue.status == status)
                      .issue
                      .statusCategory,
                ),
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final task in shown)
                    if (task.issue.status == status)
                      TaskRow(
                        key:
                            (identical(task, first) ? selectedRow : null) ??
                            ValueKey('${task.site} ${task.issue.key}'),
                        daemon: daemon,
                        task: task,
                        selected: task.issue.key == selected,
                        site: sites,
                        columns: columns,
                        onOpen: () => onOpen(task),
                        onMoved: onMoved,
                        startMenu: (open) => startMenu(task.issue.key, open),
                      ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The key's column: as wide as a long key (`ABCD-12345`).
  static double _keyWidth(BuildContext context, NushiTheme theme) {
    final p = TextPainter(
      text: TextSpan(
        text: 'ABCD-12345',
        style: theme.code(theme.t.textSecondary, size: 11.5),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = p.width.ceilToDouble() + 16;
    p.dispose();
    return w;
  }
}

/// A row's columns, the same in every row and card: the key's width,
/// whether the priority and the assignee show.
typedef TaskColumns = ({double key, bool priority, bool people});

/// A row of the task list: its key (and site, when [site]), summary, its
/// chats (a click opens the newest), and in columns of their own the
/// priority, the status (a menu of the moves) and the assignee. Start
/// work (a menu of folders, then the New chat dialog with the issue
/// picked) shows on hover and on the selected row (⌘⏎ too); a
/// right-click has it.
class TaskRow extends StatefulWidget {
  const new({
    required this.daemon,
    required this.task,
    required this.selected,
    required this.site,
    required this.columns,
    required this.onOpen,
    required this.onMoved,
    required this.startMenu,
    super.key,
  });

  final Daemon daemon;
  final Task task;
  final bool selected;
  final bool site;
  final TaskColumns columns;
  final VoidCallback onOpen;
  final Future<void> Function() onMoved;
  final void Function(OpenMenu open) startMenu;

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _hover = false;

  List<MenuEntry> _folders(BuildContext context) => folderEntries(
    widget.daemon,
    onPick: (f) => startWork(
      context,
      widget.daemon,
      widget.task.site,
      widget.task.issue.key,
      f,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final task = widget.task;
    final is_ = task.issue;
    final cols = widget.columns;
    final chats = chatsOn(widget.daemon, task);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Menu(
        entries: [MenuEntry('Start work', submenu: _folders(context))],
        builder: (context, open) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Tap(
            selected: widget.selected,
            onTap: widget.onOpen,
            onSecondaryTapUp: (d) => open(d.localPosition),
            padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
            child: Row(
              children: [
                SizedBox(
                  width: cols.key,
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
                        if (widget.site)
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
                if (chats.isNotEmpty) _Chats(widget.daemon, chats),
                if (cols.priority)
                  SizedBox(
                    width: 76,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        is_.priority,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.textMuted, size: 11.5),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 128,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusMenu(
                      is_,
                      quiet: true,
                      load: () => issueMoves(
                        context,
                        widget.daemon,
                        task.site,
                        is_,
                        onMoved: widget.onMoved,
                      ),
                    ),
                  ),
                ),
                if (cols.people)
                  SizedBox(
                    width: 26,
                    child: Center(
                      child: Avatar(name: is_.assignee, id: is_.assigneeId),
                    ),
                  ),
                SizedBox(
                  width: 30,
                  child: _hover || widget.selected
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: _start(context),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _start(BuildContext context) => Menu(
    digits: true,
    entries: _folders(context),
    builder: (context, open) {
      if (widget.selected) widget.startMenu(open);
      return IconTap(
        Icons.play_arrow_outlined,
        size: 15,
        tooltip: widget.selected ? 'Start work (⌘⏎)' : 'Start work',
        onTap: open,
      );
    },
  );
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
