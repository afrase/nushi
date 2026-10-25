import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue_parts.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Starts work on issue [key] of [site] in [folder] (one to choose, when
/// null): the New chat dialog with the issue picked, a worktree on its
/// branch.
Future<void> startWork(
  BuildContext context,
  Daemon daemon,
  String site,
  String key,
  String? folder,
) async {
  final f = folder ?? await getDirectoryPath(confirmButtonText: 'Choose');
  if (f == null || !context.mounted) return;
  await tryOrShow(context, () async {
    final r = await daemon.client.findJiraIssues(
      FindJiraIssuesRequest(text: key, site: site),
    );
    if (!context.mounted || r.issues.isEmpty) return;
    await newChat(context, daemon, f, issue: IssueChat.found(r.issues.first));
  });
}

/// The moves [issue]'s workflow allows now, asked of Jira, each moving it
/// (asking a screen's fields first), then [onMoved].
Future<List<MenuEntry>> issueMoves(
  BuildContext context,
  Daemon daemon,
  String site,
  JiraIssue issue, {
  required Future<void> Function() onMoved,
}) async {
  final r = await daemon.client.listJiraTransitions(
    ListJiraTransitionsRequest(site: site, key: issue.key),
  );
  Future<void> move(JiraTransition t) async {
    var values = <String, String>{};
    if (t.fields.isNotEmpty) {
      if (!context.mounted) return;
      final asked = await askFields(context, t);
      if (asked == null) return;
      values = asked;
    }
    if (!context.mounted) return;
    await tryOrShow(context, () async {
      await daemon.client.transitionJiraIssue(
        TransitionJiraIssueRequest(site: site, key: issue.key, transition: t.id)
          ..values.addAll(values),
      );
      await onMoved();
    });
  }

  return [
    for (final t in r.transitions)
      MenuEntry(
        t.name,
        detail: t.to == t.name ? '' : '→ ${t.to}',
        checked: t.to == issue.status,
        onPick: () => unawaited(move(t)),
      ),
  ];
}

/// The status, which opens the moves the workflow allows now (asked of
/// Jira as it opens).
class StatusMenu extends StatefulWidget {
  const new(this.issue, {required this.load, super.key});

  final JiraIssue issue;
  final Future<List<MenuEntry>> Function() load;

  @override
  State<StatusMenu> createState() => _StatusMenuState();
}

class _StatusMenuState extends State<StatusMenu> {
  List<MenuEntry> _entries = const [MenuEntry('Loading…')];

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final color = statusColor(t, widget.issue.statusCategory);
    return Menu(
      entries: _entries,
      builder: (context, open) => Tap(
        onTap: () async {
          try {
            final entries = await widget.load();
            if (!mounted) return;
            setState(
              () => _entries = entries.isEmpty
                  ? const [MenuEntry('No moves now')]
                  : entries,
            );
          } on Object catch (e) {
            if (mounted) setState(() => _entries = [MenuEntry(jiraError(e))]);
          }
          // Once the menu has its rows.
          WidgetsBinding.instance.addPostFrameCallback((_) => open());
        },
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: box(color, radius: NushiTheme.control),
          child: Text(
            '${widget.issue.status} ▾',
            style: theme.ui(color, size: 12, weight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
