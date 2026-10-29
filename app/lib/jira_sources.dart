import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_jql.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Which list the Jira view shows: my open issues, a board's sprint, a
/// saved search or the JQL typed. A saved search is known by its name and
/// JQL, not its place, so removing another leaves it showing. The others
/// are const (one of each, so `==` holds).
@immutable
sealed class JiraList {
  const new();
}

final class MyIssues extends JiraList {
  const new();
}

final class Sprint extends JiraList {
  const new();
}

final class Jql extends JiraList {
  const new();
}

final class Saved extends JiraList {
  new(JiraSearch s) : name = s.name, jql = s.jql;

  final String name;
  final String jql;

  /// Whether [site] still has this search.
  bool on(JiraSite site) =>
      site.searches.any((s) => s.name == name && s.jql == jql);

  @override
  bool operator ==(Object other) =>
      other is Saved && other.name == name && other.jql == jql;

  @override
  int get hashCode => Object.hash(name, jql);
}

/// A list's tab.
String label(JiraList list) => switch (list) {
  MyIssues() => 'Mine',
  Sprint() => 'Sprint',
  Jql() => 'JQL',
  Saved(:final name) => name,
};

/// Where the Jira view's list comes from: a tab for each of [lists] (a
/// right click on the sprint's picks its board, on a saved search's
/// removes it), the sprint's board and name under the sprint's, the JQL
/// field (and Save…) under JQL's.
class JiraSources extends StatelessWidget {
  const new({
    required this.daemon,
    required this.site,
    required this.lists,
    required this.list,
    required this.sprint,
    required this.jql,
    required this.jqlText,
    required this.jqlFocus,
    required this.onPick,
    required this.onPickBoard,
    required this.onRemoveSearch,
    required this.onRunJql,
    required this.onSave,
    super.key,
    this.filter,
  });

  final Daemon daemon;
  final JiraSite site;
  final List<JiraList> lists;
  final JiraList list;

  /// The sprint's name, or what to say without one.
  final String sprint;

  /// The JQL last run.
  final String jql;
  final TextEditingController jqlText;
  final FocusNode jqlFocus;
  final ValueChanged<JiraList> onPick;
  final VoidCallback onPickBoard;
  final ValueChanged<Saved> onRemoveSearch;
  final ValueChanged<String> onRunJql;
  final VoidCallback onSave;

  /// At the tabs' row's end: whose issues show.
  final Widget? filter;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Row(
            children: [
              Expanded(child: _tabs(theme)),
              ?filter,
            ],
          ),
        ),
        if (list is Sprint)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 10, 4),
            child: site.board == 0
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Button(
                      label: 'Pick the board…',
                      onPressed: onPickBoard,
                    ),
                  )
                : Text(
                    '${site.boardName} · $sprint',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
          ),
        if (list is Jql)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JqlField(
                  client: daemon.client,
                  site: site.id,
                  controller: jqlText,
                  focusNode: jqlFocus,
                  onRun: onRunJql,
                ),
                if (jql.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Button(label: 'Save…', onPressed: onSave),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// A tab for each list.
  Widget _tabs(NushiTheme theme) {
    final t = theme.t;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final l in lists)
          Menu(
            entries: [
              if (l is Sprint)
                MenuEntry('Pick the board…', onPick: onPickBoard),
              if (l is Saved)
                MenuEntry('Remove the search', onPick: () => onRemoveSearch(l)),
            ],
            builder: (context, open) => GestureDetector(
              onSecondaryTapUp: (d) => open(d.localPosition),
              child: Tap(
                selected: l == list,
                onTap: () => onPick(l),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  label(l),
                  style: theme.ui(
                    l == list ? t.text : t.textSecondary,
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
