import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'daemon.dart';

/// What the app remembers across launches, in `app.json` in the data folder:
/// whether the details panel shows (its toolbar button), which of its cards
/// are collapsed and their order, the repositories whose new chats get a
/// worktree, what each chat's Changes view shows, the panes' widths, whether
/// changed files show flat, which chats show their terminals, the
/// terminal's font, and whether a subagent's pane shows wide.
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
        'worktrees': worktreeRepos.value.toList(),
        'scopes': changeScopes.value,
        'cards': cardOrder.value,
        'panes': paneWidths.value,
        'flat': changesFlat.value,
        'terminals': terminalChats.value.toList(),
        'termFont': terminalFont.value,
        'termSize': terminalFontSize.value,
        'subagentWide': subagentWide.value,
      }),
    );
  } on Object {
    // Not remembered; it still applies until the app quits.
  }
}
