import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The spans the inbox can be limited to, in days (0: any time).
const updatedSpans = [30, 90, 365, 0];

/// "Last 90 days", "Last year", "Any time".
String spanLabel(int days) => switch (days) {
  0 => 'Any time',
  365 => 'Last year',
  _ => 'Last $days days',
};

/// "90 days", "a year": a span of [days] in words.
String daysWords(int days) => days == 365 ? 'a year' : '$days days';

/// A user's or an organization's name, as GitHub allows them (the daemon
/// checks again).
final ownerRE = RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,38}$');

/// The owner of `owner/name`.
String ownerOf(String repo) => repo.split('/').first;

/// Updated within: a compact menu of [updatedSpans].
class UpdatedMenu extends StatelessWidget {
  const new({required this.days, required this.onPick, super.key});

  final int days;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => MenuField(
    compact: true,
    tooltip: 'Only what changed in this time',
    entries: [
      for (final d in updatedSpans)
        MenuEntry(spanLabel(d), checked: d == days, onPick: () => onPick(d)),
    ],
    label: Text(spanLabel(days)),
  );
}

/// Which repositories: all, my folders' or only some owners'; then the
/// owners and repositories the inbox has (and those hidden), each checked
/// while shown: picking one hides it, or shows it again.
class ReposMenu extends StatelessWidget {
  const new({
    required this.known,
    required this.knownRepos,
    required this.owners,
    required this.hidden,
    required this.seen,
    required this.onKnown,
    required this.onOwners,
    required this.onHidden,
    super.key,
  });

  /// Only my folders' repositories.
  final bool known;
  final int knownRepos;

  /// Only these owners' (none: all).
  final List<String> owners;

  /// The repositories (owner/name) and owners hidden.
  final List<String> hidden;

  /// The repositories (owner/name) in the inbox.
  final List<String> seen;
  final ValueChanged<bool> onKnown;
  final ValueChanged<List<String>> onOwners;
  final ValueChanged<List<String>> onHidden;

  @override
  Widget build(BuildContext context) {
    final repos = {...seen, ...hidden.where((h) => h.contains('/'))}.toList()
      ..sort();
    final names = {
      ...repos.map(ownerOf),
      ...hidden.where((h) => !h.contains('/')),
    }.toList()..sort();
    MenuEntry toggle(String name, {String detail = ''}) {
      final shown = !hidden.contains(name);
      return MenuEntry(
        name,
        detail: detail,
        checked: shown,
        tooltip: shown ? 'Hide it' : 'Show it again',
        onPick: () => onHidden(
          shown ? [...hidden, name] : [...hidden.where((h) => h != name)],
        ),
      );
    }

    final scope = known
        ? "My folders' repositories"
        : owners.isNotEmpty
        ? owners.join(', ')
        : 'All repositories';
    return MenuField(
      compact: true,
      entries: [
        MenuEntry(
          'All repositories',
          checked: !known && owners.isEmpty,
          onPick: () {
            onKnown(false);
            onOwners(const []);
          },
        ),
        MenuEntry(
          "My folders' repositories",
          detail: '$knownRepos',
          checked: known,
          onPick: knownRepos == 0 ? null : () => onKnown(true),
        ),
        MenuEntry(
          'Only owners…',
          detail: owners.join(', '),
          checked: !known && owners.isNotEmpty,
          onPick: () async {
            final picked = await askOwners(context, owners);
            if (picked == null) return;
            onKnown(false);
            onOwners(picked);
          },
        ),
        if (names.isNotEmpty) ...[
          MenuEntry.divider,
          const MenuEntry.heading('Owners'),
          for (final o in names) toggle(o),
        ],
        if (repos.isNotEmpty) ...[
          MenuEntry.divider,
          const MenuEntry.heading('Repositories'),
          for (final r in repos)
            toggle(
              r,
              detail: hidden.contains(ownerOf(r)) ? 'its owner hidden' : '',
            ),
        ],
      ],
      label: Text(hidden.isEmpty ? scope : '$scope · ${hidden.length} hidden'),
    );
  }
}

/// The repositories (owner/name) in [inbox], each once.
List<String> reposIn(ListGitHubInboxResponse? inbox) => [
  ...{
    for (final it in [...?inbox?.review, ...?inbox?.mine, ...?inbox?.assigned])
      it.ref.repo,
  },
];

/// Asks which owners (users or organizations) the inbox is limited to:
/// names apart by spaces or commas, ten at most; none for all. Null when
/// cancelled.
Future<List<String>?> askOwners(BuildContext context, List<String> owners) {
  // Not disposed: the dialog may still be closing.
  final text = TextEditingController(text: owners.join(' '));
  return showDialog<List<String>>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          void done() {
            final names = text.text
                .split(RegExp(r'[\s,]+'))
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList();
            final bad = names.where((n) => !ownerRE.hasMatch(n)).firstOrNull;
            if (bad != null || names.length > 10) {
              setState(
                () => error = bad != null
                    ? "“$bad” isn't a user's or an organization's name."
                    : 'Ten owners at most.',
              );
              return;
            }
            Navigator.pop(context, names);
          }

          return nushiDialog(
            'Only these owners',
            TextField(
              controller: text,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'afrase my-org',
                helperText: 'Users or organizations; empty for all.',
                errorText: error,
              ),
              onSubmitted: (_) => done(),
            ),
            [
              Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
              Button(
                label: 'Only these',
                kind: ButtonKind.primary,
                onPressed: done,
              ),
            ],
          );
        },
      );
    },
  );
}

/// A card's quiet last line: "3 older than 90 days · Show".
class OlderLine extends StatelessWidget {
  const new({
    required this.count,
    required this.days,
    required this.onShow,
    super.key,
  });

  final int count;
  final int days;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Row(
        children: [
          Text('$count older than ${daysWords(days)}', style: muted),
          Text('  ·  ', style: muted),
          LinkText(
            'Show',
            size: 12,
            tooltip: 'Show them in this card until Nushi quits',
            onTap: onShow,
          ),
        ],
      ),
    );
  }
}
