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
        [Button(label: 'Cancel', onPressed: () => Navigator.pop(context))],
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
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
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

/// The view's bar: the site shown (a menu of the others and, with several,
/// "All sites": [site] null), Refresh, Close.
class JiraBar extends StatelessWidget {
  const new({
    required this.sites,
    required this.site,
    required this.loading,
    required this.onSite,
    required this.onRefresh,
    required this.onClose,
    super.key,
    this.updated,
    this.now,
  });

  final List<JiraSite> sites;
  final JiraSite? site;
  final bool loading;

  /// When Jira said what shows, if it's what was kept from last time.
  final DateTime? updated;

  /// The time ages are counted from (tests); now when null.
  final DateTime? now;
  final void Function(String? id) onSite;
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
          if (sites.isNotEmpty)
            Menu(
              entries: [
                for (final s in sites)
                  MenuEntry(
                    s.id,
                    checked: s.id == site?.id,
                    onPick: () => onSite(s.id),
                  ),
                if (sites.length > 1) ...[
                  MenuEntry.divider,
                  MenuEntry(
                    'All sites',
                    checked: site == null,
                    onPick: () => onSite(null),
                  ),
                ],
              ],
              child: Text(
                '${site?.id ?? 'All sites'} ▾',
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          const Spacer(),
          if (updatedLine(updated, loading: loading, now: now) case final line?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(line, style: theme.ui(t.textMuted, size: 12)),
            ),
          IconTap(Icons.refresh, tooltip: 'Refresh (⌘R)', onTap: onRefresh),
          IconTap(Icons.close, tooltip: 'Close (⌘J)', onTap: onClose),
        ],
      ),
    );
  }
}

/// Says a new build of Nushi needs the user's OK to read a site's token,
/// with the button that asks macOS for it.
class NeedsOk extends StatelessWidget {
  const new({required this.onAllow, super.key});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(10),
      decoration: box(t.needs, fill: t.needsSoft),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'This build of Nushi needs your OK to read the token from the '
              'keychain; macOS asks for your password.',
              style: theme.ui(t.needs, size: 12),
            ),
          ),
          const SizedBox(width: 8),
          Button(label: 'Allow…', onPressed: onAllow),
        ],
      ),
    );
  }
}
