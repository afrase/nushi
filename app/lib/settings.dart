import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart';

/// What the app remembers across launches, in `app.json` in the data folder:
/// whether the details panel shows (its toolbar button), which of its cards
/// are collapsed and their order, what each chat's Changes view shows, the
/// panes' widths, whether changed files show flat, which chats show their
/// terminals, the terminal's font, whether a subagent's pane shows wide,
/// the Jira task list's groups and assignee filters, the GitHub view's
/// cards and filters, the sidebar's project groups' order and which are
/// collapsed, and the models picked last. Not whether new chats get a
/// worktree: an older `worktrees` key is ignored, and dropped by the next
/// save.
final showDetails = ValueNotifier<bool>(_saved['details'] != false)
  ..addListener(_save);
final collapsedCards = ValueNotifier<Set<String>>(_strings('collapsed'))
  ..addListener(_save);

/// The details panel's cards by title, in the order they were dragged into.
final cardOrder = ValueNotifier<List<String>>([..._strings('cards')])
  ..addListener(_save);

/// What each chat's Changes view shows (a `Scope`'s name), by chat, once
/// picked.
final changeScopes = ValueNotifier<Map<String, String>>({
  for (final MapEntry(:key, :value)
      in ((_saved['scopes'] as Map?) ?? {}).entries)
    if (key is String && value is String) key: value,
})..addListener(_save);

/// Whether the Changes view lists its files flat rather than as a tree.
final changesFlat = ValueNotifier<bool>(_saved['flat'] == true)
  ..addListener(_save);

/// The chats whose terminal panel is open.
final terminalChats = ValueNotifier<Set<String>>(_strings('terminals'))
  ..addListener(_save);

/// The Jira site used last (shown in the Jira view, or an issue picked from
/// it for a chat): a key typed alone is looked for there.
final lastJiraSite = ValueNotifier<String?>(switch (_saved['jiraSite']) {
  final String s => s,
  _ => null,
})..addListener(_save);

/// The Jira task list's status groups, by site (`*` for every site's
/// list): the order they were dragged into (statuses it doesn't name go
/// last), and those collapsed.
final jiraGroupOrder = ValueNotifier<Map<String, List<String>>>(
  _byPlace('jiraGroups'),
)..addListener(_save);
final jiraCollapsed = ValueNotifier<Map<String, List<String>>>(
  _byPlace('jiraCollapsed'),
)..addListener(_save);

/// The Jira lists' assignee filters, by site and list (`jira_people.dart`'s
/// `filterPlace`): `["me"]`, `["none"]` or `["person", id, name]`; a list
/// not named shows everyone's.
final jiraAssignee = ValueNotifier<Map<String, List<String>>>(
  _byPlace('jiraAssignee'),
)..addListener(_save);

/// Whether the GitHub view's Review requested has pull requests asked of
/// a team of mine too ("Me and my teams"), not only of me by name.
final githubTeamReviews = ValueNotifier<bool>(_saved['githubTeams'] == true)
  ..addListener(_save);

/// The GitHub view's cards ("review", "mine", "assigned"): the order
/// they were dragged into (those it doesn't name go last), and those
/// collapsed.
final githubCardOrder = ValueNotifier<List<String>>([
  ..._strings('githubCards'),
])..addListener(_save);
final githubCollapsed = ValueNotifier<Set<String>>(_strings('githubCollapsed'))
  ..addListener(_save);

/// The GitHub view's filters: only what changed in the last this many
/// days (0: any time; 90 at first), and by host the repositories
/// (owner/name) and owners hidden, and the owners it's limited to.
final githubDays = ValueNotifier<int>(switch (_saved['githubDays']) {
  final int d when d >= 0 => d,
  _ => 90,
})..addListener(_save);
final githubHidden = ValueNotifier<Map<String, List<String>>>(
  _byPlace('githubHidden'),
)..addListener(_save);
final githubOwners = ValueNotifier<Map<String, List<String>>>(
  _byPlace('githubOwners'),
)..addListener(_save);

/// The sidebar's project groups, by folder path: the order they were
/// dragged into (folders it doesn't name go first), and those collapsed.
final sidebarOrder = ValueNotifier<List<String>>([..._strings('sidebarOrder')])
  ..addListener(_save);
final sidebarCollapsed = ValueNotifier<Set<String>>(
  _strings('sidebarCollapsed'),
)..addListener(_save);

/// The models picked from the model menu, by value, the last first: the
/// menu's first four are the ones used last.
final recentModels = ValueNotifier<List<String>>([..._strings('models')])
  ..addListener(_save);

/// The widths panes were dragged to, by pane (see `Resizable`).
final paneWidths = ValueNotifier<Map<String, double>>({
  for (final MapEntry(:key, :value)
      in ((_saved['panes'] as Map?) ?? {}).entries)
    if (key is String && value is num) key: value.toDouble(),
})..addListener(_save);

/// Whether a subagent's pane shows wide.
final subagentWide = ValueNotifier<bool>(_saved['subagentWide'] == true)
  ..addListener(_save);

/// The terminal's font family (null: the bundled JetBrains Mono) and size.
final terminalFont = ValueNotifier<String?>(switch (_saved['termFont']) {
  final String f => f,
  _ => null,
})..addListener(_save);
final terminalFontSize = ValueNotifier<double>(
  (_saved['termSize'] as num?)?.toDouble() ?? 12.5,
)..addListener(_save);

File get _settings => File('$dataDir/app.json');

final Map<String, Object?> _saved = () {
  try {
    return jsonDecode(_settings.readAsStringSync()) as Map<String, Object?>;
  } on Object {
    return <String, Object?>{};
  }
}();

Set<String> _strings(String key) => {
  ...?(_saved[key] as List?)?.whereType<String>(),
};

Map<String, List<String>> _byPlace(String name) => {
  for (final MapEntry(:key, :value) in ((_saved[name] as Map?) ?? {}).entries)
    if (key is String && value is List) key: [...value.whereType<String>()],
};

/// Writes [file] whole or not at all: to a file beside it, renamed over
/// it, so a crash mid-write can't leave half of it.
void writeWhole(File file, String text) {
  File('${file.path}.tmp')
    ..writeAsStringSync(text, flush: true)
    ..renameSync(file.path);
}

void _save() {
  try {
    writeWhole(
      _settings,
      jsonEncode({
        'details': showDetails.value,
        'collapsed': collapsedCards.value.toList(),
        'scopes': changeScopes.value,
        'cards': cardOrder.value,
        'panes': paneWidths.value,
        'flat': changesFlat.value,
        'terminals': terminalChats.value.toList(),
        'termFont': terminalFont.value,
        'termSize': terminalFontSize.value,
        'subagentWide': subagentWide.value,
        'jiraSite': lastJiraSite.value,
        'githubTeams': githubTeamReviews.value,
        'jiraGroups': jiraGroupOrder.value,
        'jiraCollapsed': jiraCollapsed.value,
        'jiraAssignee': jiraAssignee.value,
        'githubCards': githubCardOrder.value,
        'githubCollapsed': githubCollapsed.value.toList(),
        'githubDays': githubDays.value,
        'githubHidden': githubHidden.value,
        'githubOwners': githubOwners.value,
        'sidebarOrder': sidebarOrder.value,
        'sidebarCollapsed': sidebarCollapsed.value.toList(),
        'models': recentModels.value,
      }),
    );
  } on Object {
    // Not remembered; it still applies until the app quits.
  }
}
