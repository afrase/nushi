import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_nav.dart';
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

class NoSite extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add a Jira site in ', style: theme.ui(theme.t.textMuted)),
          LinkText(
            'Settings › Jira',
            onTap: () => daemon.openSettings(section: SettingsSection.jira),
          ),
        ],
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
            MenuField(
              compact: true,
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
              label: Text(site?.id ?? 'All sites'),
            ),
          const Spacer(),
          if (updatedLine(updated, loading: loading, now: now) case final line?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(line, style: theme.ui(t.textMuted, size: 12)),
            ),
          IconTap(Icons.refresh, tooltip: 'Refresh (⌘R)', onTap: onRefresh),
          IconTap(Icons.close, tooltip: 'Close (esc)', onTap: onClose),
        ],
      ),
    );
  }
}
