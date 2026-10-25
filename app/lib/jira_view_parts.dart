import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Asks which board's active sprint is the sprint list.
Future<JiraBoard?> pickBoard(BuildContext context, List<JiraBoard> boards) =>
    showDialog<JiraBoard>(
      context: context,
      builder: (context) => nushiDialog(
        'Sprint board',
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final b in boards)
              Tap(
                onTap: () => Navigator.pop(context, b),
                padding: const EdgeInsets.all(6),
                child: Text('${b.name}  ·  ${b.project}'),
              ),
            if (boards.isEmpty) const Text('No boards on this site.'),
          ],
        ),
        [
          Button(
            label: 'Cancel',
            kind: ButtonKind.ghost,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

/// Asks a saved search's name; null when cancelled.
Future<String?> askName(BuildContext context) async {
  // Not disposed: the dialog may still be closing.
  final name = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => nushiDialog(
      'Save the search',
      TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (_) => Navigator.pop(context, true),
      ),
      [
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context, false),
        ),
        Button(
          label: 'Save',
          kind: ButtonKind.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return ok ?? false ? name.text.trim() : null;
}

/// A status's color by its category: to do, in progress, done.
Color statusColor(Tokens t, String category) => switch (category) {
  'done' => t.done,
  'indeterminate' => t.running,
  _ => t.textMuted,
};

class IssueRow extends StatelessWidget {
  const new(
    this.issue, {
    required this.selected,
    required this.onTap,
    super.key,
  });

  final JiraIssue issue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final i = issue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Tap(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(i.key, style: theme.code(t.textSecondary, size: 11.5)),
                const SizedBox(width: 8),
                Text(i.type, style: theme.ui(t.textMuted, size: 11.5)),
                const Spacer(),
                Text(
                  i.status,
                  style: theme.ui(statusColor(t, i.statusCategory), size: 11.5),
                ),
              ],
            ),
            Text(
              i.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text),
            ),
            if (i.assignee.isNotEmpty || i.priority.isNotEmpty)
              Text(
                [i.assignee, i.priority].where((s) => s.isNotEmpty).join(' · '),
                style: theme.ui(t.textMuted, size: 11.5),
              ),
          ],
        ),
      ),
    );
  }
}

class NoSite extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Center(
      child: Tap(
        onTap: () => showSettings(context, daemon.client, jira: true),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Add a Jira site in ',
                style: theme.ui(theme.t.textMuted),
              ),
              TextSpan(text: 'Settings › Jira', style: theme.ui(theme.t.link)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The view's bar: the site shown (a menu of the others), Refresh, Close.
class JiraBar extends StatelessWidget {
  const new({
    required this.sites,
    required this.site,
    required this.loading,
    required this.onSite,
    required this.onRefresh,
    required this.onClose,
    super.key,
  });

  final List<JiraSite> sites;
  final JiraSite? site;
  final bool loading;
  final void Function(String id) onSite;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Text('Jira', style: theme.ui(t.text, weight: FontWeight.w600)),
          const SizedBox(width: 12),
          if (site case final site?)
            Menu(
              entries: [
                for (final s in sites)
                  MenuEntry(
                    s.id,
                    checked: s.id == site.id,
                    onPick: () => onSite(s.id),
                  ),
              ],
              child: Text(
                '${site.id} ▾',
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          const Spacer(),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('Loading…', style: theme.ui(t.textMuted, size: 12)),
            ),
          IconTap(Icons.refresh, tooltip: 'Refresh (⌘R)', onTap: onRefresh),
          IconTap(Icons.close, tooltip: 'Close (⌘J)', onTap: onClose),
        ],
      ),
    );
  }
}
