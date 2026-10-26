import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_jql.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A list's tab: "mine", "sprint", "jql", or a saved search's index.
String label(String list, JiraSite site) => switch (list) {
  'mine' => 'Mine',
  'sprint' => 'Sprint',
  'jql' => 'JQL',
  _ => site.searches[int.parse(list)].name,
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
  });

  final Daemon daemon;
  final JiraSite site;
  final List<String> lists;
  final String list;

  /// The sprint's name, or what to say without one.
  final String sprint;

  /// The JQL last run.
  final String jql;
  final TextEditingController jqlText;
  final FocusNode jqlFocus;
  final ValueChanged<String> onPick;
  final VoidCallback onPickBoard;
  final ValueChanged<int> onRemoveSearch;
  final ValueChanged<String> onRunJql;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final l in lists)
                Menu(
                  entries: [
                    if (l == 'sprint')
                      MenuEntry('Pick the board…', onPick: onPickBoard),
                    if (int.tryParse(l) case final i?)
                      MenuEntry(
                        'Remove the search',
                        onPick: () => onRemoveSearch(i),
                      ),
                  ],
                  builder: (context, open) => GestureDetector(
                    onSecondaryTapUp: (d) => open(d.localPosition),
                    child: Tap(
                      selected: l == list,
                      onTap: () => onPick(l),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        label(l, site),
                        style: theme.ui(
                          l == list ? t.text : t.textSecondary,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (list == 'sprint')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 10, 4),
            child: site.board == 0
                ? Tap(
                    onTap: onPickBoard,
                    child: Text(
                      'Pick the board',
                      style: theme.ui(t.link, size: 12),
                    ),
                  )
                : Text(
                    '${site.boardName} · $sprint',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
          ),
        if (list == 'jql')
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
}
