import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';

/// What the app remembers across launches, in `app.json` in the data folder:
/// whether the details panel shows (its toolbar button), which of its widgets
/// are collapsed and their order, what each chat's Changes view shows, the
/// panes' widths, whether changed files show flat, which chats show their
/// terminals, the terminal's font, whether a subagent's pane shows wide,
/// the Jira task list's groups and assignee filters, the GitHub view's
/// cards and filters, the sidebar's project groups' order and which are
/// collapsed, each project's chats' order, whether Pinned is collapsed,
/// the models picked last, each chat's pinned artifacts and preview tabs,
/// and the Mac's notifications and Dock badge, the appearance, and the newer
/// release whose toast was dismissed. Each is a [Pref].
/// Not whether new chats get a worktree: an older `worktrees` key is
/// ignored, and dropped by the next save.
final Pref<bool> showDetails = _plain('details', true);

/// The details panel's widgets collapsed, by title.
final Pref<Set<String>> collapsedWidgets = _set('collapsed');

/// The details panel's widgets by title, in the order they were dragged
/// into. Saved under `cards`, from when they were called that.
final Pref<List<String>> widgetOrder = _list('cards');

/// What each chat's Changes view shows (a `Scope`'s name), by chat, once
/// picked.
final Pref<Map<String, String>> changeScopes = _byChat(
  'scopes',
  (v) => v is String ? v : null,
);

/// Whether the Changes view lists its files flat rather than as a tree.
final Pref<bool> changesFlat = _plain('flat', false);

/// The chats whose terminal panel is open.
final Pref<Set<String>> terminalChats = _set('terminals', chats: true);

/// The Jira site used last (shown in the Jira view, or an issue picked from
/// it for a chat): a key typed alone is looked for there.
final Pref<String?> lastJiraSite = _plain('jiraSite', null);

/// The Jira task list's status groups, by site (`*` for every site's
/// list): the order they were dragged into (statuses it doesn't name go
/// last), and those collapsed.
final Pref<Map<String, List<String>>> jiraGroupOrder = _places('jiraGroups');
final Pref<Map<String, List<String>>> jiraCollapsed = _places('jiraCollapsed');

/// The Jira lists' assignee filters, by site and list (`jira_people.dart`'s
/// `filterPlace`): `["me"]`, `["none"]` or `["person", id, name]`; a list
/// not named shows everyone's.
final Pref<Map<String, List<String>>> jiraAssignee = _places('jiraAssignee');

/// Whether the GitHub view's Review requested has pull requests asked of
/// a team of mine too ("Me and my teams"), not only of me by name.
final Pref<bool> githubTeamReviews = _plain('githubTeams', false);

/// The GitHub view's cards ("review", "mine", "assigned"): the order
/// they were dragged into (those it doesn't name go last), and those
/// collapsed.
final Pref<List<String>> githubCardOrder = _list('githubCards');
final Pref<Set<String>> githubCollapsed = _set('githubCollapsed');

/// The GitHub view's filters: only what changed in the last this many
/// days (0: any time; 90 at first), and by host the repositories
/// (owner/name) and owners hidden, and the owners it's limited to.
final githubDays = Pref<int>('githubDays', (v) => v is int && v >= 0 ? v : 90);
final Pref<Map<String, List<String>>> githubHidden = _places('githubHidden');
final Pref<Map<String, List<String>>> githubOwners = _places('githubOwners');

/// Findings from review bots (Settings › GitHub; off at first): the To do
/// list reads must-address findings out of these bots' reviews (logins,
/// comma-separated), the list items under a heading with any of
/// [githubFindingHeadings]' words (comma-separated, any case).
final Pref<bool> githubFindings = _plain('githubFindings', false);
final Pref<String> githubFindingBots = _plain(
  'githubFindingBots',
  'github-actions',
);
final Pref<String> githubFindingHeadings = _plain(
  'githubFindingHeadings',
  findingHeadingsDefault,
);
const findingHeadingsDefault = 'Key findings, Must address';

/// The sidebar's project groups, by folder path: the order they were
/// dragged into (folders it doesn't name go first), and those collapsed.
final Pref<List<String>> sidebarOrder = _list('sidebarOrder');
final Pref<Set<String>> sidebarCollapsed = _set('sidebarCollapsed');

/// The order each project's chats were dragged into, by folder path
/// ('' for no folder): chat ids, those it doesn't name (new chats) going
/// first. A pinned chat keeps its place here while it's out of the list.
final sidebarChats = Pref<Map<String, List<String>>>(
  'sidebarChats',
  _byPlace,
  chats: (order) => order.values.expand((ids) => ids),
  without: (order, gone) => {
    for (final MapEntry(:key, :value) in order.entries)
      key: [...value.where((id) => !gone.contains(id))],
  },
);

/// Whether the sidebar's Pinned section is collapsed.
final Pref<bool> pinnedCollapsed = _plain('pinnedCollapsed', false);

/// The models picked from the model menu, by value, the last first: the
/// menu's first four are the ones used last.
final Pref<List<String>> recentModels = _list('models');

/// When each chat was last opened (milliseconds since the epoch), by chat
/// id: the palette lists chats the last opened first.
final Pref<Map<String, int>> chatOpened = _byChat(
  'opened',
  (v) => v is int ? v : null,
);

/// Each chat's pinned artifacts (as `chatFiles` names them), by chat id,
/// in the order pinned.
final Pref<Map<String, List<String>>> pinnedFiles = _byChat('pins', _strings);

/// Each chat's preview tabs (the files, as `ChatState.tabFiles` names them),
/// by chat id, in the tabs' order. The daemon checks each again when its
/// tab shows (`WatchChatFile`).
final Pref<Map<String, List<String>>> previewTabs = _byChat(
  'previewTabs',
  _strings,
);

/// The pins kept in [saved] (`app.json` read whole, as [readSaved] does).
Map<String, List<String>> savedPins(Map<String, Object?> saved) =>
    _byPlace(saved['pins']);

/// The newest comment seen of each chat's pull request (ms since the
/// epoch), by chat id: newer ones are unread.
final Pref<Map<String, int>> pullSeen = _byChat(
  'pullSeen',
  (v) => v is num ? v.toInt() : null,
);

/// The chats whose PR widget no longer offers Clean up… (Not now); its
/// menu still has it.
final Pref<Set<String>> cleanUpLater = _set('cleanUpLater', chats: true);

/// The widths panes were dragged to, by pane (see `Resizable`).
final paneWidths = Pref<Map<String, double>>(
  'panes',
  (v) => _entries(v, (w) => w is num ? w.toDouble() : null),
);

/// Whether a subagent's pane shows wide.
final Pref<bool> subagentWide = _plain('subagentWide', false);

/// The terminal's font family (null: the bundled JetBrains Mono) and size.
final Pref<String?> terminalFont = _plain('termFont', null);
final terminalFontSize = Pref<double>(
  'termSize',
  (v) => v is num ? v.toDouble() : 12.5,
);

/// The app's appearance (Settings › General, and View's items): light,
/// dark or as the system is.
final appearance = Pref<ThemeMode>(
  'appearance',
  (v) => ThemeMode.values.asNameMap()[v] ?? ThemeMode.system,
  write: (mode) => mode.name,
);

/// The Mac's notifications (`alerts.dart`), each kind on or off: a chat
/// needs you (a permission prompt or a question), a turn ends, a turn
/// fails; whether they play a sound; and the Dock badge counting the
/// chats that need you.
final Pref<bool> alertNeedsYou = _plain('alertNeedsYou', true);
final Pref<bool> alertFinished = _plain('alertFinished', true);
final Pref<bool> alertFailed = _plain('alertFailed', true);
final Pref<bool> alertSound = _plain('alertSound', false);
final Pref<bool> dockBadge = _plain('dockBadge', true);

/// The newer release whose toast was dismissed ("0.1.17"): it shows again
/// only for a newer one.
final Pref<String?> dismissedUpdate = _plain('dismissedUpdate', null);

/// The prefs kept by chat, which [chatsKept] and [forgetChats] go through.
/// Named here rather than found among those made: a pref is made when
/// first read, and a chat gone is forgotten from those not read yet too.
List<Pref<Object?>> get _chatPrefs => [
  changeScopes,
  terminalChats,
  sidebarChats,
  chatOpened,
  pinnedFiles,
  previewTabs,
  pullSeen,
  cleanUpLater,
];

/// The chats some pref keeps something for.
Set<String> chatsKept() => {for (final p in _chatPrefs) ...p.chats};

/// Forgets the chats [ids] (gone) in every pref kept by chat: one save.
void forgetChats(Set<String> ids) {
  for (final p in _chatPrefs) {
    p.forget(ids);
  }
}

/// One thing the app remembers in `app.json`, under [key]: read from
/// what was there at launch (`read` takes what's saved under the key, of
/// any type, or null, and gives the value: the default for nothing or a
/// wrong type, never an error), and saved with the others whenever it
/// changes (`write` gives what's saved; the value itself unless given).
/// One kept by chat says which chats it has something for (`chats`) and
/// how it goes without some (`without`).
final class Pref<T> extends ValueNotifier<T> {
  new(this.key, this._read, {this._write, this._chats, this._without})
    : super(_read(_saved[key])) {
    _made.add(this);
    addListener(_saveSoon);
  }

  final String key;
  final T Function(Object? saved) _read;
  final Object? Function(T value)? _write;
  final Iterable<String> Function(T value)? _chats;
  final T Function(T value, Set<String> gone)? _without;

  /// The chats this keeps something for (none unless it's kept by chat).
  Iterable<String> get chats => _chats?.call(value) ?? const [];

  /// Goes without what it keeps for the chats [ids], if anything.
  void forget(Set<String> ids) {
    if (_without case final without? when chats.any(ids.contains)) {
      value = without(value, ids);
    }
  }

  Object? get _saving => switch (_write) {
    final write? => write(value),
    null => value,
  };

  void _reset() => value = _read(_saved[key]);
}

/// The prefs made so far (read or set in this run), in that order.
final _made = <Pref<Object?>>[];

/// A plain JSON value: what's saved if it's a [T], else [or].
Pref<T> _plain<T>(String key, T or) => Pref(key, (v) => v is T ? v : or);

/// Strings in no order, saved as a list; [chats] when they're chat ids.
Pref<Set<String>> _set(String key, {bool chats = false}) => Pref(
  key,
  (v) => {..._strings(v) ?? const []},
  write: (s) => s.toList(),
  chats: chats ? (s) => s : null,
  without: chats ? (s, gone) => s.difference(gone) : null,
);

/// Strings in an order.
Pref<List<String>> _list(String key) => Pref(key, (v) => [...?_strings(v)]);

/// Strings by place (a site, a host, a folder…).
Pref<Map<String, List<String>>> _places(String key) => Pref(key, _byPlace);

/// Something for each chat, by chat id; [each] reads one (null: wrong).
Pref<Map<String, V>> _byChat<V extends Object>(
  String key,
  V? Function(Object? saved) each,
) => Pref(
  key,
  (v) => _entries(v, each),
  chats: (m) => m.keys,
  without: (m, gone) => {...m}..removeWhere((id, _) => gone.contains(id)),
);

/// [saved]'s strings, if it's a list.
List<String>? _strings(Object? saved) =>
    saved is List ? [...saved.whereType<String>()] : null;

/// [saved]'s entries that [each] reads, if it's a map.
Map<String, V> _entries<V extends Object>(
  Object? saved,
  V? Function(Object? saved) each,
) => {
  if (saved is Map)
    for (final MapEntry(:key, :value) in saved.entries)
      if ((key, each(value)) case (final String k, final V v)) k: v,
};

Map<String, List<String>> _byPlace(Object? saved) => _entries(saved, _strings);

File get _settings => File('$dataDir/app.json');

/// `app.json` as it was at launch.
final Map<String, Object?> _saved = readSaved();

/// `app.json` as it is on disk now; empty when it can't be read.
Map<String, Object?> readSaved() {
  try {
    return jsonDecode(_settings.readAsStringSync()) as Map<String, Object?>;
  } on Object {
    return <String, Object?>{};
  }
}

/// Keys an older app saved that mean nothing now, dropped by the next
/// save: `worktrees` (new chats no longer remember one).
const _dropped = {'worktrees'};

var _saveDue = false;

/// Saves once the changes made meanwhile are in (a chat forgotten from
/// several prefs, or a test's setup, is one write).
void _saveSoon() {
  if (_saveDue) return;
  _saveDue = true;
  scheduleMicrotask(() {
    _saveDue = false;
    _save();
  });
}

/// Writes the prefs made over `app.json` as it was at launch: those not
/// read in this run, and keys a newer app saved, stay as they were.
void _save() {
  try {
    writeWhole(
      _settings,
      utf8.encode(
        jsonEncode({
          for (final MapEntry(:key, :value) in _saved.entries)
            if (!_dropped.contains(key)) key: value,
          for (final p in _made) p.key: p._saving,
        }),
      ),
    );
  } on Object {
    // Not remembered; it still applies until the app quits.
  }
}

/// Every pref as it was at launch (a test process's: as its data folder's
/// `app.json` had it, none unless a test wrote one before reading), so
/// no test sees another's.
@visibleForTesting
void resetAppSettings() {
  _saveDue = false; // a test's pending save may never have run
  for (final p in _made) {
    p._reset();
  }
}
