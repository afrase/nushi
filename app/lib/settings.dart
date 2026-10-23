import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'daemon.dart';

/// What the app remembers across launches, in `app.json` in the data folder:
/// whether the details panel shows (its toolbar button), which of its cards
/// are collapsed and their order, the repositories whose new chats get a
/// worktree, what each chat's Changes view shows, the panes' widths, whether changed files show flat, and which chats
/// show their terminals.
final showDetails = ValueNotifier<bool>(_saved['details'] != false)
  ..addListener(_save);
final collapsedCards = ValueNotifier<Set<String>>(_strings('collapsed'))
  ..addListener(_save);
final worktreeRepos = ValueNotifier<Set<String>>(_strings('worktrees'))
  ..addListener(_save);

/// The details panel's cards by title, in the order they were dragged into.
final cardOrder = ValueNotifier<List<String>>([..._strings('cards')])
  ..addListener(_save);

/// What each chat's Changes view shows (a `Scope`'s name), by chat, once
/// picked. Chats from before step 43 that showed what's uncommitted keep it.
final changeScopes = ValueNotifier<Map<String, String>>({
  for (final id in _strings('uncommitted')) id: 'uncommitted',
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

/// The widths panes were dragged to, by pane (see `Resizable`).
final paneWidths = ValueNotifier<Map<String, double>>({
  for (final MapEntry(:key, :value)
      in ((_saved['panes'] as Map?) ?? {}).entries)
    if (key is String && value is num) key: value.toDouble(),
})..addListener(_save);

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

void _save() {
  try {
    _settings.writeAsStringSync(
      jsonEncode({
        'details': showDetails.value,
        'collapsed': collapsedCards.value.toList(),
        'worktrees': worktreeRepos.value.toList(),
        'scopes': changeScopes.value,
        'cards': cardOrder.value,
        'panes': paneWidths.value,
        'flat': changesFlat.value,
        'terminals': terminalChats.value.toList(),
      }),
    );
  } on Object {
    // Not remembered; it still applies until the app quits.
  }
}
